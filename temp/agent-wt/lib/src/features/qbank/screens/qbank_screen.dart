import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class QBankScreen extends StatelessWidget {
  const QBankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QBank'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Practice Session', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const ListTile(
                      title: Text('Select Subjects'),
                      trailing: Icon(LucideIcons.plus),
                    ),
                    const Divider(),
                    const ListTile(
                      title: Text('Mode'),
                      trailing: Text('Tutor'),
                    ),
                    const Divider(),
                    const ListTile(
                      title: Text('Question Count'),
                      trailing: Text('20'),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('Start Session'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Recent Sessions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('Cardiology Mixed - ${index + 1}'),
                    subtitle: const Text('20 Questions • 85% Correct'),
                    trailing: const Icon(LucideIcons.chevronRight),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
