import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../logic/downloads/downloads_cubit.dart';
import '../../../logic/downloads/downloads_state.dart';
import '../../../logic/auth/auth_cubit.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Downloads'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => context.read<DownloadsCubit>().refresh(),
          ),
        ],
      ),
      body: BlocBuilder<DownloadsCubit, DownloadsState>(
        builder: (context, state) {
          if (state.isLoading &&
              state.completed.isEmpty &&
              state.active.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.completed.isEmpty && state.active.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.download, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'No downloads yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.active.isNotEmpty) ...[
                Text(
                  'Currently Downloading',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...state.active.map(
                  (item) => _buildActiveDownload(context, item),
                ),
                const SizedBox(height: 24),
              ],
              if (state.completed.isNotEmpty) ...[
                Text(
                  'Downloaded Videos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...state.completed.map(
                  (item) => _buildCompletedDownload(context, item),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildActiveDownload(BuildContext context, ActiveDownload item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(LucideIcons.downloadCloud, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${item.resolution} | ${item.downloadedSegments}/${item.totalSegments} segments',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.xCircle, color: Colors.red),
                  onPressed: () => context
                      .read<DownloadsCubit>()
                      .cancelDownload(item.lessonId, item.resolution),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: item.progress),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(item.progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedDownload(BuildContext context, CompletedDownload item) {
    final sizeMb = item.sizeInBytes / (1024 * 1024);
    final user = context.read<AuthCubit>().state.user;
    final hasMismatch = item.isModeMismatch;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: item.banned
                  ? Colors.red.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              child: Icon(
                item.banned ? LucideIcons.shieldOff : LucideIcons.check,
                color: item.banned ? Colors.red : Colors.green,
              ),
            ),
            title: Text(item.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.resolution} | ${sizeMb.toStringAsFixed(1)} MB'),
                if (hasMismatch) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: item.banned
                          ? Colors.red.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.banned
                          ? 'BANNED - Mode mismatch'
                          : 'Mode: ${item.modeWhenDownloaded}',
                      style: TextStyle(
                        fontSize: 10,
                        color: item.banned ? Colors.red : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                if (!item.banned)
                  const PopupMenuItem(
                    value: 'play',
                    child: Text('Play Offline'),
                  ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (val) {
                if (val == 'play' && !item.banned) {
                  context.push(
                    '/video-player',
                    extra: {
                      'lessonId': item.lessonId,
                      'userEmail': user?.email ?? 'student@example.com',
                      'studentId': user?.id ?? '0000',
                    },
                  );
                } else if (val == 'delete') {
                  context.read<DownloadsCubit>().deleteDownload(
                    item.lessonId,
                    item.resolution,
                  );
                }
              },
            ),
            onTap: () {
              if (!item.banned) {
                context.push(
                  '/video-player',
                  extra: {
                    'lessonId': item.lessonId,
                    'userEmail': user?.email ?? 'student@example.com',
                    'studentId': user?.id ?? '0000',
                  },
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'This download is banned due to server mode policy.',
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
