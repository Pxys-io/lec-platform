import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../logic/auth/auth_cubit.dart';
import '../../../logic/course/course_cubit.dart';
import '../../../logic/stats/stats_cubit.dart';
import '../../../models/user.dart';
import '../../../widgets/app_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _UserAvatar(user: user),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  user?.fullName.isNotEmpty == true ? user!.fullName : 'Student',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 16),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.messageSquare),
            tooltip: 'Inbox',
            onPressed: () => context.push('/inbox'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            context.read<CourseCubit>().loadCourses(),
            context.read<StatsCubit>().loadStats(),
          ]);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionHeader(title: 'Continue Learning'),
              const SizedBox(height: 12),
              BlocBuilder<StatsCubit, StatsState>(
                builder: (context, state) {
                  if (state is StatsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is StatsLoaded &&
                      state.continueWatching.isNotEmpty) {
                    final item = state.continueWatching.first;
                    final progress = (item['completion_percentage'] as num?)
                            ?.toDouble() ??
                        0.0;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 80,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer.withValues(
                                  alpha: 0.4,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(LucideIcons.play),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['lesson_title']?.toString() ??
                                        'Continue Lesson',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: (progress / 100).clamp(0.0, 1.0),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${progress.toStringAsFixed(0)}% completed',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () {
                                final user = context.read<AuthCubit>().state.user;
                                context.push('/video-player', extra: {
                                  'lessonId': item['lesson_id'],
                                  'userEmail': user?.email ?? '',
                                  'studentId': user?.id ?? '',
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                minimumSize: const Size(0, 36),
                              ),
                              child: const Text('Resume'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return AppEmptyState(
                    icon: LucideIcons.playCircle,
                    title: 'No recent activity',
                    message: 'Start watching a lesson to pick up where you left off.',
                  );
                },
              ),
              const SizedBox(height: 24),
              const AppSectionHeader(title: 'Quick View'),
              const SizedBox(height: 12),
              BlocBuilder<StatsCubit, StatsState>(
                builder: (context, state) {
                  if (state is StatsLoaded) {
                    final stats = state.overview;
                    return Row(
                      children: [
                        Expanded(
                          child: AppStatCard(
                            icon: LucideIcons.bookOpen,
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
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 24),
              const AppSectionHeader(title: 'My Courses'),
              const SizedBox(height: 12),
              BlocBuilder<CourseCubit, CourseState>(
                builder: (context, state) {
                  if (state is CourseLoading) {
                    return const AppSkeletonList(itemCount: 2);
                  }
                  if (state is CourseLoaded) {
                    if (state.courses.isEmpty) {
                      return AppEmptyState(
                        icon: LucideIcons.bookOpen,
                        title: 'No courses yet',
                        message: 'Browse the Discover tab to find courses.',
                      );
                    }
                    final courses = state.courses.take(4).toList();
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.8,
                          ),
                      itemCount: courses.length,
                      itemBuilder: (context, index) {
                        final course = courses[index];
                        return AppCourseCard(
                          title: course.title,
                          subtitle: course.visibility,
                          thumbnailUrl: course.thumbnailUrl,
                          onTap: () =>
                              context.push('/course-detail', extra: course),
                        );
                      },
                    );
                  }
                  if (state is CourseFailure) {
                    return AppErrorState(
                      message: state.message,
                      onRetry: () => context.read<CourseCubit>().loadCourses(),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final User? user;

  const _UserAvatar({this.user});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = user?.fullName.trim() ?? '';
    final initials = name.isNotEmpty
        ? name.split(RegExp(r'\s+')).take(2).map((p) => p[0]).join().toUpperCase()
        : '?';
    return CircleAvatar(
      radius: 18,
      backgroundColor: colors.primaryContainer,
      foregroundColor: colors.primary,
      child: Text(
        initials,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}