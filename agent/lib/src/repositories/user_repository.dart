import '../models/user.dart';
import '../models/course.dart';
import '../api/api_client.dart';

class UserRepository {
  final ApiClient apiClient;

  UserRepository({required this.apiClient});

  Future<List<User>> getUsers() async {
    final response = await apiClient.get('/users');
    return (response as List)
        .map((e) => User.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<User> getUser(String id) async {
    final response = await apiClient.get('/users/$id');
    return User.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<User> createUser(Map<String, dynamic> data) async {
    final response = await apiClient.post('/users', body: data);
    return User.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<User> updateUser(String id, Map<String, dynamic> data) async {
    final response = await apiClient.put('/users/$id', body: data);
    return User.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<void> deleteUser(String id) async {
    await apiClient.delete('/users/$id');
  }

  Future<void> banUser(String id, {int banDurationDays = 0}) async {
    await apiClient.post('/users/$id/ban', queryParams: {
      'ban_duration_days': banDurationDays.toString(),
    });
  }

  Future<void> unbanUser(String id) async {
    await apiClient.post('/users/$id/unban');
  }

  Future<Map<String, dynamic>> grantAccess(String id, Map<String, dynamic> data) async {
    final response = await apiClient.post('/users/$id/access', body: data);
    return Map<String, dynamic>.from(response as Map);
  }

  Future<List<dynamic>> getAccess(String id) async {
    final response = await apiClient.get('/users/$id/access');
    return response as List;
  }

  Future<void> revokeAccess(String id, String accessId) async {
    await apiClient.delete('/users/$id/access/$accessId');
  }

  Future<List<Course>> getMyCourses() async {
    final response = await apiClient.get('/users/me/courses');
    return (response as List)
        .map((e) => Course.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> getUserDevices(String userId) async {
    final response = await apiClient.get('/users/$userId/devices');
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> resetUserDevices(String userId) async {
    await apiClient.post('/users/$userId/devices/reset');
  }
}