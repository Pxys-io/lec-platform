class AccessCode {
  final String id;
  final String code;
  final String? courseId;
  final String? lessonId;
  final String accessType;
  final int? accessDuration;
  final int? maxUses;
  final int currentUses;
  final bool isActive;
  final DateTime createdAt;

  AccessCode({
    required this.id,
    required this.code,
    this.courseId,
    this.lessonId,
    required this.accessType,
    this.accessDuration,
    this.maxUses,
    this.currentUses = 0,
    required this.isActive,
    required this.createdAt,
  });

  factory AccessCode.fromJson(Map<String, dynamic> json) => AccessCode(
        id: json['id'],
        code: json['code'] ?? '',
        courseId: json['course_id'],
        lessonId: json['lesson_id'],
        accessType: json['access_type'] ?? '',
        accessDuration: json['access_duration'],
        maxUses: json['max_uses'],
        currentUses: json['current_uses'] ?? 0,
        isActive: json['is_active'] ?? true,
        createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      );
}
