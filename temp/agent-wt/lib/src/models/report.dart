class Report {
  final String id;
  final String reporterId;
  final String targetType;
  final String targetId;
  final String reason;
  final String status;
  final DateTime createdAt;

  Report({required this.id, required this.reporterId, required this.targetType, required this.targetId, required this.reason, required this.status, required this.createdAt});

  factory Report.fromJson(Map<String, dynamic> json) => Report(
        id: json['id'],
        reporterId: json['reporter_id'] ?? '',
        targetType: json['target_type'] ?? '',
        targetId: json['target_id'] ?? '',
        reason: json['reason'] ?? '',
        status: json['status'] ?? '',
        createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      );
}