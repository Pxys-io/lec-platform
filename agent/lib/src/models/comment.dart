class Comment {
  final String id;
  final String userId;
  final String lessonId;
  final String content;
  final String? parentId;
  final bool isEdited;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userName;
  final String? userAvatar;

  Comment({
    required this.id,
    required this.userId,
    required this.lessonId,
    required this.content,
    this.parentId,
    this.isEdited = false,
    required this.createdAt,
    required this.updatedAt,
    this.userName = '',
    this.userAvatar,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] ?? '',
        userId: json['user_id'] ?? '',
        lessonId: json['lesson_id'] ?? '',
        content: json['content'] ?? '',
        parentId: json['parent_id'],
        isEdited: json['is_edited'] ?? false,
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
        userName: json['user_name'] ?? '',
        userAvatar: json['user_avatar'],
      );
}
