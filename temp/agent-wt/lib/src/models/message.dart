class Message {
  final String id;
  final String senderId;
  final String recipientId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  Message({required this.id, required this.senderId, required this.recipientId, required this.content, required this.isRead, required this.createdAt});

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'],
        senderId: json['sender_id'] ?? '',
        recipientId: json['recipient_id'] ?? '',
        content: json['content'] ?? '',
        isRead: json['is_read'] ?? false,
        createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      );
}