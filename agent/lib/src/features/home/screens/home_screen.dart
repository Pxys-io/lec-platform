import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../logic/auth/auth_cubit.dart';
import '../../../logic/auth/auth_state.dart';
import '../../../logic/course/course_cubit.dart';
import '../../../logic/stats/stats_cubit.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state.user;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: user?.avatarUrl != null 
                ? NetworkImage(user!.avatarUrl!) 
                : const NetworkImage('https://i.pravatar.cc/150'),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  user?.fullName ?? 'Student',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.flame, color: Colors.orange),
            onPressed: () {},
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(right: 16),
              child: Text('14 Days', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<CourseCubit>().loadCourses();
          context.read<StatsCubit>().loadStats();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Continue Learning', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              BlocBuilder<StatsCubit, StatsState>(
                builder: (context, state) {
                  if (state is StatsLoaded && state.continueWatching.isNotEmpty) {
                    final lastItem = state.continueWatching.first;
                    return Card(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 80,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
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
                                    lastItem['lesson_title'] ?? 'Continue Lesson',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(value: (lastItem['progress'] ?? 0) / 100),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${lastItem['progress'] ?? 0}% completed',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () {
                                // context.push('/video-player', extra: { ... });
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                minimumSize: const Size(0, 36),
                              ),
                              child: const Text('Resume'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No recent activity. Start learning today!'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('Quick View', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              BlocBuilder<StatsCubit, StatsState>(
                builder: (context, state) {
                  if (state is StatsLoaded) {
                    final stats = state.overview;
                    return Row(
                      children: [
                        _buildQuickStat(context, 'Lessons', stats.totalLessons.toString(), LucideIcons.playCircle),
                        const SizedBox(width: 12),
                        _buildQuickStat(context, 'Quizzes', stats.totalQuizzes.toString(), LucideIcons.helpCircle),
                        const SizedBox(width: 12),
                        _buildQuickStat(context, 'Hours', (stats.totalWatchTime / 3600).toStringAsFixed(1), LucideIcons.clock),
                      ],
                    );
                  }
                  return const SizedBox();
                },
              ),
              const SizedBox(height: 24),
              Text('My Courses', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              BlocBuilder<CourseCubit, CourseState>(
                builder: (context, state) {
                  if (state is CourseLoaded) {
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: state.courses.length > 4 ? 4 : state.courses.length,
                      itemBuilder: (context, index) {
                        final course = state.courses[index];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => context.push('/course-detail', extra: course),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 100,
                                  color: Colors.grey[200],
                                  child: const Center(child: Icon(LucideIcons.book, size: 40)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        course.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Course Detail',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat(BuildContext context, String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
