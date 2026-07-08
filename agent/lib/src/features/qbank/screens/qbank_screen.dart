import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons_flutter.dart';
import '../../../logic/qbank/qbank_cubit.dart';
import '../../../models/qbank.dart';

class QBankScreen extends StatefulWidget {
  const QBankScreen({super.key});

  @override
  State<QBankScreen> createState() => _QBankScreenState();
}

class _QBankScreenState extends State<QBankScreen> {
  @override
  void initState() {
    super.initState();
    context.read<QBankCubit>().loadQBanks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QBank'),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<QBankCubit>().loadQBanks(),
        child: BlocBuilder<QBankCubit, QBankState>(
          builder: (context, state) {
            if (state is QBankLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is QBankLoaded) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Available QBanks', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.qbanks.length,
                      itemBuilder: (context, index) {
                        final qbank = state.qbanks[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(LucideIcons.bookOpen, color: Theme.of(context).colorScheme.primary),
                            ),
                            title: Text(qbank.title),
                            subtitle: Text('${qbank.tags.join(", ")}'),
                            trailing: ElevatedButton(
                              onPressed: () => _showCreateSessionDialog(context, qbank),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                minimumSize: const Size(0, 32),
                              ),
                              child: const Text('Create'),
                            ),
                          ),
                        );
                      },
                    ),
                    if (state.qbanks.isEmpty)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('No QBanks available yet.'),
                      )),
                    const SizedBox(height: 24),
                    Text('Recent Sessions', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.recentSessions.length,
                      itemBuilder: (context, index) {
                        final session = state.recentSessions[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(session.title),
                            subtitle: Text('${session.questionIds.length} Questions • ${session.score?.toStringAsFixed(1) ?? "In Progress"}%'),
                            trailing: const Icon(LucideIcons.chevronRight),
                            onTap: () {
                              // context.push('/quiz-session', extra: session);
                            },
                          ),
                        );
                      },
                    ),
                    if (state.recentSessions.isEmpty)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('Start a practice session to see your progress.'),
                      )),
                  ],
                ),
              );
            } else if (state is QBankFailure) {
              return Center(child: Text(state.message));
            }
            return const Center(child: Text('Welcome to QBank!'));
          },
        ),
      ),
    );
  }

  void _showCreateSessionDialog(BuildContext context, QBank qbank) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CreateSessionSheet(qbank: qbank),
    );
  }
}

class _CreateSessionSheet extends StatefulWidget {
  final QBank qbank;
  const _CreateSessionSheet({required this.qbank});

  @override
  State<_CreateSessionSheet> createState() => _CreateSessionSheetState();
}

class _CreateSessionSheetState extends State<_CreateSessionSheet> {
  final List<String> _selectedSubjects = [];
  String _mode = 'tutor';
  int _count = 20;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New Practice Session', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          Text('Select Subjects', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: widget.qbank.tags.map((tag) {
              final isSelected = _selectedSubjects.contains(tag);
              return FilterChip(
                label: Text(tag),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedSubjects.add(tag);
                    } else {
                      _selectedSubjects.remove(tag);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text('Mode', style: Theme.of(context).textTheme.titleMedium),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'tutor', label: Text('Tutor'), icon: Icon(LucideIcons.info)),
              ButtonSegment(value: 'timed', label: Text('Timed'), icon: Icon(LucideIcons.clock)),
            ],
            selected: {_mode},
            onSelectionChanged: (value) => setState(() => _mode = value.first),
          ),
          const SizedBox(height: 24),
          Text('Question Count', style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: _count.toDouble(),
            min: 5,
            max: 50,
            divisions: 9,
            label: _count.toString(),
            onChanged: (value) => setState(() => _count = value.round()),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.read<QBankCubit>().createSession(widget.qbank.id, {
                  'title': '${widget.qbank.title} - ${DateTime.now().day}/${DateTime.now().month}',
                  'subjects': _selectedSubjects,
                  'mode': _mode,
                  'count': _count,
                });
                Navigator.pop(context);
              },
              child: const Text('Start Session'),
            ),
          ),
        ],
      ),
    );
  }
}
