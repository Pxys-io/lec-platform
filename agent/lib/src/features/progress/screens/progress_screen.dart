import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../logic/stats/stats_cubit.dart';

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
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildStatCard(context, 'Enrolled Courses', stats.totalCourses.toString(), LucideIcons.book),
                      const SizedBox(width: 16),
                      _buildStatCard(context, 'Completed Lessons', stats.totalLessons.toString(), LucideIcons.checkCircle),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatCard(context, 'Quizzes Taken', stats.totalQuizzes.toString(), LucideIcons.helpCircle),
                      const SizedBox(width: 16),
                      _buildStatCard(context, 'Watch Time (hrs)', (stats.totalWatchTime / 3600).toStringAsFixed(1), LucideIcons.playCircle),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Learning Activity', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Container(
                    height: 200,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                    ),
                    child: BarChart(
                      BarChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 8, color: Theme.of(context).colorScheme.primary)]),
                          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 10, color: Theme.of(context).colorScheme.primary)]),
                          BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 14, color: Theme.of(context).colorScheme.primary)]),
                          BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 15, color: Theme.of(context).colorScheme.primary)]),
                          BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 13, color: Theme.of(context).colorScheme.primary)]),
                          BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 10, color: Theme.of(context).colorScheme.primary)]),
                          BarChartGroupData(x: 6, barRods: [BarChartRodData(toY: 8, color: Theme.of(context).colorScheme.primary)]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Achievements', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildAchievementBadge(context, LucideIcons.zap, 'Fast Learner', stats.totalLessons > 5),
                      _buildAchievementBadge(context, LucideIcons.award, 'Top Scorer', stats.totalQuizzes > 0),
                      _buildAchievementBadge(context, LucideIcons.trendingUp, 'Consistent', stats.totalWatchTime > 3600),
                      _buildAchievementBadge(context, LucideIcons.shield, 'Verified', true),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Timeline', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  _buildTimelineItem(context, 'Completed Lesson', 'Pharmacology Intro', '2 hours ago'),
                  _buildTimelineItem(context, 'Passed Quiz', 'Cardiology Basics', 'Yesterday'),
                  _buildTimelineItem(context, 'Enrolled', 'Anatomy 101', '3 days ago'),
                ],
              ),
            );
          } else if (state is StatsFailure) {
            return Center(child: Text(state.message));
          }
          return const Center(child: Text('Start learning to see your progress!'));
        },
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementBadge(BuildContext context, IconData icon, String label, bool unlocked) {
    return Column(
      children: [
        Opacity(
          opacity: unlocked ? 1.0 : 0.3,
          child: CircleAvatar(
            radius: 30,
            backgroundColor: unlocked ? Theme.of(context).colorScheme.primaryContainer : Colors.grey[200],
            child: Icon(icon, color: unlocked ? Theme.of(context).colorScheme.primary : Colors.grey),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: unlocked ? null : Colors.grey,
        )),
      ],
    );
  }

  Widget _buildTimelineItem(BuildContext context, String title, String subtitle, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(time, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
