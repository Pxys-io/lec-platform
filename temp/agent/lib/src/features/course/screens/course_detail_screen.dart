import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../models/course.dart';
import '../../../models/quiz.dart';
import '../../../repositories/quiz_repository.dart';
import '../../../repositories/lesson_repository.dart';
import '../../../logic/lesson/lesson_cubit.dart';
import '../../../logic/auth/auth_cubit.dart';
import '../../../logic/downloads/downloads_cubit.dart';
import '../../../logic/downloads/downloads_state.dart';
import '../../report/report_dialog.dart';
import '../../documents/screens/document_viewer_screen.dart';
import 'enrollment_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final Course course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<LessonCubit>().loadLessons(widget.course.id);
  }

  Future<void> _handleLessonTap(BuildContext context, lesson) async {
    final isLocked = lesson.lockType == 'locked';
    if (isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This lesson is locked')),
      );
      return;
    }

    final user = context.read<AuthCubit>().state.user;
    final hasVideo = lesson.videoId != null;
    final hasQuiz = lesson.quizId != null;

    if (hasVideo) {
      if (context.mounted) {
        context.push('/video-player', extra: {
          'lessonId': lesson.id,
          'userEmail': user?.email ?? 'student@example.com',
          'studentId': user?.id ?? '0000',
        });
      }
      return;
    }

    if (hasQuiz) {
      try {
        final quizRepo = context.read<QuizRepository>();
        final quizData = await quizRepo.getQuiz(lesson.quizId);
        final questions = await quizRepo.getQuizQuestions(lesson.quizId);
        final quiz = Quiz(
          id: quizData.id,
          lessonId: quizData.lessonId,
          title: quizData.title,
          description: quizData.description,
          passingScore: quizData.passingScore,
          timeLimit: quizData.timeLimit,
          questions: questions,
          createdAt: quizData.createdAt,
        );
        if (context.mounted) {
          context.push('/quiz-session', extra: {
            'quiz': quiz,
            'isTutorMode': false,
          });
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load quiz: $e')),
          );
        }
      }
      return;
    }

    try {
      final lessonRepo = context.read<LessonRepository>();
      final materials = await lessonRepo.getMaterials(lesson.id);
      if (context.mounted) {
        if (materials.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DocumentViewerScreen(
                materials: materials,
                lessonTitle: lesson.title,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No content available for this lesson')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load materials: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.flag, color: Colors.white),
                onPressed: () => ReportDialog.show(context, targetType: 'course', targetId: widget.course.id),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.course.title, style: const TextStyle(color: Colors.white)),
              background: Container(
                color: Theme.of(context).colorScheme.primary,
                child: const Icon(LucideIcons.image, size: 80, color: Colors.white24),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(child: Icon(LucideIcons.user)),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Instructor', style: Theme.of(context).textTheme.bodySmall),
                          Text('Course Instructor', style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      const Spacer(),
                      const Icon(LucideIcons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      const Text('4.8'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Overview', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    widget.course.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Text('Curriculum', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
          ),
          BlocBuilder<LessonCubit, LessonState>(
            builder: (context, state) {
              if (state is LessonLoading) {
                return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                );
              } else if (state is LessonLoaded) {
                if (state.lessons.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: Text('No lessons available.')),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final lesson = state.lessons[index];
                      final isLocked = lesson.lockType == 'locked';
                      final hasVideo = lesson.videoId != null;
                      final hasQuiz = lesson.quizId != null;
                      
                      IconData icon = LucideIcons.fileText;
                      if (hasVideo) icon = LucideIcons.playCircle;
                      if (hasQuiz) icon = LucideIcons.helpCircle;
                      if (isLocked) icon = LucideIcons.lock;

                      return BlocBuilder<DownloadsCubit, DownloadsState>(
                        builder: (context, downloadState) {
                          final activeDownload = downloadState.active.where((d) => d.lessonId == lesson.id).firstOrNull;
                          final isDownloaded = downloadState.completed.any((d) => d.lessonId == lesson.id);

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Text('${index + 1}'),
                            ),
                            title: Text(lesson.title),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(lesson.description.isNotEmpty ? lesson.description : 'Lesson material'),
                                if (activeDownload != null) ...[
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(value: activeDownload.progress, minHeight: 2),
                                  Text('${(activeDownload.progress * 100).toStringAsFixed(0)}% downloading...', 
                                    style: const TextStyle(fontSize: 10, color: Colors.blue)),
                                ]
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasVideo && !isLocked) ...[
                                  if (activeDownload != null)
                                    IconButton(
                                      icon: const Icon(LucideIcons.xCircle, size: 20, color: Colors.red),
                                      onPressed: () => context.read<DownloadsCubit>().cancelDownload(lesson.id, '1080p'),
                                    )
                                  else if (isDownloaded)
                                    const Icon(LucideIcons.checkCircle, size: 20, color: Colors.green)
                                  else
                                    IconButton(
                                      icon: const Icon(LucideIcons.download, size: 20),
                                      onPressed: () => context.read<DownloadsCubit>().startDownload(
                                        lessonId: lesson.id,
                                        title: lesson.title,
                                        resolution: '1080p',
                                      ),
                                    ),
                                ],
                                const SizedBox(width: 8),
                                Icon(icon),
                              ],
                            ),
                            onTap: () => _handleLessonTap(context, lesson),
                          );
                        },
                      );
                    },
                    childCount: state.lessons.length,
                  ),
                );
              } else if (state is LessonFailure) {
                return SliverToBoxAdapter(
                  child: Center(child: Text('Error: ${state.message}')),
                );
              }
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EnrollmentScreen(course: widget.course),
              ),
            );
          },
          child: const Text('Enroll Now / Request Access'),
        ),
      ),
    );
  }
}
