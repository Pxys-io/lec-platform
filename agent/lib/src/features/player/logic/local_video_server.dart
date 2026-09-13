import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'encryption_helper.dart';
import 'video_downloader.dart' show kOfflineFormat;

class ModeMismatchException implements Exception {
  final String message;
  final String currentMode;
  final String downloadMode;
  ModeMismatchException(this.message, this.currentMode, this.downloadMode);

  @override
  String toString() => message;
}

class LocalVideoServer {
  static final LocalVideoServer _instance = LocalVideoServer._internal();
  factory LocalVideoServer() => _instance;
  LocalVideoServer._internal();

  HttpServer? _server;
  String? _authToken;
  String? _downloadPath;
  String? _blockReason;
  final Map<String, Uint8List> _segmentCache = {};

  String? get authToken => _authToken;
  int? get port => _server?.port;
  String? get blockReason => _blockReason;

  String _serverMode = 'hybrid';
  String _mismatchAction = 'warn';

  Future<void> start(
    String downloadPath, {
    String serverMode = 'hybrid',
    String mismatchAction = 'warn',
    String downloadPolicy = 'allow',
  }) async {
    if (_server != null) return;

    _downloadPath = downloadPath;
    _serverMode = serverMode;
    _mismatchAction = mismatchAction;
    _authToken = _generateRandomToken();
    _blockReason = null;

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    debugPrint(
      'Local native server started on http://${_server!.address.host}:${_server!.port}',
    );

    _server!.listen((HttpRequest request) async {
      try {
        // 1. Check Auth
        final authHeader = request.headers.value('Authorization');
        if (authHeader == null ||
            !authHeader.startsWith('Bearer ') ||
            authHeader.substring(7) != _authToken) {
          request.response
            ..statusCode = HttpStatus.forbidden
            ..write('Unauthorized')
            ..close();
          return;
        }

        final path = request.uri.path;

        // 2. Route: Playlist
        if (path.startsWith('/playlist/')) {
          await _handlePlaylist(request);
        }
        // 3. Route: fMP4 init segments (EXT-X-MAP, MUX renditions)
        else if (path.startsWith('/init/')) {
          await _handleInit(request);
        }
        // 4. Route: Segments
        else if (path.startsWith('/segments/')) {
          await _handleSegment(request);
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('Not Found')
            ..close();
        }
      } catch (e) {
        debugPrint('Server error: $e');
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..write('Internal Error')
          ..close();
      }
    });
  }

  Future<void> _handlePlaylist(HttpRequest request) async {
    final parts = request.uri.pathSegments;
    if (parts.length < 3) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }

    final lessonId = parts[1];
    final resolution = parts[2].replaceAll('.m3u8', '');

    final serverMode = _serverMode;
    final mismatchAction = _mismatchAction;
    final downloadMode = await _readDownloadMode(lessonId, resolution);

    if (downloadMode != null && downloadMode != serverMode) {
      if (mismatchAction == 'block') {
        _blockReason = 'MODE_MISMATCH_BLOCK';
        request.response
          ..statusCode = HttpStatus.forbidden
          ..headers.contentType = ContentType('text', 'plain')
          ..write(
            'BLOCKED: Video downloaded in $downloadMode mode but server is now in $serverMode mode. Admin has blocked playback.',
          )
          ..close();
        return;
      }
      if (mismatchAction == 'auto_delete') {
        final dir = Directory('$_downloadPath/$lessonId');
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
        _blockReason = 'MODE_MISMATCH_AUTO_DELETED';
        request.response
          ..statusCode = HttpStatus.gone
          ..headers.contentType = ContentType('text', 'plain')
          ..write(
            'DELETED: Video was downloaded in $downloadMode mode but server is now in $serverMode mode. Auto-deleted per admin policy.',
          )
          ..close();
        return;
      }
    }

    final playlistFile = File(
      '$_downloadPath/$lessonId/$resolution/playlist.m3u8',
    );
    if (!await playlistFile.exists()) {
      print('Playlist not found at: ${playlistFile.path}');
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }

    var content = await playlistFile.readAsString();

    content = content.replaceAllMapped(RegExp(r'segment_(\d+)\.ts'), (match) {
      return 'http://localhost:${_server!.port}/segments/$lessonId/$resolution/${match.group(0)}';
    });

    // Offline layouts: legacy app-encrypted (segment_N.ts) and the current
    // clear layout (seg_N.m4s for fMP4/MUX, seg_N.ts for MPEG-TS, init_N.mp4
    // for EXT-X-MAP). Rewrite every local media/init reference to localhost.
    content = content.replaceAllMapped(
      RegExp(r'(seg_\d+\.(?:m4s|ts))'),
      (match) {
        return 'http://localhost:${_server!.port}/segments/$lessonId/$resolution/${match.group(1)}';
      },
    );
    content = content.replaceAllMapped(RegExp(r'(init_\d+\.mp4)'), (match) {
      return 'http://localhost:${_server!.port}/init/$lessonId/$resolution/${match.group(1)}';
    });

    if (downloadMode != null && downloadMode != serverMode) {
      content = content.replaceFirst(
        '#EXTM3U',
        '#EXTM3U\n# NOTE: Played in mode mismatch (DL: $downloadMode, SRV: $serverMode)',
      );
    }

    request.response
      ..headers.contentType = ContentType('application', 'x-mpegURL')
      ..write(content)
      ..close();
  }

  Future<bool> _isClearFormat(String lessonId, String resolution) async {
    final fmtFile = File('$_downloadPath/$lessonId/$resolution/.fmt');
    if (!await fmtFile.exists()) return false;
    return (await fmtFile.readAsString()).trim() == kOfflineFormat;
  }

  ContentType _contentTypeFor(String fileName) {
    if (fileName.endsWith('.m4s') || fileName.endsWith('.mp4')) {
      return ContentType('video', 'mp4'); // fMP4 fragments + init (MUX)
    }
    return ContentType('video', 'MP2T'); // MPEG-TS (local ffmpeg)
  }

  Future<void> _serveFile(
    HttpRequest request,
    String cacheKey,
    String filePath, {
    required bool clear,
  }) async {
    final data = await File(filePath).readAsBytes();
    final Uint8List out;
    if (clear) {
      out = data;
    } else {
      out = EncryptionHelper.decrypt(Uint8List.fromList(data));
    }
    _segmentCache[cacheKey] = out;
    request.response
      ..headers.contentType = _contentTypeFor(filePath)
      ..add(out)
      ..close();
  }

  Future<void> _handleInit(HttpRequest request) async {
    final parts =
        request.uri.pathSegments; // init, lessonId, resolution, fileName
    if (parts.length < 4) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }

    final cacheKey = parts.skip(1).join('/'); // lessonId/resolution/fileName
    if (_segmentCache.containsKey(cacheKey)) {
      request.response
        ..headers.contentType = ContentType('video', 'mp4')
        ..add(_segmentCache[cacheKey]!)
        ..close();
      return;
    }

    final initFile = File('$_downloadPath/$cacheKey');
    if (!await initFile.exists()) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }

    final clear = await _isClearFormat(parts[1], parts[2]);
    await _serveFile(request, cacheKey, initFile.path, clear: clear);
  }

  Future<void> _handleSegment(HttpRequest request) async {
    final parts =
        request.uri.pathSegments; // segments, lessonId, resolution, segmentName
    if (parts.length < 4) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }

    final cacheKey = parts.skip(1).join('/'); // lessonId/resolution/segmentName

    if (_segmentCache.containsKey(cacheKey)) {
      request.response
        ..headers.contentType = _contentTypeFor(parts.last)
        ..add(_segmentCache[cacheKey]!)
        ..close();
      return;
    }

    final segmentFile = File('$_downloadPath/$cacheKey');
    if (!await segmentFile.exists()) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }

    final clear = await _isClearFormat(parts[1], parts[2]);
    await _serveFile(request, cacheKey, segmentFile.path, clear: clear);
  }

  Future<String?> _readDownloadMode(String lessonId, String resolution) async {
    final modeFile = File('$_downloadPath/$lessonId/$resolution/.mode');
    if (await modeFile.exists()) {
      return await modeFile.readAsString();
    }
    return null;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _authToken = null;
    _segmentCache.clear();
  }

  String _generateRandomToken() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return values.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }
}
