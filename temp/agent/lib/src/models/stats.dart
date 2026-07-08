class StatsOverview {
  final int totalUsers;
  final int totalCourses;
  final int totalLessons;
  final int totalQuizzes;
  final int newUsersThisMonth;
  final int activeUsersThisMonth;
  final double totalWatchTime;
  final List<Map<String, dynamic>> weeklyUniqueUsers;
  final List<Map<String, dynamic>> monthlyWatchStats;

  StatsOverview({
    required this.totalUsers,
    required this.totalCourses,
    this.totalLessons = 0,
    this.totalQuizzes = 0,
    this.newUsersThisMonth = 0,
    this.activeUsersThisMonth = 0,
    required this.totalWatchTime,
    this.weeklyUniqueUsers = const [],
    this.monthlyWatchStats = const [],
  });

  factory StatsOverview.fromJson(Map<String, dynamic> json) => StatsOverview(
    totalUsers: json['total_users'] ?? 0,
    totalCourses: json['total_courses'] ?? 0,
    totalLessons: json['total_lessons'] ?? 0,
    totalQuizzes: json['total_quizzes'] ?? 0,
    newUsersThisMonth: json['new_users_this_month'] ?? 0,
    activeUsersThisMonth: json['active_users_this_month'] ?? 0,
    totalWatchTime: (json['total_watch_time'] ?? 0).toDouble(),
    weeklyUniqueUsers: List<Map<String, dynamic>>.from(
      json['weekly_unique_users'] ?? [],
    ),
    monthlyWatchStats: List<Map<String, dynamic>>.from(
      json['monthly_watch_stats'] ?? [],
    ),
  );
}

class CourseStats {
  final String courseId;
  final int totalViews;
  final int uniqueUsers;
  final double averageCompletion;
  final List<Map<String, dynamic>> lessonStats;
  final int nearEndingSubscriptions;

  CourseStats({
    required this.courseId,
    this.totalViews = 0,
    this.uniqueUsers = 0,
    this.averageCompletion = 0.0,
    this.lessonStats = const [],
    this.nearEndingSubscriptions = 0,
  });

  factory CourseStats.fromJson(Map<String, dynamic> json) => CourseStats(
    courseId: json['course_id'] ?? '',
    totalViews: json['total_views'] ?? 0,
    uniqueUsers: json['unique_users'] ?? 0,
    averageCompletion: (json['average_completion'] ?? 0).toDouble(),
    lessonStats: List<Map<String, dynamic>>.from(json['lesson_stats'] ?? []),
    nearEndingSubscriptions: json['near_ending_subscriptions'] ?? 0,
  );
}

class InstructorStats {
  final String instructorId;
  final String email;
  final int totalCourses;
  final int totalUniqueUsers;
  final double totalWatchTime;
  final int codesGenerated;
  final int codesUsed;

  InstructorStats({
    required this.instructorId,
    this.email = '',
    this.totalCourses = 0,
    this.totalUniqueUsers = 0,
    this.totalWatchTime = 0.0,
    this.codesGenerated = 0,
    this.codesUsed = 0,
  });

  factory InstructorStats.fromJson(Map<String, dynamic> json) =>
      InstructorStats(
        instructorId: json['instructor_id'] ?? '',
        email: json['email'] ?? '',
        totalCourses: json['total_courses'] ?? 0,
        totalUniqueUsers: json['total_unique_users'] ?? 0,
        totalWatchTime: (json['total_watch_time'] ?? 0).toDouble(),
        codesGenerated: json['codes_generated'] ?? 0,
        codesUsed: json['codes_used'] ?? 0,
      );
}
