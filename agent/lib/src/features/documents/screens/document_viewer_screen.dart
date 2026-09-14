import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

  void _openMaterial(BuildContext context, models.Material material) {
    final type = material.type.toLowerCase();
    if (type == 'image') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MaterialImageScreen(material: material),
        ),
      );
    } else if (type == 'link') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MaterialWebScreen(material: material),
        ),
      );
    } else {
      // pdf / document: render in-app (download then PDFView),
      // with external-app fallback on failure.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MaterialPdfScreen(material: material),
        ),
      );
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
                  Text('No materials available',
                      style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: materials.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final material = materials[index];
                final type = material.type.toLowerCase();
                final trailing = type == 'link'
                    ? LucideIcons.globe
                    : type == 'image'
                        ? LucideIcons.image
                        : LucideIcons.bookOpen;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(_iconForType(material.type)),
                  ),
                  title: Text(material.title),
                  subtitle: Text(material.type.toUpperCase()),
                  trailing: Icon(trailing, size: 18),
                  onTap: () => _openMaterial(context, material),
                );
              },
            ),
    );
  }
}

/// In-app PDF / document viewer: downloads the file to a temp file and
/// renders it with PDFView. Falls back to an external app on failure.
class MaterialPdfScreen extends StatefulWidget {
  final models.Material material;

  const MaterialPdfScreen({super.key, required this.material});

  @override
  State<MaterialPdfScreen> createState() => _MaterialPdfScreenState();
}

class _MaterialPdfScreenState extends State<MaterialPdfScreen> {
  String? _localPath;
  String? _error;
  int _pages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    try {
      final uri = Uri.parse(widget.material.url);
      final res = await http.get(uri);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final dir = await getTemporaryDirectory();
      final safeName =
          'material_${widget.material.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(res.bodyBytes, flush: true);
      if (mounted) setState(() => _localPath = file.path);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load document: $e');
    }
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.material.url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${widget.material.url}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.material.title,
            overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.externalLink),
            tooltip: 'Open externally',
            onPressed: _openExternal,
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.fileWarning, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _openExternal,
                      child: const Text('Open in external app'),
                    ),
                  ],
                ),
              ),
            )
          : _localPath == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    PDFView(
                      filePath: _localPath,
                      enableSwipe: true,
                      swipeHorizontal: false,
                      autoSpacing: true,
                      pageFling: true,
                      onRender: (pages) =>
                          setState(() => _pages = pages ?? 0),
                      onPageChanged: (page, _) => setState(
                          () => _currentPage = page ?? 0),
                      onError: (e) =>
                          setState(() => _error = 'Could not render PDF: $e'),
                    ),
                    if (_pages > 1)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${_currentPage + 1} / $_pages',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

/// In-app image viewer.
class MaterialImageScreen extends StatelessWidget {
  final models.Material material;

  const MaterialImageScreen({super.key, required this.material});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(material.title)),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            material.url,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (ctx, err, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load image: $err',
                  textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}

/// In-app webpage viewer for link materials.
class MaterialWebScreen extends StatefulWidget {
  final models.Material material;

  const MaterialWebScreen({super.key, required this.material});

  @override
  State<MaterialWebScreen> createState() => _MaterialWebScreenState();
}

class _MaterialWebScreenState extends State<MaterialWebScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) =>
              mounted ? setState(() => _loading = false) : null,
        ),
      )
      ..loadRequest(Uri.parse(widget.material.url));
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.material.url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.material.title,
            overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.externalLink),
            tooltip: 'Open in browser',
            onPressed: _openExternal,
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
