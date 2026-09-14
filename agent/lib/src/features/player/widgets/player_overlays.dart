import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../models/video.dart';

/// Overlay chrome for the video player: moving watermark, top bar (back,
/// comments, quality chip), mode-mismatch banner, and download progress.
class PlayerOverlays extends StatelessWidget {
  final VideoManifest? manifest;
  final Offset watermarkOffset;
  final String userEmail;
  final String studentId;
  final String currentResolution;
  final bool modeMismatchWarning;
  final String modeMismatchMessage;
  final bool isDownloading;
  final double downloadProgress;
  final VoidCallback onBack;
  final VoidCallback onComments;
  final VoidCallback onQualityTap;

  const PlayerOverlays({
    super.key,
    required this.manifest,
    required this.watermarkOffset,
    required this.userEmail,
    required this.studentId,
    required this.currentResolution,
    required this.modeMismatchWarning,
    required this.modeMismatchMessage,
    required this.isDownloading,
    required this.downloadProgress,
    required this.onBack,
    required this.onComments,
    required this.onQualityTap,
  });

  Color _hexColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (manifest != null)
          AnimatedPositioned(
            duration: const Duration(seconds: 1),
            left: watermarkOffset.dx,
            top: watermarkOffset.dy,
            child: Opacity(
              opacity: manifest!.watermarkOpacity.clamp(0.0, 1.0),
              child: Text(
                '$userEmail — $studentId',
                style: TextStyle(
                  color: _hexColor(manifest!.watermarkColor),
                  fontSize: manifest!.watermarkFontSize.toDouble(),
                  fontWeight: FontWeight.bold,
                  shadows: const [Shadow(blurRadius: 2, color: Colors.black)],
                ),
              ),
            ),
          ),

        Positioned(
          top: 40,
          left: 20,
          child: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
            onPressed: onBack,
          ),
        ),

        Positioned(
          top: 40,
          right: 20,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(LucideIcons.messageSquare, color: Colors.white),
                onPressed: onComments,
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onQualityTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.monitor, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        currentResolution,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        if (modeMismatchWarning)
          Positioned(
            top: 80,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.shieldAlert, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      modeMismatchMessage,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (isDownloading)
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: downloadProgress,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 4),
                Text(
                  'Downloading... ${(downloadProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}