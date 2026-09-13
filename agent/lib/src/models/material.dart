class Material {
  final String id;
  final String lessonId;
  final String title;
  final String type;
  final String url;
  final int? fileSize;
  final DateTime createdAt;

  Material({
    required this.id,
    required this.lessonId,
    required this.title,
    required this.type,
    required this.url,
    this.fileSize,
    required this.createdAt,
  });

  factory Material.fromJson(Map<String, dynamic> json) => Material(
        id: json['id'],
        lessonId: json['lesson_id'] ?? '',
        title: json['title'] ?? '',
        type: json['type'] ?? '',
        url: json['url'] ?? '',
        fileSize: json['file_size'],
        createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      );
}