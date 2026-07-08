import 'package:flutter_test/flutter_test.dart';
import 'package:agent/agent.dart';
import 'package:uuid/uuid.dart';

void main() {
  const baseUrl = 'http://localhost:8000/api/v1';
  late Backend backend;
  late String testDeviceId;

  setUpAll(() {
    testDeviceId = const Uuid().v7();
    backend = Backend.create(baseUrl, deviceId: testDeviceId);
  });

  group('Full Backend Integration Tests', () {
    String? testCourseId;
    String? testLessonId;
    String? testQuizId;

    test('1. Authentication - Register and Login', () async {
      // Register a new user
      final userData = {
        'first_name': 'Test',
        'last_name': 'User',
        'email': 'newuser@example.com',
        'password': 'password123',
        'phone': '1234567890',
        'role': 'student',
      };
      await backend.auth.register(userData);

      // Login
      final token = await backend.auth.login(
        'newuser@example.com',
        'password123',
        deviceId: testDeviceId,
      );
      expect(token, isNotEmpty);

      final user = await backend.auth.getCurrentUser();
      expect(user.email, 'newuser@example.com');
    });

    test('2. Courses - List and Get', () async {
      final courses = await backend.courses.getCourses();
      expect(courses, isNotEmpty);
      testCourseId = courses.first.id;

      final course = await backend.courses.getCourse(testCourseId!);
      expect(course.id, testCourseId);
      expect(course.title, isNotEmpty);
    });

    test('3. Lessons - List by Course and Get', () async {
      expect(
        testCourseId,
        isNotNull,
        reason: 'Course ID from previous test is required',
      );

      final lessons = await backend.courses.getCourseLessons(testCourseId!);
      // Note: Might be empty if course has no lessons, but our DB has some
      if (lessons.isNotEmpty) {
        testLessonId = lessons.first.id;

        final lesson = await backend.lessons.getLesson(testLessonId!);
        expect(lesson.id, testLessonId);
        expect(lesson.courseId, testCourseId);
      }
    });

    test('4. Quizzes - Creation and Retrieval', () async {
      expect(
        testLessonId,
        isNotNull,
        reason: 'Lesson ID from previous test is required',
      );

      // Check if quiz exists
      final lesson = await backend.lessons.getLesson(testLessonId!);
      if (lesson.quizId != null) {
        testQuizId = lesson.quizId;
        final quiz = await backend.quizzes.getQuiz(testQuizId!);
        expect(quiz.id, testQuizId);
        expect(quiz.lessonId, testLessonId);

        final questions = await backend.quizzes.getQuizQuestions(testQuizId!);
        expect(questions, isA<List<Question>>());
      } else {
        print(
          'Skipping Quiz specific tests as no quiz is attached to lesson $testLessonId',
        );
      }
    });

    test('5. Videos - Manifest and Playlist', () async {
      expect(
        testLessonId,
        isNotNull,
        reason: 'Lesson ID from previous test is required',
      );

      final lesson = await backend.lessons.getLesson(testLessonId!);
      if (lesson.videoId != null) {
        final manifest = await backend.videos.getVideoManifest(testLessonId!);
        expect(manifest.videoId, lesson.videoId);
        expect(manifest.resolutions, isNotEmpty);

        if (manifest.resolutions.isNotEmpty) {
          final res = manifest.resolutions.first.resolution;
          final playlist = await backend.videos.getPlaylist(testLessonId!, res);
          expect(playlist, contains('#EXTM3U'));
        }
      } else {
        print(
          'Skipping Video specific tests as no video is attached to lesson $testLessonId',
        );
      }
    });

    test('6. Logout', () async {
      await backend.auth.logout();
      // After logout, subsequent calls should fail
      expect(() => backend.auth.getCurrentUser(), throwsA(isA<ApiException>()));
    });
  });
}
