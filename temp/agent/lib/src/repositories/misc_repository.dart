import '../models/material.dart';
import '../models/access_code.dart';
import '../models/report.dart';
import '../models/stats.dart';
import '../models/message.dart';
import '../models/certificate.dart';
import '../api/api_client.dart';

class MiscRepository {
  final ApiClient apiClient;

  MiscRepository({required this.apiClient});

  // Materials
  Future<Material> getMaterial(String id) async {
    final response = await apiClient.get('/materials/$id');
    return Material.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<void> deleteMaterial(String id) async {
    await apiClient.delete('/materials/$id');
  }

  // Codes
  Future<List<AccessCode>> getCodes() async {
    final response = await apiClient.get('/codes');
    return (response as List)
        .map((e) => AccessCode.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AccessCode> createCode(Map<String, dynamic> data) async {
    final response = await apiClient.post('/codes', body: data);
    return AccessCode.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<Map<String, dynamic>> getCode(String code) async {
    final response = await apiClient.get('/codes/$code');
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> validateCode(Map<String, dynamic> data) async {
    final response = await apiClient.post('/codes/validate', body: data);
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> deleteCode(String id) async {
    await apiClient.delete('/codes/$id');
  }

  // Reports
  Future<List<Report>> getReports() async {
    final response = await apiClient.get('/reports');
    return (response as List)
        .map((e) => Report.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Report> createReport(Map<String, dynamic> data) async {
    final response = await apiClient.post('/reports', body: data);
    return Report.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<Report> updateReport(String id, Map<String, dynamic> data) async {
    final response = await apiClient.put('/reports/$id', body: data);
    return Report.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<Report> getReport(String id) async {
    final response = await apiClient.get('/reports/$id');
    return Report.fromJson(Map<String, dynamic>.from(response as Map));
  }

  // Stats
  Future<StatsOverview> getStatsOverview() async {
    final response = await apiClient.get('/stats/overview');
    return StatsOverview.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<Map<String, dynamic>> getStatsUsers() async {
    final response = await apiClient.get('/stats/users');
    return Map<String, dynamic>.from(response as Map);
  }

  Future<CourseStats> getStatsCourse(String id) async {
    final response = await apiClient.get('/stats/courses/$id');
    return CourseStats.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<List<InstructorStats>> getStatsInstructors() async {
    final response = await apiClient.get('/stats/instructors');
    return (response as List)
        .map((e) => InstructorStats.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> postWatchStat(Map<String, dynamic> data) async {
    final response = await apiClient.post('/stats/watch', body: data);
    return Map<String, dynamic>.from(response as Map);
  }

  Future<List<Map<String, dynamic>>> getContinueWatching() async {
    final response = await apiClient.get('/stats/continue-watching');
    return List<Map<String, dynamic>>.from(response);
  }

  // Messages
  Future<List<Message>> getMessages() async {
    final response = await apiClient.get('/messages');
    return (response as List)
        .map((e) => Message.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Message> getMessage(String id) async {
    final response = await apiClient.get('/messages/$id');
    return Message.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<Message> createMessage(Map<String, dynamic> data) async {
    final response = await apiClient.post('/messages', body: data);
    return Message.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<Message> markMessageRead(String id) async {
    final response = await apiClient.put('/messages/$id/read');
    return Message.fromJson(Map<String, dynamic>.from(response as Map));
  }

  // Certificates
  Future<List<Certificate>> getCertificates() async {
    final response = await apiClient.get('/certificates');
    return (response as List)
        .map((e) => Certificate.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> claimCertificate(String courseId) async {
    final response = await apiClient.post('/certificates/claim/$courseId');
    return Map<String, dynamic>.from(response as Map);
  }

  // Handshake
  Future<Map<String, dynamic>> appHandshake(Map<String, dynamic> data) async {
    final response = await apiClient.post('/misc/handshake', body: data);
    return Map<String, dynamic>.from(response as Map);
  }
}