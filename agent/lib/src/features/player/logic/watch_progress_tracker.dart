import 'dart:async';
import 'dart:developer' as dev;
import '../../../repositories/misc_repository.dart';

/// Reports playback progress to `POST /stats/watch` periodically and on
/// dispose. The backend upserts WatchHistory, which powers continue-watching,
/// watch-time analytics, and `previous_lesson` lesson locks (they require
/// >= 90% completion of the prior lesson). Without these calls those features
/// are dead, so this must accompany every playback session.
class WatchProgressTracker {
  final MiscRepository misc;
  final String lessonId;
  final String? deviceInfo;

  static const Duration _reportInterval = Duration(seconds: 15);
  static const double _completionThreshold = 0.9;

  Timer? _timer;
  Duration _lastPosition = Duration.zero;
  Duration _duration = Duration.zero;
  double _maxCompletion = 0;
  bool _reported = false;
  bool _disposed = false;

  WatchProgressTracker({
    required this.misc,
    required this.lessonId,
    this.deviceInfo,
  });

  void start() {
    _timer ??= Timer.periodic(_reportInterval, (_) => report());
  }

  /// Called from the player's controller listener with the latest values.
  void update(Duration position, Duration duration) {
    _lastPosition = position;
    if (duration > Duration.zero) _duration = duration;
    final pct = _completionPercent;
    if (pct > _maxCompletion) _maxCompletion = pct;
  }

  double get _completionPercent {
    if (_duration.inMilliseconds <= 0) return 0;
    return (_lastPosition.inMilliseconds / _duration.inMilliseconds * 100)
        .clamp(0.0, 100.0);
  }

  bool get isComplete => _maxCompletion >= _completionThreshold * 100;

  Future<void> report() async {
    if (_reported) return;
    final pct = _maxCompletion > 0 ? _maxCompletion : _completionPercent;
    try {
      await misc.postWatchStat({
        'lesson_id': lessonId,
        'watch_time': _lastPosition.inMilliseconds / 1000.0,
        'completion_percentage': pct,
        'last_position': _lastPosition.inMilliseconds / 1000.0,
        if (deviceInfo != null) 'device_info': deviceInfo,
      });
    } catch (e) {
      dev.log('watch progress report failed: $e');
    }
  }

  /// Flushes the final position; call from the player's dispose.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    await report();
  }
}