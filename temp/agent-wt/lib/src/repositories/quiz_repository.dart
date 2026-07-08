import '../models/quiz.dart';
import '../api/api_client.dart';

class QuizRepository {
  final ApiClient apiClient;

  QuizRepository({required this.apiClient});

  Future<Quiz> getQuiz(String id) async {
    final response = await apiClient.get('/quizzes/$id');
    return Quiz.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<Quiz> createQuiz(Map<String, dynamic> data) async {
    final response = await apiClient.post('/quizzes', body: data);
    return Quiz.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<Quiz> updateQuiz(String id, Map<String, dynamic> data) async {
    final response = await apiClient.put('/quizzes/$id', body: data);
    return Quiz.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<void> deleteQuiz(String id) async {
    await apiClient.delete('/quizzes/$id');
  }

  Future<Question> createQuestion(String quizId, Map<String, dynamic> data) async {
    final response = await apiClient.post('/quizzes/$quizId/questions', body: data);
    return Question.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<List<Question>> getQuizQuestions(String quizId) async {
    final response = await apiClient.get('/quizzes/$quizId/questions');
    return (response as List)
        .map((e) => Question.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> submitQuiz(String quizId, Map<String, String> answers) async {
    final response = await apiClient.post('/quizzes/$quizId/submit', body: {
      'answers': answers,
    });
    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> getResults(String quizId) async {
    final response = await apiClient.get('/quizzes/$quizId/results');
    return Map<String, dynamic>.from(response as Map);
  }
}