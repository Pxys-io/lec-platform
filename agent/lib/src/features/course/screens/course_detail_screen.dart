import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

  static bool _isLocked(lesson) {
    // Backend lock values: none | previous_lesson | quiz ('locked' kept for
    // backward compatibility with older payloads).
    return lesson.lockType != 'none';
  }

  Future<Quiz?> _loadQuizForLesson(BuildContext context, lesson) async {
    final quizRepo = context.read<QuizRepository>();
    final quizData = await quizRepo.getQuiz(lesson.quizId);
    final questions = await quizRepo.getQuizQuestions(lesson.quizId);
    return Quiz(
      id: quizData.id,
      lessonId: quizData.lessonId,
      title: quizData.title,
      description: quizData.description,
      passingScore: quizData.passingScore,
      timeLimit: quizData.timeLimit,
      questions: questions.isNotEmpty ? questions : quizData.questions,
      createdAt: quizData.createdAt,
    );
  }

  Future<bool> _openQuiz(
    BuildContext context,
    lesson, {
    bool tutorMode = false,
  }) async {
    try {
      final quiz = await _loadQuizForLesson(context, lesson);
      if (quiz == null || !context.mounted) return false;
      final passed = await context.push('/quiz-session', extra: {
        'quiz': quiz,
        'isTutorMode': tutorMode,
      });
      if (passed == true && context.mounted) {
        // A pass can unlock gated lessons - refresh the list.
        context.read<LessonCubit>().loadLessons(widget.course.id);
      }
      return passed == true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load quiz: $e')),
        );
      }
      return false;
    }
  }

  Future<void> _openVideo(BuildContext context, lesson) async {
    final user = context.read<AuthCubit>().state.user;
    if (context.mounted) {
      await context.push('/video-player', extra: {
        'lessonId': lesson.id,
        'userEmail': user?.email ?? 'student@example.com',
        'studentId': user?.id ?? '0000',
      });
      // Watching can satisfy "previous lesson" gates - refresh on return.
      if (context.mounted) {
        context.read<LessonCubit>().loadLessons(widget.course.id);
      }
    }
  }

  Future<void> _handleLockedTap(
    BuildContext context,
    lesson,
    List<dynamic> lessons,
  ) async {
    final sorted = List.of(lessons)
      ..sort((a, b) => (a.order as int).compareTo(b.order as int));
    dynamic prev;
    for (final l in sorted) {
      if ((l.order as int) < (lesson.order as int)) prev = l;
    }
    final message = lesson.lockType == 'quiz'
        ? 'This lesson is quiz-gated. Pass the previous lesson\u2019s quiz to unlock it.'
        : 'Finish the previous lesson to unlock this one.';
    if (!context.mounted) return;
    final goToQuiz = prev != null && prev.quizId != null;
    final action = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lesson locked'),
        content: Text(goToQuiz
            ? '$message\n\nPrevious: ${prev.title}'
            : message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('OK'),
          ),
          if (goToQuiz)
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Take prerequisite quiz'),
            ),
        ],
      ),
    );
    if (action == true && context.mounted) {
      await _openQuiz(context, prev);
    }
  }

  Future<void> _handleLessonTap(BuildContext context, lesson) async {
    final state = context.read<LessonCubit>().state;
    final lessons =
        state is LessonLoaded ? state.lessons : [lesson];

    if (_isLocked(lesson)) {
      await _handleLockedTap(context, lesson, lessons);
      return;
    }

    final hasVideo = lesson.videoId != null;
    final hasQuiz = lesson.quizId != null;

    if (hasVideo && hasQuiz) {
      // Mixed lesson: let the student choose instead of hiding the quiz.
      if (!context.mounted) return;
      final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(LucideIcons.playCircle),
                title: const Text('Watch video'),
                onTap: () => Navigator.of(ctx).pop('video'),
              ),
              ListTile(
                leading: const Icon(LucideIcons.helpCircle),
                title: const Text('Take quiz'),
                onTap: () => Navigator.of(ctx).pop('quiz'),
              ),
            ],
          ),
        ),
      );
      if (!context.mounted) return;
      if (choice == 'video') {
        await _openVideo(context, lesson);
      } else if (choice == 'quiz') {
        await _openQuiz(context, lesson);
      }
      return;
    }

    if (hasVideo) {
      await _openVideo(context, lesson);
      return;
    }

    if (hasQuiz) {
      await _openQuiz(context, lesson);
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
                      final isLocked = _isLocked(lesson);
                      final hasVideo = lesson.videoId != null;
                      final hasQuiz = lesson.quizId != null;

                      IconData icon = LucideIcons.fileText;
                      if (hasVideo) icon = LucideIcons.playCircle;
                      if (hasQuiz) icon = LucideIcons.helpCircle;
                      if (hasVideo && hasQuiz) icon = LucideIcons.layers;
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
                                if (isLocked)
                                  Text(
                                    lesson.lockType == 'quiz'
                                        ? 'Locked — pass the previous quiz to unlock'
                                        : 'Locked — finish the previous lesson to unlock',
                                    style: const TextStyle(fontSize: 11, color: Colors.orange),
                                  ),
                                if (!isLocked && hasVideo && hasQuiz)
                                  const Text(
                                    'Video + quiz',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
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
