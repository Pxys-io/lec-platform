import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/material.dart' as models;

class DocumentViewerScreen extends StatelessWidget {
  final List<models.Material> materials;
  final String lessonTitle;

  const DocumentViewerScreen({
    super.key,
    required this.materials,
    required this.lessonTitle,
  });

  IconData _iconForType(String type) {
    switch (type) {
      case 'pdf':
        return LucideIcons.fileText;
      case 'document':
        return LucideIcons.file;
      case 'image':
        return LucideIcons.image;
      case 'link':
        return LucideIcons.link;
      default:
        return LucideIcons.file;
    }
  }

  Future<void> _openMaterial(BuildContext context, models.Material material) async {
    final uri = Uri.tryParse(material.url);
    if (uri == null) return;

    if (material.type == 'link' || material.type == 'pdf' || material.type == 'document') {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open ${material.url}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(lessonTitle),
      ),
      body: materials.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.fileX, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No materials available', style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: materials.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final material = materials[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(_iconForType(material.type)),
                  ),
                  title: Text(material.title),
                  subtitle: Text(material.type.toUpperCase()),
                  trailing: const Icon(LucideIcons.externalLink, size: 18),
                  onTap: () => _openMaterial(context, material),
                );
              },
            ),
    );
  }
}
