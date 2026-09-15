import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as hls_crypto;
import 'package:flutter/foundation.dart';

/// Offline format marker: segments stored HLS-decrypted (clear) with a
/// self-contained playlist (no EXT-X-KEY, MAP rewritten to local init).
/// Anything without this marker uses the legacy app-encrypted layout.
const String kOfflineFormat = 'hls-clear-v1';

/// Encrypted-at-rest format: segments stored EXACTLY as received from the
/// server (still AES-128 encrypted), playlist keeps EXT-X-KEY tags with URIs
/// rewritten to local key_N.bin files (fetched once, with auth, at download
/// time) and original per-segment IVs preserved. No server, token, or
/// re-encryption needed at play time - pure file:// playback on both
/// platforms. Copied segments alone are unplayable ciphertext.
const String kOfflineEncryptedFormat = 'hls-enc-v1';

void _dlLog(String msg) => debugPrint('[DOWNLOAD] $msg');

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
  final Dio _dio;
  final String baseUrl;
  final String authToken;
  final String baseDir;
  bool _isCancelled = false;

  VideoDownloader({
    required this.baseUrl,
    required this.authToken,
    required this.baseDir,
  }) : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 120),
          ),
        );

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

  Future<Uint8List> _getBytes(String url, {int attempts = 3}) async {
    Object? lastError;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      if (_isCancelled) throw Exception('Download cancelled');
      try {
        final response = await _dio.get<List<int>>(
          url,
          options: Options(
            headers: _headersFor(url),
            responseType: ResponseType.bytes,
          ),
        );
        if (response.data == null) {
          throw Exception('Empty response for $url');
        }
        return Uint8List.fromList(response.data!);
      } catch (e) {
        lastError = e;
        if (_isCancelled) throw Exception('Download cancelled');
        if (attempt < attempts) {
          _dlLog('retry $attempt/$attempts $url (${e.runtimeType})');
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
    throw Exception('Failed to download $url after $attempts attempts: $lastError');
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
    bool storeEncrypted = true,
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
    final keyFileCache = <String, String>{}; // remote key URI -> local key_N.bin
    _KeyState? activeKey;
    var segIndex = 0;
    var mapIndex = 0;
    var keyIndex = 0;
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
    _dlLog('start lesson=$lessonId res=$resolution assets=$total fmp4=$isFmp4 '
        'encrypted=$storeEncrypted');

    // Throttle progress callbacks: at most one per 250ms (+ always final).
    var lastReport = DateTime.fromMillisecondsSinceEpoch(0);
    void report({bool force = false}) {
      final now = DateTime.now();
      if (!force && now.difference(lastReport).inMilliseconds < 250) return;
      lastReport = now;
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
          outLines.add(line);
          continue;
        }
        final keyUri = _attr(line, 'URI');
        final ivHex = _ivHex(line);
        if (keyUri != null && ivHex != null) {
          var key = keyCache[keyUri];
          // Key fetch needs auth (proxy URL) - fails loudly without it:
          // an offline download without its key is unplayable.
          key ??= await _getBytes(keyUri);
          keyCache[keyUri] = key;
          activeKey = _KeyState(key, _hexToBytes(ivHex));
          if (storeEncrypted) {
            var keyFile = keyFileCache[keyUri];
            if (keyFile == null) {
              keyFile = 'key_${keyIndex++}.bin';
              await File('${downloadDir.path}/$keyFile')
                  .writeAsBytes(key);
              keyFileCache[keyUri] = keyFile;
              _dlLog('stored key $keyFile (${key.length}B)');
            }
            // Preserve the whole tag (METHOD/IV/KEYFORMAT), only the URI
            // becomes the local key file.
            outLines.add(line.replaceAll(
              RegExp(r'URI="[^"]+"'),
              'URI="$keyFile"',
            ));
            continue;
          }
        }
        if (!storeEncrypted) {
          continue; // drop the tag: content is decrypted at download time
        }
        outLines.add(line);
        continue;
      }

      if (line.startsWith('#EXT-X-MAP:')) {
        final mapUri = _attr(line, 'URI');
        if (mapUri == null) continue;
        var local = mapCache[mapUri];
        if (local == null) {
          var initBytes = await _getBytes(mapUri);
          if (activeKey != null && !storeEncrypted) {
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
      if (activeKey != null && !storeEncrypted) {
        data = _aes128CbcDecrypt(data, activeKey.key, activeKey.iv);
      }
      final localName = 'seg_${segIndex++}.$segExt';
      await File('${downloadDir.path}/$localName').writeAsBytes(data);
      outLines.add(localName);
      done++;
      report();
    }

    if (_isCancelled) {
      _dlLog('cancelled lesson=$lessonId res=$resolution at $done/$total');
      if (await downloadDir.exists()) {
        await downloadDir.delete(recursive: true);
      }
      return;
    }

    final playlistFile = File('${downloadDir.path}/playlist.m3u8');
    await playlistFile.writeAsString(outLines.join('\n'));
    await File('${downloadDir.path}/.fmt').writeAsString(
      storeEncrypted ? kOfflineEncryptedFormat : kOfflineFormat,
    );
    report(force: true);
    _dlLog('done lesson=$lessonId res=$resolution assets=$done/$total');
  }

  Future<bool> isDownloaded(String lessonId, String resolution) async {
    final downloadDir = Directory('$baseDir/downloads/$lessonId/$resolution');
    if (!await downloadDir.exists()) return false;

    final playlistFile = File('${downloadDir.path}/playlist.m3u8');
    return await playlistFile.exists();
  }

  /// Offline format of a stored download: 'hls-clear-v1' for the current
  /// self-contained layout, anything else (or missing) is legacy.
  Future<String?> offlineFormat(String lessonId, String resolution) async {
    try {
      final fmtFile =
          File('$baseDir/downloads/$lessonId/$resolution/.fmt');
      if (!await fmtFile.exists()) return null;
      return (await fmtFile.readAsString()).trim();
    } catch (_) {
      return null;
    }
  }

  /// Mode recorded when the download was made (server_mode at the time).
  Future<String?> readDownloadMode(String lessonId, String resolution) async {
    try {
      final modeFile =
          File('$baseDir/downloads/$lessonId/$resolution/.mode');
      if (!await modeFile.exists()) return null;
      return (await modeFile.readAsString()).trim();
    } catch (_) {
      return null;
    }
  }

  /// Builds a directly-playable file:// playlist for a clear-format download
  /// by rewriting its relative segment/init references to absolute file
  /// paths. No local HTTP server needed - works on Android AND iOS.
  /// Returns the play-file path, or null when the download is legacy format
  /// (serve those through LocalVideoServer instead).
  Future<String?> buildLocalPlayFile(
    String lessonId,
    String resolution,
  ) async {
    final dir = Directory('$baseDir/downloads/$lessonId/$resolution');
    final format = await offlineFormat(lessonId, resolution);
    if (format != kOfflineFormat) return null;
    final playlistFile = File('${dir.path}/playlist.m3u8');
    if (!await playlistFile.exists()) return null;

    final content = await playlistFile.readAsString();
    final out = <String>[];
    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.startsWith('#EXT-X-MAP:')) {
        final m = RegExp(r'URI="([^"]+)"').firstMatch(line);
        final name = m?.group(1) ?? '';
        if (name.isEmpty || name.startsWith('http') || name.startsWith('/')) {
          return null; // not fully offline - don't play half-local
        }
        out.add('#EXT-X-MAP:URI="file://${dir.path}/$name"');
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        if (line.startsWith('http') || line.startsWith('/')) {
          return null;
        }
        out.add('file://${dir.path}/$line');
      } else {
        out.add(rawLine);
      }
    }
    final playFile = File('${dir.path}/play.m3u8');
    await playFile.writeAsString(out.join('\n'));
    _dlLog('play-file ready $playFile');
    return playFile.path;
  }

  Future<void> deleteDownload(String lessonId, String resolution) async {
    final dir = Directory('$baseDir/downloads/$lessonId/$resolution');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  void close() {
    _isCancelled = true;
    _dio.close(force: true);
  }
}
