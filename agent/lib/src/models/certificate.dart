class Certificate {
  final String id;
  final String userId;
  final String courseId;
  final String title;
  final String? description;
  final DateTime issuedAt;
  final DateTime? expiryDate;
  final String certificateHash;

  Certificate({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.title,
    this.description,
    required this.issuedAt,
    this.expiryDate,
    required this.certificateHash,
  });

  factory Certificate.fromJson(Map<String, dynamic> json) => Certificate(
        id: json['id'] ?? '',
        userId: json['user_id'] ?? '',
        courseId: json['course_id'] ?? '',
        title: json['title'] ?? '',
        description: json['description'],
        issuedAt: DateTime.parse(json['issued_at'] ?? DateTime.now().toIso8601String()),
        expiryDate: json['expiry_date'] != null ? DateTime.parse(json['expiry_date']) : null,
        certificateHash: json['certificate_hash'] ?? '',
      );
}
