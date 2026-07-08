import 'package:shared_preferences/shared_preferences.dart';

class ServerModeService {
  static const _serverModeKey = 'server_mode';
  static const _downloadPolicyKey = 'download_policy';
  static const _mismatchActionKey = 'mode_mismatch_action';

  String serverMode = 'hybrid';
  String downloadPolicy = 'allow';
  String mismatchAction = 'warn';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    serverMode = prefs.getString(_serverModeKey) ?? 'hybrid';
    downloadPolicy = prefs.getString(_downloadPolicyKey) ?? 'allow';
    mismatchAction = prefs.getString(_mismatchActionKey) ?? 'warn';
  }

  Future<void> updateFromHandshake(Map<String, dynamic> handshake) async {
    serverMode = handshake['server_mode'] as String? ?? 'hybrid';
    downloadPolicy = handshake['download_policy'] as String? ?? 'allow';
    mismatchAction = handshake['mode_mismatch_action'] as String? ?? 'warn';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverModeKey, serverMode);
    await prefs.setString(_downloadPolicyKey, downloadPolicy);
    await prefs.setString(_mismatchActionKey, mismatchAction);
  }

  bool get isCloudOnly => serverMode == 'cloud_only';
  bool get isLocalOnly => serverMode == 'local_only';
  bool get isHybrid => serverMode == 'hybrid';

  bool get shouldBlockMismatch => mismatchAction == 'block';
  bool get shouldAutoDeleteMismatch => mismatchAction == 'auto_delete';
  bool get shouldWarnMismatch => mismatchAction == 'warn';
}
