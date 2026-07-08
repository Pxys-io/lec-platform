import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'encryption_helper.dart';

class DownloadProgress {
  final int totalSegments;
  final int downloadedSegments;
  final double progress;

  DownloadProgress({
    required this.totalSegments,
    required this.downloadedSegments,
    required this.progress,
  });
}

class VideoDownloader {
  final Dio _dio = Dio();
  final String baseUrl;
  final String authToken;
  final String baseDir;
  bool _isCancelled = false;

  VideoDownloader({
    required this.baseUrl,
    required this.authToken,
    required this.baseDir,
  });

  Future<void> downloadVideo({
    required String lessonId,
    required String resolution,
    required String playlistContent,
    String modeWhenDownloaded = 'hybrid',
    Function(DownloadProgress)? onProgress,
  }) async {
    final downloadDir = Directory('$baseDir/downloads/$lessonId/$resolution');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    final modeFile = File('${downloadDir.path}/.mode');
    await modeFile.writeAsString(modeWhenDownloaded);

    final playlistFile = File('${downloadDir.path}/playlist.m3u8');
    await playlistFile.writeAsString(playlistContent);

    final segments = playlistContent
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();

    if (segments.isEmpty) {
      throw Exception('No segments found in playlist');
    }

    for (int i = 0; i < segments.length; i++) {
      if (_isCancelled) break;
      final segmentLine = segments[i];

      // If it's already a full URL, use it. Otherwise construct it.
      final String segmentUrl;
      if (segmentLine.startsWith('http')) {
        segmentUrl = segmentLine;
      } else {
        segmentUrl =
            '$baseUrl/videos/$lessonId/segments/$resolution/$segmentLine';
      }

      final response = await _dio.get<List<int>>(
        segmentUrl,
        options: Options(
          headers: {'Authorization': 'Bearer $authToken'},
          responseType: ResponseType.bytes,
        ),
      );

      if (response.data == null) {
        throw Exception('Failed to download segment from $segmentUrl');
      }

      final encryptedData = EncryptionHelper.encrypt(
        Uint8List.fromList(response.data!),
      );

      // We save it with a predictable name for the local server to find
      // The server expects segment_(\d+).ts or the original name.
      // Let's save it as segment_i.ts and ALSO update the local playlist to match.
      final segmentFileName = 'segment_$i.ts';
      final targetFile = File('${downloadDir.path}/$segmentFileName');
      await targetFile.writeAsBytes(encryptedData);

      if (onProgress != null) {
        onProgress(
          DownloadProgress(
            totalSegments: segments.length,
            downloadedSegments: i + 1,
            progress: (i + 1) / segments.length,
          ),
        );
      }
    }

    if (_isCancelled) {
      // Clean up partial downloads if cancelled
      if (await downloadDir.exists()) {
        await downloadDir.delete(recursive: true);
      }
      return;
    }

    // Rewrite the local playlist to use the new segment names (segment_0.ts, segment_1.ts, etc.)
    var newPlaylistContent = playlistContent;
    for (int i = 0; i < segments.length; i++) {
      // Be careful with replacement to not replace parts of other URLs
      // Since we know the exact line, we can replace the whole line.
      newPlaylistContent = newPlaylistContent.replaceFirst(
        segments[i],
        'segment_$i.ts',
      );
    }
    await playlistFile.writeAsString(newPlaylistContent);
  }

  Future<bool> isDownloaded(String lessonId, String resolution) async {
    final downloadDir = Directory('$baseDir/downloads/$lessonId/$resolution');
    if (!await downloadDir.exists()) return false;

    final playlistFile = File('${downloadDir.path}/playlist.m3u8');
    return await playlistFile.exists();
  }

  void close() {
    _isCancelled = true;
    _dio.close(force: true);
  }
}
