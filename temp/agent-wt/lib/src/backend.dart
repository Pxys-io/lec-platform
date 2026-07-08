import 'api/api_client.dart';
import 'repositories/auth_repository.dart';
import 'repositories/user_repository.dart';
import 'repositories/course_repository.dart';
import 'repositories/lesson_repository.dart';
import 'repositories/quiz_repository.dart';
import 'repositories/video_repository.dart';
import 'repositories/misc_repository.dart';

class Backend {
  final ApiClient apiClient;
  final AuthRepository auth;
  final UserRepository users;
  final CourseRepository courses;
  final LessonRepository lessons;
  final QuizRepository quizzes;
  final VideoRepository videos;
  final MiscRepository misc;

  Backend._internal(
    this.apiClient, 
    this.auth, 
    this.users, 
    this.courses, 
    this.lessons, 
    this.quizzes, 
    this.videos,
    this.misc,
  );

  static Backend create(String baseUrl) {
    final client = ApiClient(baseUrl: baseUrl);
    return Backend._internal(
      client,
      AuthRepository(apiClient: client),
      UserRepository(apiClient: client),
      CourseRepository(apiClient: client),
      LessonRepository(apiClient: client),
      QuizRepository(apiClient: client),
      VideoRepository(apiClient: client),
      MiscRepository(apiClient: client),
    );
  }
}