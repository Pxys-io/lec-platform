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
        title: const Text('Performance'),
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
                      _buildStatCard(context, 'Total Students', stats.totalUsers.toString(), LucideIcons.users),
                      const SizedBox(width: 16),
                      _buildStatCard(context, 'Total Courses', stats.totalCourses.toString(), LucideIcons.book),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatCard(context, 'Total Lessons', stats.totalLessons.toString(), LucideIcons.playCircle),
                      const SizedBox(width: 16),
                      _buildStatCard(context, 'Active Quizzes', stats.totalQuizzes.toString(), LucideIcons.helpCircle),
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
                      _buildAchievementBadge(context, LucideIcons.zap, 'Fast Learner'),
                      _buildAchievementBadge(context, LucideIcons.award, 'Top Scorer'),
                      _buildAchievementBadge(context, LucideIcons.trendingUp, 'Consistent'),
                      _buildAchievementBadge(context, LucideIcons.shield, 'Verified'),
                    ],
                  ),
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

  Widget _buildAchievementBadge(BuildContext context, IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
