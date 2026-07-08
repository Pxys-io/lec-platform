class QBank {
  final String id;
  final String title;
  final String description;
  final String instructorId;
  final List<String> tags;
  final String visibility;
  final String? thumbnailUrl;
  final double price;

  QBank({
    required this.id,
    required this.title,
    required this.description,
    required this.instructorId,
    this.tags = const [],
    this.visibility = 'private',
    this.thumbnailUrl,
    this.price = 0.0,
  });

  factory QBank.fromJson(Map<String, dynamic> json) => QBank(
        id: json['id'],
        title: json['title'],
        description: json['description'] ?? '',
        instructorId: json['instructor_id'],
        tags: List<String>.from(json['tags'] ?? []),
        visibility: json['visibility'] ?? 'private',
        thumbnailUrl: json['thumbnail_url'],
        price: (json['price'] ?? 0).toDouble(),
      );
}

class QBankEnrollment {
  final String id;
  final String userId;
  final String qbankId;
  final String status;
  final Map<String, dynamic> formData;
  final DateTime? expiresAt;

  QBankEnrollment({
    required this.id,
    required this.userId,
    required this.qbankId,
    required this.status,
    this.formData = const {},
    this.expiresAt,
  });

  factory QBankEnrollment.fromJson(Map<String, dynamic> json) => QBankEnrollment(
        id: json['id'],
        userId: json['user_id'],
        qbankId: json['qbank_id'],
        status: json['status'],
        formData: json['form_data'] ?? {},
        expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : null,
      );
}

class QBankSession {
  final String id;
  final String userId;
  final String qbankId;
  final String title;
  final Map<String, dynamic> config;
  final List<String> questionIds;
  final Map<String, dynamic> answers;
  final double? score;
  final DateTime? completedAt;
  final DateTime createdAt;

  QBankSession({
    required this.id,
    required this.userId,
    required this.qbankId,
    required this.title,
    this.config = const {},
    this.questionIds = const [],
    this.answers = const {},
    this.score,
    this.completedAt,
    required this.createdAt,
  });

  factory QBankSession.fromJson(Map<String, dynamic> json) => QBankSession(
        id: json['id'],
        userId: json['user_id'],
        qbankId: json['qbank_id'],
        title: json['title'],
        config: json['config_json'] != null ? Map<String, dynamic>.from(json['config_json'] is String ? {} : json['config_json']) : {}, // Simplified
        questionIds: List<String>.from(json['questions_json'] is String ? [] : json['questions_json']),
        answers: Map<String, dynamic>.from(json['answers_json'] is String ? {} : json['answers_json']),
        score: json['score']?.toDouble(),
        completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
        createdAt: DateTime.parse(json['created_at']),
      );
}
