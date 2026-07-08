class Comment {
  final String id;
  final String userId;
  final String lessonId;
  final String content;
  final DateTime createdAt;

  Comment({required this.id, required this.userId, required this.lessonId, required this.content, required this.createdAt});

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'],
        userId: json['user_id'] ?? '',
        lessonId: json['lesson_id'] ?? '',
        content: json['content'] ?? '',
        createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      );
}