import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../models/material.dart' as models;

/// Viewer debug logging (debugPrint is stripped from release builds).
void _viewerLog(String msg) => debugPrint('[VIEWER] $msg');

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

/// In-app PDF viewer: downloads the file to a temp file and renders it
/// with PDFView. No external-app fallback (in-app only by design).
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

  bool get _isPdf {
    final t = widget.material.type.toLowerCase();
    if (t == 'pdf') return true;
    if (t == 'document') {
      return widget.material.url.toLowerCase().split('?').first.endsWith('.pdf');
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _viewerLog('open id=${widget.material.id} type=${widget.material.type} url=${widget.material.url}');
    if (!_isPdf) {
      setState(() => _error = 'preview-unsupported');
    } else {
      _download();
    }
  }

  Future<void> _download() async {
    setState(() {
      _error = null;
      _localPath = null;
    });
    try {
      final uri = Uri.parse(widget.material.url);
      _viewerLog('download start $uri');
      final res = await http.get(uri).timeout(const Duration(seconds: 30));
      _viewerLog('download status=${res.statusCode} bytes=${res.bodyBytes.length} '
          'content-type=${res.headers['content-type']}');
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final dir = await getTemporaryDirectory();
      final safeName =
          'material_${widget.material.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(res.bodyBytes, flush: true);
      _viewerLog('saved ${file.path} size=${await file.length()}');
      if (mounted) setState(() => _localPath = file.path);
    } on TimeoutException {
      _viewerLog('download TIMEOUT');
      if (mounted) setState(() => _error = 'Download timed out. Check your connection and retry.');
    } catch (e) {
      _viewerLog('download FAILED: $e');
      if (mounted) setState(() => _error = 'Could not load document: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.material.title,
            overflow: TextOverflow.ellipsis),
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
                    Text(
                      _error == 'preview-unsupported'
                          ? 'This file type cannot be previewed in the app.'
                          : _error!,
                      textAlign: TextAlign.center,
                    ),
                    if (_error != 'preview-unsupported') ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _download,
                        icon: const Icon(LucideIcons.rotateCw),
                        label: const Text('Retry'),
                      ),
                    ],
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
                      onRender: (pages) {
                        _viewerLog('pdf rendered pages=$pages');
                        if (mounted) setState(() => _pages = pages ?? 0);
                      },
                      onPageChanged: (page, _) {
                        if (mounted) setState(() => _currentPage = page ?? 0);
                      },
                      onError: (e) {
                        _viewerLog('pdf RENDER-ERROR: $e');
                        if (mounted) {
                          setState(() => _error = 'Could not render PDF: $e');
                        }
                      },
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
    _viewerLog('open link url=${widget.material.url}');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) =>
              mounted ? setState(() => _loading = false) : null,
          onWebResourceError: (e) =>
              _viewerLog('webview ERROR: ${e.errorCode} ${e.description}'),
        ),
      )
      ..loadRequest(Uri.parse(widget.material.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.material.title,
            overflow: TextOverflow.ellipsis),
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
