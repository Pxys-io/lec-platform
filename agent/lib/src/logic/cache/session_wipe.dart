import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zero-cache policy: on sign-in AND sign-out, ALL downloaded and cached
/// data is deleted. Only the stable device ID survives (rotating it would
/// register a "new" device against the device limit). Theme lives in
/// Hydrated storage and is a setting, not cache, so it survives too.
class SessionWipe {
  static const _deviceIdKey = 'device_id';

  static Future<void> wipeAll() async {
    int files = 0;
    // 1. Offline downloads.
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final downloads = Directory('${appDir.path}/downloads');
      if (await downloads.exists()) {
        await for (final e in downloads.list(recursive: true)) {
          if (e is File) files++;
        }
        await downloads.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('[WIPE] downloads delete failed: $e');
    }
    // 2. Temp playlist cache.
    try {
      final tmp = await getTemporaryDirectory();
      final cache = Directory('${tmp.path}/video_cache');
      if (await cache.exists()) {
        await cache.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('[WIPE] video_cache delete failed: $e');
    }
    // 3. All prefs except the device id (positions, quiz progress,
    // server-mode flags, stale session bits - everything).
    int prefsCleared = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString(_deviceIdKey);
      final keys = prefs.getKeys().toList();
      for (final k in keys) {
        if (k == _deviceIdKey) continue;
        await prefs.remove(k);
        prefsCleared++;
      }
      // Restore device id if anything went sideways (paranoia: never lose it).
      if (deviceId != null && prefs.getString(_deviceIdKey) == null) {
        await prefs.setString(_deviceIdKey, deviceId);
      }
    } catch (e) {
      debugPrint('[WIPE] prefs clear failed: $e');
    }
    debugPrint('[WIPE] done files=$files prefs=$prefsCleared');
  }
}
