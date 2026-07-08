import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:agent/src/logic/auth/auth_cubit.dart';
import 'package:agent/src/models/message.dart';
import 'package:agent/src/repositories/misc_repository.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<Message> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      final repo = context.read<MiscRepository>();
      final messages = await repo.getMessages();
      if (mounted) setState(() => _messages = messages);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthCubit>().state.user;
    if (currentUser == null) return const SizedBox();

    final conversations = _groupConversations(currentUser.id);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : conversations.isEmpty
              ? const Center(child: Text('No conversations yet'))
              : RefreshIndicator(
                  onRefresh: _loadMessages,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: conversations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final conv = conversations[index];
                      final displayName =
                          'User ${conv.otherUserId.length > 8 ? conv.otherUserId.substring(0, 8) : conv.otherUserId}';
                      return _ConversationTile(
                        otherUserId: conv.otherUserId,
                        displayName: displayName,
                        lastMessage: conv.lastMessage.content,
                        timestamp: conv.lastMessage.createdAt,
                        unreadCount: conv.unreadCount,
                        onTap: () => context.push('/chat', extra: {
                          'otherUserId': conv.otherUserId,
                          'otherUserName': displayName,
                        }),
                      );
                    },
                  ),
                ),
    );
  }

  List<_Conversation> _groupConversations(String currentUserId) {
    final Map<String, List<Message>> grouped = {};
    for (final msg in _messages) {
      final otherId =
          msg.senderId == currentUserId ? msg.recipientId : msg.senderId;
      grouped.putIfAbsent(otherId, () => []).add(msg);
    }

    final result = grouped.entries.map((e) {
      final msgs = e.value;
      msgs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final unreadCount =
          msgs.where((m) => m.recipientId == currentUserId && !m.isRead).length;
      return _Conversation(
        otherUserId: e.key,
        lastMessage: msgs.first,
        unreadCount: unreadCount,
      );
    }).toList();

    result.sort((a, b) => b.lastMessage.createdAt.compareTo(a.lastMessage.createdAt));
    return result;
  }
}

class _Conversation {
  final String otherUserId;
  final Message lastMessage;
  final int unreadCount;

  _Conversation({
    required this.otherUserId,
    required this.lastMessage,
    required this.unreadCount,
  });
}

class _ConversationTile extends StatelessWidget {
  final String otherUserId;
  final String displayName;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.otherUserId,
    required this.displayName,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
    required this.onTap,
  });

  String _formattedTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    } else if (dt.year == now.year) {
      return DateFormat('MMM d').format(dt);
    }
    return DateFormat('MMM d, y').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    return ListTile(
      leading: CircleAvatar(
        child: Text(
          otherUserId.isNotEmpty ? otherUserId[0].toUpperCase() : '?',
        ),
      ),
      title: Text(
        displayName,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formattedTime(timestamp),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (hasUnread) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}
