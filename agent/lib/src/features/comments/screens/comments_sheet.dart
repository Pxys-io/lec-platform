import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons_flutter.dart';
import 'package:agent/src/models/comment.dart';
import 'package:agent/src/repositories/lesson_repository.dart';
import 'package:agent/src/features/report/report_dialog.dart';

class CommentsSheet extends StatefulWidget {
  final String lessonId;
  final String currentUserId;

  const CommentsSheet({
    super.key,
    required this.lessonId,
    required this.currentUserId,
  });

  static Future<void> show(BuildContext context, {required String lessonId, required String currentUserId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CommentsSheet(lessonId: lessonId, currentUserId: currentUserId),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  List<Comment> _comments = [];
  bool _isLoading = true;
  String? _error;
  Comment? _replyTarget;
  final _commentController = TextEditingController();
  final _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = context.read<LessonRepository>();
      final comments = await repo.getComments(widget.lessonId);
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createComment(String content, {String? parentId}) async {
    try {
      final repo = context.read<LessonRepository>();
      final data = <String, dynamic>{
        'content': content,
        'user_id': widget.currentUserId,
      };
      if (parentId != null) {
        data['parent_id'] = parentId;
      }
      await repo.createComment(widget.lessonId, data);
      _commentController.clear();
      _replyController.clear();
      setState(() => _replyTarget = null);
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    }
  }

  void _showReportDialog(Comment comment) {
    ReportDialog.show(context, targetType: 'comment', targetId: comment.id);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
          const Divider(height: 1),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(LucideIcons.messageSquare, size: 20),
          const SizedBox(width: 8),
          Text('Comments', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          Text('${_comments.length}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(LucideIcons.x, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertCircle, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadComments,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text('No comments yet', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }
    final topLevel = _comments.where((c) => c.parentId == null).toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: topLevel.length,
      itemBuilder: (context, index) {
        final parent = topLevel[index];
        final replies = _comments.where((c) => c.parentId == parent.id).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCommentTile(parent),
            if (replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: replies.map(_buildCommentTile).toList(),
                ),
              ),
            const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        );
      },
    );
  }

  Widget _buildCommentTile(Comment comment) {
    final isReplyTarget = _replyTarget?.id == comment.id;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isReplyTarget ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: comment.userAvatar != null ? NetworkImage(comment.userAvatar!) : null,
            child: comment.userAvatar == null
                ? Text(
                    comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 14),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(comment.createdAt),
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                    const Spacer(),
                    _buildActionIcon(LucideIcons.flag, () => _showReportDialog(comment)),
                    const SizedBox(width: 4),
                    _buildActionIcon(LucideIcons.reply, () {
                      setState(() => _replyTarget = isReplyTarget ? null : comment);
                    }),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.content, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: Colors.grey[500]),
      ),
    );
  }

  Widget _buildInputArea() {
    final isReplying = _replyTarget != null;
    final controller = isReplying ? _replyController : _commentController;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isReplying)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(LucideIcons.reply, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Replying to ${_replyTarget!.userName}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _replyTarget = null),
                    child: const Icon(LucideIcons.x, size: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: isReplying ? 'Write a reply...' : 'Write a comment...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      _createComment(value.trim(), parentId: _replyTarget?.id);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(LucideIcons.send),
                color: Theme.of(context).colorScheme.primary,
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    _createComment(controller.text.trim(), parentId: _replyTarget?.id);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dateTime.month}/${dateTime.day}';
  }
}
