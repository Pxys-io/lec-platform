class Material {
  final String id;
  final String lessonId;
  final String title;
  final String type;
  final String url;
  final DateTime createdAt;

  Material({required this.id, required this.lessonId, required this.title, required this.type, required this.url, required this.createdAt});

  factory Material.fromJson(Map<String, dynamic> json) => Material(
        id: json['id'],
        lessonId: json['lesson_id'] ?? '',
        title: json['title'] ?? '',
        type: json['type'] ?? '',
        url: json['url'] ?? '',
        createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      );
}