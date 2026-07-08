class AccessCode {
  final String id;
  final String code;
  final String courseId;
  final String accessType;
  final int? durationDays;
  final bool isActive;
  final DateTime createdAt;

  AccessCode({required this.id, required this.code, required this.courseId, required this.accessType, this.durationDays, required this.isActive, required this.createdAt});

  factory AccessCode.fromJson(Map<String, dynamic> json) => AccessCode(
        id: json['id'],
        code: json['code'] ?? '',
        courseId: json['course_id'] ?? '',
        accessType: json['access_type'] ?? '',
        durationDays: json['duration_days'],
        isActive: json['is_active'] ?? true,
        createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      );
}