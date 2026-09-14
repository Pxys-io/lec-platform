import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../models/qbank.dart';
import '../../../models/quiz.dart';
import '../../../repositories/quiz_repository.dart';

/// QBank practice session. Tutor mode gives per-question feedback via the
/// backend check endpoint; timed mode collects answers and submits at the end.
/// Review after submit uses the grading returned by the submit endpoint.
class QBankSessionScreen extends StatefulWidget {
  final QBankSession session;
  final List<Question> questions;

  const QBankSessionScreen({
    super.key,
    required this.session,
    required this.questions,
  });

  @override
  State<QBankSessionScreen> createState() => _QBankSessionScreenState();
}

class _QBankSessionScreenState extends State<QBankSessionScreen> {
  int _currentIndex = 0;
  final Map<String, String> _answers = {};
  final Set<String> _flagged = {};
  final Map<String, Map<String, dynamic>> _tutorFeedback = {};
  Map<String, Map<String, dynamic>> _reviewAnswers = {};
  Map<String, dynamic>? _result;
  bool _checking = false;
  bool _submitting = false;
  bool _submitted = false;

  bool get _isTutor => (widget.session.config['mode'] ?? 'tutor') == 'tutor';

  Question? get _current =>
      widget.questions.isEmpty ? null : widget.questions[_currentIndex];

  int get _unanswered =>
      widget.questions.where((q) => !(_answers[q.id]?.trim().isNotEmpty ?? false)).length;

  Future<void> _checkCurrent() async {
    final q = _current;
    final answer = q != null ? _answers[q.id] ?? '' : '';
    if (q == null || answer.trim().isEmpty || _checking) return;
    setState(() => _checking = true);
    try {
      final res = await context.read<QuizRepository>().checkQBankAnswer(
            widget.session.id,
            q.id,
            answer,
          );
      if (mounted) {
        setState(() => _tutorFeedback[q.id] = res);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting || _submitted) return;
    if (_unanswered > 0 && mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Submit session?'),
          content: Text('$_unanswered of ${widget.questions.length} questions are unanswered.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep answering')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit anyway')),
          ],
        ),
      );
      if (go != true) return;
    }
    setState(() => _submitting = true);
    try {
      final result = await context.read<QuizRepository>().submitQBankSession(
            widget.session.id,
            Map<String, String>.from(_answers),
          );
      final graded = result['questions'];
      if (graded is List) {
        final map = <String, Map<String, dynamic>>{};
        for (final q in graded) {
          if (q is Map && q['id'] != null) map[q['id']] = Map<String, dynamic>.from(q);
        }
        _reviewAnswers = map;
      }
      if (mounted) {
        setState(() {
          _result = result;
          _submitted = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _retake() {
    setState(() {
      _currentIndex = 0;
      _answers.clear();
      _flagged.clear();
      _tutorFeedback.clear();
      _reviewAnswers = {};
      _result = null;
      _submitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildResults(context);
    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Practice Session')),
        body: const Center(child: Text('No questions in this session.')),
      );
    }
    final q = _current!;
    final currentAnswer = _answers[q.id] ?? '';
    final feedback = _tutorFeedback[q.id];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Q${_currentIndex + 1} of ${widget.questions.length}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(
              LucideIcons.flag,
              color: _flagged.contains(q.id) ? Colors.orange : null,
            ),
            onPressed: () => setState(() {
              if (_flagged.contains(q.id)) _flagged.remove(q.id);
              else _flagged.add(q.id);
            }),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: (_currentIndex + 1) / widget.questions.length,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q.text, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 20),
                      ...q.options.asMap().entries.map((entry) {
                        final oi = entry.key;
                        final opt = entry.value;
                        final selected = currentAnswer == opt;
                        final fb = feedback;
                        Color? tileColor;
                        Color borderColor = Colors.grey[300]!;
                        if (fb != null) {
                          final isCorrectOpt = opt.trim().toLowerCase() ==
                              (fb['correct_answer']?.toString() ?? '').trim().toLowerCase();
                          if (isCorrectOpt) {
                            tileColor = Colors.green.withValues(alpha: 0.12);
                            borderColor = Colors.green;
                          } else if (selected) {
                            tileColor = Colors.red.withValues(alpha: 0.1);
                            borderColor = Colors.red;
                          }
                        } else if (selected) {
                          tileColor = Theme.of(context).colorScheme.primaryContainer;
                          borderColor = Theme.of(context).colorScheme.primary;
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: tileColor,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: borderColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() {
                                _answers[q.id] = opt;
                                if (_isTutor && feedback == null) _checkCurrent();
                              }),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Text(
                                      String.fromCharCode(65 + oi),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(opt)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      if (feedback != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (feedback['correct'] == true ? Colors.green : Colors.red)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feedback['correct'] == true ? 'Correct!' : 'Incorrect',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: feedback['correct'] == true ? Colors.green : Colors.red,
                                ),
                              ),
                              if (feedback['correct'] == false) ...[
                                const SizedBox(height: 4),
                                Text('Correct answer: ${feedback['correct_answer']}'),
                              ],
                              if ((feedback['explanation'] ?? '').toString().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  feedback['explanation'].toString(),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _currentIndex > 0
                        ? () => setState(() => _currentIndex--)
                        : null,
                    child: const Text('Prev'),
                  ),
                  const Spacer(),
                  if (_isTutor && feedback == null)
                    FilledButton(
                      onPressed: _checking ? null : _checkCurrent,
                      child: Text(_checking ? 'Checking…' : 'Check'),
                    )
                  else if (!_isTutor || feedback != null)
                    FilledButton(
                      onPressed: _currentIndex < widget.questions.length - 1
                          ? () => setState(() => _currentIndex++)
                          : _submit,
                      child: Text(
                        _currentIndex < widget.questions.length - 1
                            ? 'Next'
                            : _submitting
                                ? 'Submitting…'
                                : 'Submit',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final score = (_result?['score'] as num?)?.toDouble() ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Results'),
        actions: [
          TextButton(onPressed: _retake, child: const Text('Retake')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  '${score.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: score >= 60 ? Colors.green : Colors.orange,
                      ),
                ),
                const SizedBox(height: 4),
                Text('Your score', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...widget.questions.asMap().entries.map((e) {
            final i = e.key;
            final q = e.value;
            final given = _answers[q.id] ?? '';
            final graded = _reviewAnswers[q.id];
            final ok = graded?['is_correct'] == true;
            final correct = (graded?['correct_answer'] as String?)?.trim().isNotEmpty == true
                ? graded!['correct_answer'] as String
                : q.correctAnswer;
            final explanation = (graded?['explanation'] as String?)?.isNotEmpty == true
                ? graded!['explanation'] as String
                : q.explanation;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          ok ? LucideIcons.checkCircle : LucideIcons.xCircle,
                          size: 18,
                          color: ok ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Q${i + 1}. ${q.text}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your answer: ${given.trim().isNotEmpty ? given : '—'}',
                      style: TextStyle(color: ok ? Colors.green[800] : Colors.red[800]),
                    ),
                    if (!ok) ...[
                      const SizedBox(height: 4),
                      Text('Correct answer: $correct'),
                    ],
                    if ((explanation ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(explanation!, style: const TextStyle(color: Colors.grey)),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}