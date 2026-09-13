import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as hls_crypto;

/// Offline format marker: segments stored HLS-decrypted (clear) with a
/// self-contained playlist (no EXT-X-KEY, MAP rewritten to local init).
/// Anything without this marker uses the legacy app-encrypted layout.
const String kOfflineFormat = 'hls-clear-v1';

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

class _KeyState {
  final Uint8List key;
  final Uint8List iv;
  _KeyState(this.key, this.iv);
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

  String get _mainHost {
    try {
      return Uri.parse(baseUrl).host;
    } catch (_) {
      return '';
    }
  }

  /// Auth is only sent to our own backend (playlist / key / watermark proxy).
  /// Segment/media hosts (R2, MUX) are public - sending a Bearer there can
  /// make S3-style storage reject the request, and leaks the JWT to CDN logs.
  /// Matched by backend host OR the proxy path, so aliased/dev hosts of the
  /// same backend still authenticate.
  Map<String, String> _headersFor(String url) {
    if (authToken.isEmpty) return {};
    try {
      final uri = Uri.parse(url);
      if (uri.host == _mainHost || uri.path.contains('/api/v1/videos/proxy')) {
        return {'Authorization': 'Bearer $authToken'};
      }
    } catch (_) {}
    return {};
  }

  Future<Uint8List> _getBytes(String url) async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        headers: _headersFor(url),
        responseType: ResponseType.bytes,
      ),
    );
    if (response.data == null) {
      throw Exception('Failed to download $url');
    }
    return Uint8List.fromList(response.data!);
  }

  static Uint8List _hexToBytes(String hex) {
    var h = hex.toLowerCase();
    if (h.startsWith('0x')) h = h.substring(2);
    final out = Uint8List(h.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static Uint8List _aes128CbcDecrypt(
    Uint8List data,
    Uint8List key,
    Uint8List iv,
  ) {
    final encrypter = hls_crypto.Encrypter(
      hls_crypto.AES(hls_crypto.Key(key), mode: hls_crypto.AESMode.cbc),
    );
    return Uint8List.fromList(
      encrypter.decryptBytes(hls_crypto.Encrypted(data), iv: hls_crypto.IV(iv)),
    );
  }

  static String? _attr(String line, String name) {
    final m = RegExp('$name="([^"]+)"').firstMatch(line);
    return m?.group(1);
  }

  static String? _ivHex(String line) {
    final m = RegExp(r'IV=0?x?([0-9a-fA-F]+)').firstMatch(line);
    return m?.group(1);
  }

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

    final lines = playlistContent.split('\n').map((l) => l.trim()).toList();

    // fMP4 (MUX) playlists carry EXT-X-MAP; MPEG-TS (local ffmpeg) ones don't.
    // Either way we store clear segments + a self-contained playlist, so one
    // code path handles MUX and non-MUX, encrypted and clear videos.
    final bool isFmp4 = lines.any((l) => l.startsWith('#EXT-X-MAP:'));
    final String segExt = isFmp4 ? 'm4s' : 'ts';

    final keyCache = <String, Uint8List>{};
    final mapCache = <String, String>{}; // remote URI -> local file name
    _KeyState? activeKey;
    var segIndex = 0;
    var mapIndex = 0;
    var done = 0;

    // Count downloadable assets for progress: MAP inits + media segments.
    var total = 0;
    for (final l in lines) {
      if (l.startsWith('#EXT-X-MAP:')) total++;
      if (l.isNotEmpty && !l.startsWith('#')) total++;
    }
    if (total == 0) {
      throw Exception('No segments found in playlist');
    }

    void report() {
      onProgress?.call(
        DownloadProgress(
          totalSegments: total,
          downloadedSegments: done,
          progress: total == 0 ? 0 : done / total,
        ),
      );
    }

    final outLines = <String>[];

    for (final line in lines) {
      if (_isCancelled) break;

      if (line.startsWith('#EXT-X-KEY:')) {
        if (line.contains('METHOD=NONE')) {
          activeKey = null;
          continue; // drop the tag: everything stored is clear
        }
        final keyUri = _attr(line, 'URI');
        final ivHex = _ivHex(line);
        if (keyUri != null && ivHex != null) {
          var key = keyCache[keyUri];
          key ??= await _getBytes(keyUri);
          keyCache[keyUri] = key;
          activeKey = _KeyState(key, _hexToBytes(ivHex));
        }
        continue; // drop the tag: content is decrypted at download time
      }

      if (line.startsWith('#EXT-X-MAP:')) {
        final mapUri = _attr(line, 'URI');
        if (mapUri == null) continue;
        var local = mapCache[mapUri];
        if (local == null) {
          var initBytes = await _getBytes(mapUri);
          if (activeKey != null) {
            initBytes = _aes128CbcDecrypt(
              initBytes,
              activeKey.key,
              activeKey.iv,
            );
          }
          local = 'init_${mapIndex++}.mp4';
          await File('${downloadDir.path}/$local').writeAsBytes(initBytes);
          mapCache[mapUri] = local;
          done++;
          report();
        }
        outLines.add('#EXT-X-MAP:URI="$local"');
        continue;
      }

      if (line.isEmpty || line.startsWith('#')) {
        outLines.add(line); // EXTINF, DISCONTINUITY, VERSION, TARGETDURATION...
        continue;
      }

      // Media segment (content, watermark break or overlay - all handled same).
      final String segmentUrl;
      if (line.startsWith('http')) {
        segmentUrl = line;
      } else {
        segmentUrl =
            '$baseUrl/videos/$lessonId/segments/$resolution/$line';
      }
      var data = await _getBytes(segmentUrl);
      if (activeKey != null) {
        data = _aes128CbcDecrypt(data, activeKey.key, activeKey.iv);
      }
      final localName = 'seg_${segIndex++}.$segExt';
      await File('${downloadDir.path}/$localName').writeAsBytes(data);
      outLines.add(localName);
      done++;
      report();
    }

    if (_isCancelled) {
      if (await downloadDir.exists()) {
        await downloadDir.delete(recursive: true);
      }
      return;
    }

    final playlistFile = File('${downloadDir.path}/playlist.m3u8');
    await playlistFile.writeAsString(outLines.join('\n'));
    await File('${downloadDir.path}/.fmt').writeAsString(kOfflineFormat);
    report();
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
