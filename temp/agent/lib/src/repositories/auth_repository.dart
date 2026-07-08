import '../models/user.dart';
import '../api/api_client.dart';
import '../services/device_service.dart';

class AuthRepository {
  final ApiClient apiClient;
  String? _refreshToken;

  String? get refreshToken => _refreshToken;

  AuthRepository({required this.apiClient});

  Future<String> login(String email, String password) async {
    final deviceId = await DeviceService.getDeviceId();
    final deviceType = DeviceService.getDeviceType();
    final response = await apiClient.post('/auth/login', body: {
      'email': email,
      'password': password,
      'device_id': deviceId,
      'device_type': deviceType,
    });
    final token = response['access_token'];
    _refreshToken = response['refresh_token'];
    apiClient.setToken(token);
    return token;
  }
  
  Future<dynamic> register(Map<String, dynamic> data) async {
    return await apiClient.post('/auth/register', body: data);
  }
  
  Future<String> refresh() async {
    final response = await apiClient.post('/auth/refresh', queryParams: {
      'refresh_token': _refreshToken ?? '',
    });
    final token = response['access_token'];
    _refreshToken = response['refresh_token'];
    apiClient.setToken(token);
    return token;
  }

  Future<User> getCurrentUser() async {
    final response = await apiClient.get('/auth/me');
    return User.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<User> updateCurrentUser(Map<String, dynamic> data) async {
    final response = await apiClient.put('/auth/me', body: data);
    return User.fromJson(Map<String, dynamic>.from(response as Map));
  }
  
  Future<void> updatePassword(String currentPassword, String newPassword) async {
    await apiClient.put('/auth/me/password', queryParams: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  Future<void> logout() async {
    await apiClient.post('/auth/logout');
    apiClient.clearToken();
    _refreshToken = null;
  }
}
