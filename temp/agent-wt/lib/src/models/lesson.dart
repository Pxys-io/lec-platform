class Lesson {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final int order;
  final String? videoId;
  final String? quizId;
  final String lockType;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;

  Lesson({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.order,
    this.videoId,
    this.quizId,
    required this.lockType,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'],
      courseId: json['course_id'],
      title: json['title'],
      description: json['description'] ?? '',
      order: json['order'] ?? 0,
      videoId: json['video_id'],
      quizId: json['quiz_id'],
      lockType: json['lock_type'] ?? 'none',
      isPublished: json['is_published'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'title': title,
      'description': description,
      'order': order,
      'video_id': videoId,
      'quiz_id': quizId,
      'lock_type': lockType,
      'is_published': isPublished,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
