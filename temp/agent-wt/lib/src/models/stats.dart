class StatsOverview {
  final int totalUsers;
  final int totalCourses;
  final int totalLessons;
  final int totalQuizzes;
  final int activeUsers;
  final double totalWatchTime;

  StatsOverview({
    required this.totalUsers,
    required this.totalCourses,
    this.totalLessons = 0,
    this.totalQuizzes = 0,
    required this.activeUsers,
    required this.totalWatchTime,
  });

  factory StatsOverview.fromJson(Map<String, dynamic> json) => StatsOverview(
        totalUsers: json['total_users'] ?? 0,
        totalCourses: json['total_courses'] ?? 0,
        totalLessons: json['total_lessons'] ?? 0,
        totalQuizzes: json['total_quizzes'] ?? 0,
        activeUsers: json['active_users'] ?? 0,
        totalWatchTime: (json['total_watch_time'] ?? 0).toDouble(),
      );
}

class CourseStats {
  final String courseId;
  final int totalEnrolled;
  final int totalLessons;

  CourseStats({required this.courseId, required this.totalEnrolled, required this.totalLessons});

  factory CourseStats.fromJson(Map<String, dynamic> json) => CourseStats(
        courseId: json['course_id'] ?? '',
        totalEnrolled: json['total_enrolled'] ?? 0,
        totalLessons: json['total_lessons'] ?? 0,
      );
}

class InstructorStats {
  final String instructorId;
  final int totalCourses;
  final int totalStudents;

  InstructorStats({required this.instructorId, required this.totalCourses, required this.totalStudents});

  factory InstructorStats.fromJson(Map<String, dynamic> json) => InstructorStats(
        instructorId: json['instructor_id'] ?? '',
        totalCourses: json['total_courses'] ?? 0,
        totalStudents: json['total_students'] ?? 0,
      );
}