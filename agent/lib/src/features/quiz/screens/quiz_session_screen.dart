import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../models/quiz.dart';
import '../../../repositories/quiz_repository.dart';

/// Lesson quiz session (exam mode) and tutor practice.
///
/// Answers are submitted as option TEXT (server scores by exact text match
/// against correct_answer). Letters (A/B/C) are display-only.
class QuizSessionScreen extends StatefulWidget {
  final Quiz quiz;
  final bool isTutorMode;

  const QuizSessionScreen({
    super.key,
    required this.quiz,
    this.isTutorMode = true,
  });

  @override
  State<QuizSessionScreen> createState() => _QuizSessionScreenState();
}

class _QuizSessionScreenState extends State<QuizSessionScreen> {
  int _currentQuestionIndex = 0;
  final Map<String, String> _userAnswers = {};
  final Set<String> _flagged = {};
  int _remainingSeconds = 0;
  Timer? _timer;
  bool _isSubmitted = false;
  Map<String, dynamic>? _result;
  bool _isSubmitting = false;
  Map<String, dynamic>? _previousAttempt;
  bool _loadingPrevious = true;

  bool get _timed =>
      widget.quiz.timeLimit != null && widget.quiz.timeLimit! > 0;

  @override
  void initState() {
    super.initState();
    if (_timed) {
      _remainingSeconds = widget.quiz.timeLimit! * 60;
      _startTimer();
    }
    _loadPreviousAttempt();
  }

  Future<void> _loadPreviousAttempt() async {
    try {
      final repo = context.read<QuizRepository>();
      final prev = await repo.getResults(widget.quiz.id);
      if (mounted) setState(() => _previousAttempt = prev);
    } catch (_) {
      // No previous attempt yet - not an error.
    } finally {
      if (mounted) setState(() => _loadingPrevious = false);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        _submitQuiz();
      }
    });
  }

  String get _formattedTime {
    final min = _remainingSeconds ~/ 60;
    final sec = _remainingSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _isCorrect(Question q) {
    final given = (_userAnswers[q.id] ?? '').trim().toLowerCase();
    return given.isNotEmpty && given == q.correctAnswer.trim().toLowerCase();
  }

  int get _unansweredCount => widget.quiz.questions
      .where((q) => !(_userAnswers[q.id]?.trim().isNotEmpty ?? false))
      .length;

  Future<void> _confirmAndSubmit() async {
    if (_isSubmitting || _isSubmitted) return;
    if (_unansweredCount > 0 && mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Submit quiz?'),
          content: Text(
            '$_unansweredCount of ${widget.quiz.questions.length} questions are unanswered.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep answering'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Submit anyway'),
            ),
          ],
        ),
      );
      if (go != true) return;
    }
    await _submitQuiz();
  }

  Future<void> _submitQuiz() async {
    if (_isSubmitting || _isSubmitted) return;
    setState(() => _isSubmitting = true);
    _timer?.cancel();
    try {
      final result = await context
          .read<QuizRepository>()
          .submitQuiz(widget.quiz.id, Map<String, String>.from(_userAnswers));
      if (mounted) {
        setState(() {
          _isSubmitted = true;
          _result = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit quiz: $e')),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _retake() {
    _timer?.cancel();
    setState(() {
      _currentQuestionIndex = 0;
      _userAnswers.clear();
      _flagged.clear();
      _isSubmitted = false;
      _result = null;
      _isSubmitting = false;
      if (_timed) {
        _remainingSeconds = widget.quiz.timeLimit! * 60;
        _startTimer();
      }
    });
  }

  void _goToQuestion(int index) {
    setState(() => _currentQuestionIndex = index.clamp(
      0,
      widget.quiz.questions.length - 1,
    ));
  }

  void _popWithResult() {
    Navigator.of(context).pop(_result?['passed'] == true);
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.quiz.questions;

    if (_isSubmitted) {
      return _buildResultsScreen(context, questions);
    }

    final current = questions.isNotEmpty
        ? questions[_currentQuestionIndex.clamp(0, questions.length - 1)]
        : null;
    final currentAnswer =
        current != null ? _userAnswers[current.id] : null;
    final answeredInTutor =
        widget.isTutorMode && (currentAnswer?.trim().isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Column(
          children: [
            LinearProgressIndicator(
              value: questions.isNotEmpty
                  ? (_currentQuestionIndex + 1) / questions.length
                  : 0,
            ),
            if (_timed)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _formattedTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: _remainingSeconds < 60 ? Colors.red : null,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          if (current != null)
            IconButton(
              icon: Icon(
                _flagged.contains(current.id)
                    ? LucideIcons.flag
                    : LucideIcons.flagOff,
                color: _flagged.contains(current.id) ? Colors.amber : null,
              ),
              tooltip: 'Flag for review',
              onPressed: () => setState(() {
                if (!_flagged.remove(current.id)) {
                  _flagged.add(current.id);
                }
              }),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'submit') _confirmAndSubmit();
              if (value == 'overview') _showOverviewSheet(context, questions);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'overview',
                child: Text('Question overview'),
              ),
              const PopupMenuItem(
                value: 'submit',
                child: Text('Submit Quiz'),
              ),
            ],
          ),
        ],
      ),
      body: questions.isEmpty
          ? const Center(child: Text('No questions available'))
          : Column(
              children: [
                if (!_loadingPrevious && _previousAttempt != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: Colors.blue.withOpacity(0.08),
                    child: Text(
                      'Previous attempt: ${((_previousAttempt!['score'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}% • ${(_previousAttempt!['passed'] as bool? ?? false) ? 'Passed' : 'Not passed'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Question ${_currentQuestionIndex + 1} of ${questions.length}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Row(
                              children: [
                                if (current != null &&
                                    _flagged.contains(current.id))
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(
                                      LucideIcons.flag,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                  ),
                                Text(
                                  '${_userAnswers.length} answered',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          current!.text,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        ...current.options.asMap().entries.map((entry) {
                          final optionIndex = entry.key;
                          final optionText = entry.value;
                          final optionLabel =
                              String.fromCharCode(65 + optionIndex);
                          final isSelected =
                              currentAnswer == optionText;
                          // Tutor feedback compares TEXT, matching the server.
                          final isCorrectOption = optionText.trim()
                                  .toLowerCase() ==
                              current.correctAnswer.trim().toLowerCase();

                          Color? tileColor;
                          Color borderColor = Colors.grey[300]!;
                          if (answeredInTutor) {
                            if (isCorrectOption) {
                              tileColor = Colors.green.withOpacity(0.12);
                              borderColor = Colors.green;
                            } else if (isSelected) {
                              tileColor = Colors.red.withOpacity(0.1);
                              borderColor = Colors.red;
                            }
                          } else if (isSelected) {
                            tileColor = Theme.of(context)
                                .colorScheme
                                .primaryContainer;
                            borderColor =
                                Theme.of(context).colorScheme.primary;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () => setState(() {
                                _userAnswers[current.id] = optionText;
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: tileColor,
                                  border: Border.all(color: borderColor),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Colors.transparent,
                                      child: Text(
                                        optionLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(optionText)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        if (answeredInTutor) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: (_isCorrect(current)
                                      ? Colors.green
                                      : Colors.red)
                                  .withOpacity(0.07),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isCorrect(current)
                                      ? 'Correct'
                                      : 'Not quite',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: _isCorrect(current)
                                            ? Colors.green[800]
                                            : Colors.red[800],
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Correct answer: ${current.correctAnswer}',
                                ),
                                if ((current.explanation ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(current.explanation!),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentQuestionIndex > 0)
                        OutlinedButton(
                          onPressed: () =>
                              _goToQuestion(_currentQuestionIndex - 1),
                          child: const Text('Previous'),
                        )
                      else
                        const SizedBox(width: 96),
                      if (_flagged.isNotEmpty)
                        Text(
                          '${_flagged.length} flagged',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.amber,
                          ),
                        ),
                      ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                if (_currentQuestionIndex <
                                    questions.length - 1) {
                                  _goToQuestion(
                                      _currentQuestionIndex + 1);
                                } else {
                                  await _confirmAndSubmit();
                                }
                              },
                        child: Text(
                          _currentQuestionIndex < questions.length - 1
                              ? 'Next'
                              : (_isSubmitting
                                  ? 'Submitting...'
                                  : 'End Session'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _showOverviewSheet(
    BuildContext context,
    List<Question> questions,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: questions.asMap().entries.map((e) {
            final i = e.key;
            final q = e.value;
            final answered =
                (_userAnswers[q.id]?.trim().isNotEmpty ?? false);
            return InkWell(
              onTap: () {
                Navigator.of(ctx).pop();
                _goToQuestion(i);
              },
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == _currentQuestionIndex
                      ? Theme.of(context).colorScheme.primary
                      : answered
                          ? Colors.green.withOpacity(0.25)
                          : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: _flagged.contains(q.id)
                      ? Border.all(color: Colors.amber, width: 2)
                      : null,
                ),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: i == _currentQuestionIndex
                        ? Colors.white
                        : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildResultsScreen(
    BuildContext context,
    List<Question> questions,
  ) {
    final score = (_result?['score'] as num?)?.toDouble() ?? 0;
    final passed = _result?['passed'] as bool? ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: _popWithResult,
        ),
        title: const Text('Results'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              passed ? LucideIcons.checkCircle : LucideIcons.xCircle,
              size: 72,
              color: passed ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              passed ? 'Passed!' : 'Not passed yet',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: passed ? Colors.green : Colors.red,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '${score.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Passing score: ${widget.quiz.passingScore.toStringAsFixed(0)}% • ${_userAnswers.length} of ${questions.length} answered',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _retake,
                  icon: const Icon(LucideIcons.rotateCcw),
                  label: const Text('Retake'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _popWithResult,
                  icon: const Icon(LucideIcons.arrowLeft),
                  label: const Text('Back to Course'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Review',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            ...questions.asMap().entries.map((e) {
              final i = e.key;
              final q = e.value;
              final given = _userAnswers[q.id];
              final ok = _isCorrect(q);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            ok
                                ? LucideIcons.checkCircle
                                : LucideIcons.xCircle,
                            size: 18,
                            color: ok ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Q${i + 1}. ${q.text}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your answer: ${given?.trim().isNotEmpty == true ? given : '—'}',
                        style: TextStyle(
                          color: ok ? Colors.green[800] : Colors.red[800],
                        ),
                      ),
                      if (!ok) ...[
                        const SizedBox(height: 4),
                        Text('Correct answer: ${q.correctAnswer}'),
                      ],
                      if ((q.explanation ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          q.explanation!,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
