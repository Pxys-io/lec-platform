import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../../models/video.dart';
import '../logic/video_downloader.dart';

/// Shows the bottom-sheet quality picker for the video player. Returns the
/// resolution the user chose (or null if dismissed / auto selected a change).
/// Downloads are started directly via [onDownload].
Future<void> showQualityPicker(
  BuildContext context, {
  required VideoManifest manifest,
  required String currentResolution,
  required bool isAutoQuality,
  required double estimatedSpeedKbps,
  required String lessonId,
  required String baseUrl,
  required String authToken,
  required ValueChanged<bool> onAutoChanged,
  required ValueChanged<VideoResolution> onSelect,
  required ValueChanged<VideoResolution> onDownload,
}) async {
  final appDir = await getApplicationDocumentsDirectory();
  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.black87,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Video Quality',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Auto Quality', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              'Estimated: ${estimatedSpeedKbps.toStringAsFixed(0)} kbps',
              style: const TextStyle(color: Colors.white54),
            ),
            value: isAutoQuality,
            onChanged: (val) {
              setSheetState(() {});
              Navigator.pop(ctx);
              onAutoChanged(val);
            },
          ),
          if (!isAutoQuality)
            ...manifest.resolutions.map((res) {
              return FutureBuilder<bool>(
                future: VideoDownloader(
                  baseUrl: baseUrl,
                  authToken: authToken,
                  baseDir: appDir.path,
                ).isDownloaded(lessonId, res.resolution),
                builder: (context, snapshot) {
                  final isDownloaded = snapshot.data ?? false;
                  return ListTile(
                    leading: Icon(
                      res.resolution == currentResolution
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: Colors.white,
                    ),
                    title: Text(
                      '${res.resolution}  |  ${(res.bitrate / 1000000).toStringAsFixed(1)} Mbps',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: isDownloaded
                        ? const Icon(Icons.download_done, color: Colors.green)
                        : IconButton(
                            icon: const Icon(Icons.download, color: Colors.white),
                            onPressed: () {
                              Navigator.pop(ctx);
                              onDownload(res);
                            },
                          ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onSelect(res);
                    },
                  );
                },
              );
            }),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}