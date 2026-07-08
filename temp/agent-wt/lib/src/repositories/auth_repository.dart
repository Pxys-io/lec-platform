import '../models/user.dart';
import '../api/api_client.dart';

class AuthRepository {
  final ApiClient apiClient;

  AuthRepository({required this.apiClient});

  Future<String> login(String email, String password) async {
    final response = await apiClient.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    final token = response['access_token'];
    apiClient.setToken(token);
    return token;
  }
  
  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    return await apiClient.post('/auth/register', body: data);
  }
  
  Future<String> refresh() async {
    final response = await apiClient.post('/auth/refresh');
    final token = response['access_token'];
    apiClient.setToken(token);
    return token;
  }

  Future<User> getCurrentUser() async {
    final response = await apiClient.get('/auth/me');
    // Ensure response is Map<String, dynamic>
    return User.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<User> updateCurrentUser(Map<String, dynamic> data) async {
    final response = await apiClient.put('/auth/me', body: data);
    return User.fromJson(Map<String, dynamic>.from(response as Map));
  }
  
  Future<void> updatePassword(String oldPassword, String newPassword) async {
    await apiClient.put('/auth/me/password', body: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  Future<void> logout() async {
    await apiClient.post('/auth/logout');
    apiClient.clearToken();
  }
}