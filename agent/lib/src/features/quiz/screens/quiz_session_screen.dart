import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons_flutter.dart';
import '../../../models/quiz.dart';
import '../../../logic/qbank/qbank_cubit.dart';

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
  bool _showRationale = false;
  int _remainingSeconds = 0;
  Timer? _timer;
  bool _isSubmitted = false;
  Map<String, dynamic>? _result;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.quiz.timeLimit != null && widget.quiz.timeLimit! > 0) {
      _remainingSeconds = widget.quiz.timeLimit! * 60;
      _startTimer();
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

  Future<void> _submitQuiz() async {
    if (_isSubmitting || _isSubmitted) return;
    setState(() => _isSubmitting = true);
    _timer?.cancel();
    try {
      final result = await context.read<QBankCubit>().submitQuiz(widget.quiz.id, _userAnswers);
      if (mounted) {
        setState(() {
          _isSubmitted = true;
          _result = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit quiz: $e')));
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _goToQuestion(int index) {
    setState(() {
      _currentQuestionIndex = index;
      _showRationale = widget.isTutorMode && _userAnswers.containsKey(widget.quiz.questions[index].id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.quiz.questions;

    if (_isSubmitted) {
      return _buildResultsScreen(context, questions);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            LinearProgressIndicator(
              value: questions.isNotEmpty ? (_currentQuestionIndex + 1) / questions.length : 0,
            ),
            if (widget.quiz.timeLimit != null && widget.quiz.timeLimit! > 0)
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
          IconButton(
            icon: const Icon(LucideIcons.flag),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'submit') _submitQuiz();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'submit', child: Text('Submit Quiz')),
            ],
          ),
        ],
      ),
      body: questions.isEmpty
        ? const Center(child: Text('No questions available'))
        : Column(
            children: [
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
                          Text(
                            '${_userAnswers.length} answered',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        questions[_currentQuestionIndex].text,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      ...questions[_currentQuestionIndex].options.asMap().entries.map((entry) {
                        final optionIndex = entry.key;
                        final optionText = entry.value;
                        final optionLabel = String.fromCharCode(65 + optionIndex);
                        final isSelected = _userAnswers[questions[_currentQuestionIndex].id] == optionLabel;
                        final isCorrect = questions[_currentQuestionIndex].correctAnswer == optionLabel;

                        Color? tileColor;
                        if (_showRationale) {
                          if (isCorrect) tileColor = Colors.green.withOpacity(0.1);
                          else if (isSelected) tileColor = Colors.red.withOpacity(0.1);
                        } else if (isSelected) {
                          tileColor = Theme.of(context).colorScheme.primaryContainer;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: _showRationale ? null : () {
                              setState(() {
                                _userAnswers[questions[_currentQuestionIndex].id] = optionLabel;
                                if (widget.isTutorMode) _showRationale = true;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: tileColor,
                                border: Border.all(
                                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[300]!,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                    child: Text(
                                      optionLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isSelected ? Colors.white : Colors.black,
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
                      }).toList(),
                      if (_showRationale) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Explanation', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Text('Correct: ${questions[_currentQuestionIndex].correctAnswer}'),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (widget.quiz.timeLimit == null || widget.quiz.timeLimit == 0)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentQuestionIndex > 0)
                        OutlinedButton(
                          onPressed: () => _goToQuestion(_currentQuestionIndex - 1),
                          child: const Text('Previous'),
                        )
                      else
                        const SizedBox(),
                      ElevatedButton(
                        onPressed: () async {
                          if (_currentQuestionIndex < questions.length - 1) {
                            _goToQuestion(_currentQuestionIndex + 1);
                          } else {
                            await _submitQuiz();
                          }
                        },
                        child: Text(_currentQuestionIndex < questions.length - 1 ? 'Next' : 'End Session'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
    );
  }

  Widget _buildResultsScreen(BuildContext context, List<Question> questions) {
    final score = (_result?['score'] as num?)?.toDouble() ?? 0;
    final passed = _result?['passed'] as bool? ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Results'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                passed ? LucideIcons.checkCircle : LucideIcons.xCircle,
                size: 80,
                color: passed ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 24),
              Text(
                passed ? 'Passed!' : 'Failed',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: passed ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${score.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Passing score: ${widget.quiz.passingScore.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                '${_userAnswers.length} of ${questions.length} answered',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(LucideIcons.arrowLeft),
                label: const Text('Back to Course'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}