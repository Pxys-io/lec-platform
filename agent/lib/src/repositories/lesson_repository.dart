import '../models/lesson.dart';
import '../models/material.dart';
import '../models/comment.dart';
import '../api/api_client.dart';

class LessonRepository {
  final ApiClient apiClient;

  LessonRepository({required this.apiClient});

  Future<Lesson> getLesson(String id) async {
    final response = await apiClient.get('/lessons/$id');
    return Lesson.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<Lesson> createLesson(Map<String, dynamic> data) async {
    final response = await apiClient.post('/lessons', body: data);
    return Lesson.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<Lesson> updateLesson(String id, Map<String, dynamic> data) async {
    final response = await apiClient.put('/lessons/$id', body: data);
    return Lesson.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<void> deleteLesson(String id) async {
    await apiClient.delete('/lessons/$id');
  }

  Future<List<Material>> getMaterials(String lessonId) async {
    final response = await apiClient.get('/lessons/$lessonId/materials');
    return (response as List)
        .map((e) => Material.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Material> createMaterial(String lessonId, Map<String, dynamic> data) async {
    final response = await apiClient.post('/lessons/$lessonId/materials', body: data);
    return Material.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<List<Comment>> getComments(String lessonId) async {
    final response = await apiClient.get('/lessons/$lessonId/comments');
    return (response as List)
        .map((e) => Comment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Comment> createComment(String lessonId, Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    payload['lesson_id'] = lessonId;
    final response = await apiClient.post('/lessons/$lessonId/comments', body: payload);
    return Comment.fromJson(Map<String, dynamic>.from(response as Map));
  }
}