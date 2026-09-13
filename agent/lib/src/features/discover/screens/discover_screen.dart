import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../logic/course/course_cubit.dart';
import '../../../models/course.dart';
import '../../../widgets/app_widgets.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _query = '';
  String? _category;

  @override
  void initState() {
    super.initState();
    // Courses are shared with Home; ensure they're loaded if not already.
    final cubit = context.read<CourseCubit>();
    if (cubit.state is! CourseLoaded) {
      cubit.loadCourses();
    }
  }

  List<Course> _filter(List<Course> courses) {
    final q = _query.trim().toLowerCase();
    return courses.where((c) {
      final matchesQuery = q.isEmpty ||
          c.title.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q) ||
          c.tags.any((t) => t.toLowerCase().contains(q));
      final matchesCategory =
          _category == null || c.tags.contains(_category);
      return matchesQuery && matchesCategory;
    }).toList();
  }

  List<String> _categories(List<Course> courses) {
    final tags = <String>{};
    for (final c in courses) {
      tags.addAll(c.tags);
    }
    return tags.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search courses...',
                prefixIcon: const Icon(LucideIcons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x),
                        onPressed: () => setState(() => _query = ''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          BlocBuilder<CourseCubit, CourseState>(
            builder: (context, state) {
              if (state is! CourseLoaded) return const SizedBox.shrink();
              final categories = _categories(state.courses);
              if (categories.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('All'),
                        selected: _category == null,
                        onSelected: (_) => setState(() => _category = null),
                      ),
                    ),
                    ...categories.map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category),
                          selected: _category == category,
                          onSelected: (_) =>
                              setState(() => _category = category),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: BlocBuilder<CourseCubit, CourseState>(
              builder: (context, state) {
                if (state is CourseLoading) {
                  return const AppSkeletonList(itemCount: 5);
                } else if (state is CourseLoaded) {
                  final courses = _filter(state.courses);
                  if (courses.isEmpty) {
                    return AppEmptyState(
                      icon: LucideIcons.searchX,
                      title: 'No courses found',
                      message: _query.isNotEmpty
                          ? 'Nothing matches "$_query". Try a different search.'
                          : 'No courses in this category yet.',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: courses.length,
                    itemBuilder: (context, index) {
                      final course = courses[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer.withValues(
                                alpha: 0.4,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: course.thumbnailUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      course.thumbnailUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(
                                        LucideIcons.bookOpen,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    LucideIcons.bookOpen,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                          ),
                          title: Text(course.title),
                          subtitle: Text(
                            course.tags.isNotEmpty
                                ? course.tags.join(', ')
                                : course.visibility,
                          ),
                          trailing: const Icon(LucideIcons.chevronRight),
                          onTap: () {
                            context.push('/course-detail', extra: course);
                          },
                        ),
                      );
                    },
                  );
                } else if (state is CourseFailure) {
                  return AppErrorState(
                    message: state.message,
                    onRetry: () => context.read<CourseCubit>().loadCourses(),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}