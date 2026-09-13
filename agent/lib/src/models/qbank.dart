import 'dart:convert';

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

  factory QBankEnrollment.fromJson(Map<String, dynamic> json) =>
      QBankEnrollment(
        id: json['id'],
        userId: json['user_id'],
        qbankId: json['qbank_id'],
        status: json['status'],
        // Backend sends form_data_json as a JSON string; tolerate both shapes.
        formData: _decodeJsonMap(json['form_data_json'] ?? json['form_data']),
        expiresAt: json['expires_at'] != null
            ? DateTime.parse(json['expires_at'])
            : null,
      );
}

class QBankSession {
  final String id;
  final String userId;
  final String qbankId;
  final String title;
  final Map<String, dynamic> config;
  final List<Map<String, dynamic>> questions;
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
    this.questions = const [],
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
        // config_json / questions_json / answers_json are JSON strings from
        // the backend; decode them (tolerate already-decoded shapes).
        config: _decodeJsonMap(json['config_json'] ?? json['config']),
        questions: _decodeJsonList(json['questions_json'] ?? json['questions']),
        answers: _decodeJsonMap(json['answers_json'] ?? json['answers']),
        score: json['score']?.toDouble(),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'])
            : null,
        createdAt: DateTime.parse(json['created_at']),
      );
}

Map<String, dynamic> _decodeJsonMap(dynamic value) {
  if (value == null) return {};
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }
  return {};
}

List<Map<String, dynamic>> _decodeJsonList(dynamic value) {
  if (value == null) return [];
  if (value is List) {
    return value
        .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
        .toList();
  }
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded
            .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
  return [];
}
