import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/misc_repository.dart';

class ReportDialog {
  static Future<void> show(BuildContext context, {required String targetType, required String targetId}) async {
    final descriptionController = TextEditingController();
    String? selectedReason;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Report Content'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        prefixIcon: Icon(LucideIcons.flag),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'spam', child: Text('Spam')),
                        DropdownMenuItem(value: 'inappropriate', child: Text('Inappropriate')),
                        DropdownMenuItem(value: 'offensive', child: Text('Offensive')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (value) {
                        setState(() => selectedReason = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        prefixIcon: Icon(LucideIcons.messageSquare),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  icon: const Icon(LucideIcons.send),
                  label: const Text('Submit'),
                  onPressed: selectedReason == null
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop({
                            'target_type': targetType,
                            'target_id': targetId,
                            'reason': selectedReason,
                            'description': descriptionController.text.trim().isEmpty
                                ? null
                                : descriptionController.text.trim(),
                          });
                        },
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || context.mounted == false) return;

    try {
      await context.read<MiscRepository>().createReport(Map<String, dynamic>.from(result));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e')),
        );
      }
    }
  }
}
