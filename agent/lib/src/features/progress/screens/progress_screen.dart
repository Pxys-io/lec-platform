import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../logic/stats/stats_cubit.dart';
import '../../../logic/auth/auth_cubit.dart';
import '../../../widgets/app_widgets.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Progress'),
      ),
      body: BlocBuilder<StatsCubit, StatsState>(
        builder: (context, state) {
          if (state is StatsLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is StatsLoaded) {
            final stats = state.overview;
            return RefreshIndicator(
              onRefresh: () => context.read<StatsCubit>().loadStats(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppStatCard(
                            icon: LucideIcons.book,
                            label: 'Courses',
                            value: stats.totalCourses.toString(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppStatCard(
                            icon: LucideIcons.checkCircle,
                            label: 'Completed',
                            value: stats.totalLessons.toString(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppStatCard(
                            icon: LucideIcons.clock,
                            label: 'Hours',
                            value: (stats.totalWatchTime / 3600)
                                .toStringAsFixed(1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const AppSectionHeader(title: 'Continue Watching'),
                    const SizedBox(height: 12),
                    if (state.continueWatching.isEmpty)
                      AppEmptyState(
                        icon: LucideIcons.playCircle,
                        title: 'Nothing in progress',
                        message:
                            'Videos you start will show up here so you can pick up where you left off.',
                      )
                    else
                      ...state.continueWatching.map(
                        (item) => _ContinueWatchingTile(item: item),
                      ),
                    const SizedBox(height: 24),
                    const AppSectionHeader(title: 'Achievements'),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildAchievementBadge(
                          context,
                          LucideIcons.zap,
                          'Fast Learner',
                          stats.totalLessons > 5,
                        ),
                        _buildAchievementBadge(
                          context,
                          LucideIcons.trendingUp,
                          'Consistent',
                          stats.totalWatchTime > 3600,
                        ),
                        _buildAchievementBadge(
                          context,
                          LucideIcons.bookOpen,
                          'Explorer',
                          stats.totalCourses > 1,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          } else if (state is StatsFailure) {
            return AppErrorState(
              message: state.message,
              onRetry: () => context.read<StatsCubit>().loadStats(),
            );
          }
          return AppEmptyState(
            icon: LucideIcons.barChart,
            title: 'No progress yet',
            message: 'Start learning to see your progress!',
          );
        },
      ),
    );
  }

  Widget _buildAchievementBadge(
    BuildContext context,
    IconData icon,
    String label,
    bool unlocked,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Opacity(
          opacity: unlocked ? 1.0 : 0.3,
          child: CircleAvatar(
            radius: 30,
            backgroundColor:
                unlocked ? colors.primaryContainer : colors.surfaceContainerHighest,
            child: Icon(
              icon,
              color: unlocked ? colors.primary : colors.outline,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: unlocked ? null : colors.outline,
              ),
        ),
      ],
    );
  }
}

class _ContinueWatchingTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _ContinueWatchingTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final progress =
        (item['completion_percentage'] as num?)?.toDouble() ?? 0.0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primaryContainer.withValues(
                alpha: 0.5,
              ),
          child: Icon(
            LucideIcons.play,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(item['lesson_title']?.toString() ?? 'Lesson'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['course_title']?.toString() ?? ''),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (progress / 100).clamp(0.0, 1.0),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text(
              '${progress.toStringAsFixed(0)}% • ${_formatPosition((item['last_position'] as num?)?.toDouble() ?? 0)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: const Icon(LucideIcons.chevronRight),
        onTap: () {
          final user = context.read<AuthCubit>().state.user;
          context.push('/video-player', extra: {
            'lessonId': item['lesson_id'],
            'courseId': item['course_id'],
            'userEmail': user?.email ?? '',
            'studentId': user?.id ?? '',
          });
        },
      ),
    );
  }

  String _formatPosition(double seconds) {
    final d = Duration(seconds: seconds.round());
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}