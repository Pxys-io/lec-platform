class Course {
  final String id;
  final String title;
  final String description;
  final String instructorId;
  final String visibility;
  final String? thumbnailUrl;
  final List<String> tags;
  final double price;
  final DateTime createdAt;
  final DateTime updatedAt;

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.instructorId,
    required this.visibility,
    this.thumbnailUrl,
    required this.tags,
    this.price = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      instructorId: json['instructor_id'],
      visibility: json['visibility'],
      thumbnailUrl: json['thumbnail_url'],
      tags: List<String>.from(json['tags'] ?? []),
      price: (json['price'] ?? 0.0).toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'instructor_id': instructorId,
      'visibility': visibility,
      'thumbnail_url': thumbnailUrl,
      'tags': tags,
      'price': price,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
