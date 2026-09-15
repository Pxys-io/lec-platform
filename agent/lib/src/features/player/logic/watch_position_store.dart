import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline-first watch position store. The last known position of every
/// lesson is persisted LOCALLY (throttled during playback, final on exit)
/// so resume works with zero connectivity and never waits on the server.
/// The server WatchHistory remains the cross-device/analytics record; this
/// store is the instant local source of truth.
class WatchPositionStore {
  static final WatchPositionStore _instance = WatchPositionStore._internal();
  factory WatchPositionStore() => _instance;
  WatchPositionStore._internal();

  static const _posPrefix = 'watch_pos_secs_';
  static const _durPrefix = 'watch_dur_secs_';

  /// Random tag per isolate boot: if a save and a later load carry different
  /// boot tags, a hot restart happened between them (fresh statics, disk
  /// read) - the prime suspect for lost positions.
  static final String bootTag =
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  SharedPreferences? _prefs;

  Future<SharedPreferences> _db() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> save(String lessonId, double positionSecs, double durationSecs,
      {String src = ''}) async {
    final p = await _db();
    // A zero reading is never newer information than a stored nonzero
    // position (first-tick/hot-restart races all report 0). Only an
    // explicit exit (user scrubbed back to start and left) may clear it.
    if (positionSecs <= 0 && src != 'dispose') {
      final cur = p.getDouble('$_posPrefix$lessonId');
      if (cur != null && cur > 0) {
        debugPrint(
          '[STORE] skip zero-overwrite ${lessonId.substring(0, 8)} '
          '(stored ${cur.toStringAsFixed(0)}s) src=$src',
        );
        return;
      }
    }
    final okPos = await p.setDouble('$_posPrefix$lessonId', positionSecs);
    final okDur = await p.setDouble('$_durPrefix$lessonId', durationSecs);
    debugPrint(
      '[STORE] save ${lessonId.substring(0, 8)} '
      'pos=${positionSecs.toStringAsFixed(0)} '
      'dur=${durationSecs.toStringAsFixed(0)} src=$src '
      'ok=$okPos/$okDur boot=$bootTag',
    );
  }

    /// Returns (positionSecs, durationSecs), or null when never watched.
  Future<({double position, double duration})?> load(String lessonId) async {
    final p = await _db();
    final pos = p.getDouble('$_posPrefix$lessonId');
    final dur = p.getDouble('$_durPrefix$lessonId');
    debugPrint(
      '[STORE] load ${lessonId.substring(0, 8)} '
      'pos=${pos?.toStringAsFixed(0) ?? 'null'} '
      'dur=${dur?.toStringAsFixed(0) ?? 'null'} boot=$bootTag',
    );
    if (pos == null || dur == null) return null;
    return (position: pos, duration: dur);
  }

  Future<void> clear(String lessonId) async {
    final p = await _db();
    await p.remove('$_posPrefix$lessonId');
    await p.remove('$_durPrefix$lessonId');
    debugPrint('[STORE] clear ${lessonId.substring(0, 8)} boot=$bootTag');
  }
}