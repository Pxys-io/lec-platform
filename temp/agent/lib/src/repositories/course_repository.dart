import '../models/course.dart';
import '../models/lesson.dart';
import '../models/enrollment.dart';
import '../api/api_client.dart';

class CourseRepository {
  final ApiClient apiClient;

  CourseRepository({required this.apiClient});

  Future<List<Course>> getCourses() async {
    final response = await apiClient.get('/courses');
    return (response as List)
        .map((e) => Course.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Course>> getLatestCourses() async {
    final response = await apiClient.get('/courses/latest');
    return (response as List)
        .map((e) => Course.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Course> getCourse(String id) async {
    final response = await apiClient.get('/courses/$id');
    return Course.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<Course> createCourse(Map<String, dynamic> data) async {
    final response = await apiClient.post('/courses', body: data);
    return Course.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<Course> updateCourse(String id, Map<String, dynamic> data) async {
    final response = await apiClient.put('/courses/$id', body: data);
    return Course.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<void> deleteCourse(String id) async {
    await apiClient.delete('/courses/$id');
  }

  Future<List<Lesson>> getCourseLessons(String courseId) async {
    final response = await apiClient.get('/courses/$courseId/lessons');
    return (response as List)
        .map((e) => Lesson.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> getCourseStats(String courseId) async {
    final response = await apiClient.get('/courses/$courseId/stats');
    return Map<String, dynamic>.from(response as Map);
  }

  Future<EnrollmentConfig> getEnrollmentConfig(String courseId) async {
    final response = await apiClient.get('/courses/$courseId/enrollment-config');
    return EnrollmentConfig.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<EnrollmentRequest> submitEnrollmentRequest(
    String courseId,
    Map<String, dynamic> formData,
    List<String> imageUrls,
  ) async {
    final response = await apiClient.post('/enrollment/request', body: {
      'course_id': courseId,
      'form_data': formData,
      'image_urls': imageUrls,
    });
    return EnrollmentRequest.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<List<EnrollmentRequest>> getMyEnrollmentRequests() async {
    final response = await apiClient.get('/enrollment/requests/my');
    return (response as List)
        .map((e) => EnrollmentRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<String> uploadFile(String filePath) async {
    final response = await apiClient.upload('/misc/upload', filePath);
    return response['url'];
  }
}
