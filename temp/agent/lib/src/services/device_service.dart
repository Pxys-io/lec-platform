import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static const _deviceIdKey = 'device_id';

  static String _detectDeviceType() {
    if (Platform.isAndroid || Platform.isIOS) return 'mobile';
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) return 'desktop';
    return 'mobile';
  }

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v7();
      await prefs.setString(_deviceIdKey, deviceId);
    }
    return deviceId;
  }

  static String getDeviceType() => _detectDeviceType();
}
