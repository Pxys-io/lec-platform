class EnrollmentFormField {
  final String label;
  final String type;
  final bool required;
  final List<String>? options;

  EnrollmentFormField({
    required this.label,
    required this.type,
    required this.required,
    this.options,
  });

  factory EnrollmentFormField.fromJson(Map<String, dynamic> json) {
    return EnrollmentFormField(
      label: json['label'],
      type: json['type'],
      required: json['required'] ?? false,
      options: json['options'] != null ? List<String>.from(json['options']) : null,
    );
  }
}

class EnrollmentConfig {
  final String id;
  final String courseId;
  final List<EnrollmentFormField> fields;
  final bool requireImages;
  final int imageCount;
  final String? imageInstructions;

  EnrollmentConfig({
    required this.id,
    required this.courseId,
    required this.fields,
    required this.requireImages,
    required this.imageCount,
    this.imageInstructions,
  });

  factory EnrollmentConfig.fromJson(Map<String, dynamic> json) {
    return EnrollmentConfig(
      id: json['id'],
      courseId: json['course_id'],
      fields: (json['fields'] as List)
          .map((e) => EnrollmentFormField.fromJson(e))
          .toList(),
      requireImages: json['require_images'] ?? false,
      imageCount: json['image_count'] ?? 1,
      imageInstructions: json['image_instructions'],
    );
  }
}

class EnrollmentRequest {
  final String id;
  final String userId;
  final String courseId;
  final String status;
  final Map<String, dynamic> formData;
  final String? adminComment;
  final DateTime createdAt;

  EnrollmentRequest({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.status,
    required this.formData,
    this.adminComment,
    required this.createdAt,
  });

  factory EnrollmentRequest.fromJson(Map<String, dynamic> json) {
    return EnrollmentRequest(
      id: json['id'],
      userId: json['user_id'],
      courseId: json['course_id'],
      status: json['status'],
      formData: Map<String, dynamic>.from(json['form_data'] ?? {}),
      adminComment: json['admin_comment'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
