import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:lucide_icons_flutter/lucide_icons_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../logic/local_video_server.dart';
import '../logic/video_downloader.dart';
import '../../../repositories/video_repository.dart';
import '../../../api/api_client.dart';
import '../../../models/video.dart';
import '../../comments/screens/comments_sheet.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String lessonId;
  final String userEmail;
  final String studentId;

  const VideoPlayerScreen({
    super.key,
    required this.lessonId,
    required this.userEmail,
    required this.studentId,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  Timer? _watermarkTimer;
  Timer? _autoQualityTimer;
  Offset _watermarkOffset = const Offset(20, 20);

  VideoManifest? _manifest;
  String _currentResolution = '';
  bool _isAutoQuality = true;
  double _estimatedSpeedKbps = 0;
  String? _cacheDir;
  List<double> _watermarkTimes = [];

  bool _isDownloading = false;
  double _downloadProgress = 0;
  bool _isLocal = false;
  bool _modeMismatchWarning = false;
  String _modeMismatchMessage = '';
  final LocalVideoServer _localServer = LocalVideoServer();

  @override
  void initState() {
    super.initState();
    _enterFullScreen();
    _protectScreen();
    WakelockPlus.enable();
    _initializePlayer();
    _startWatermarkTimer();
  }

  Future<void> _enterFullScreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _exitFullScreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  Future<void> _protectScreen() async {
    await ScreenProtector.protectDataLeakageWithBlur();
    await ScreenProtector.preventScreenshotOn();
  }

  Future<String> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/video_cache';
    final cacheDir = Directory(path);
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    _cacheDir = path;
    return _cacheDir!;
  }

  Future<void> _initializePlayer() async {
    try {
      final videoRepo = context.read<VideoRepository>();
      final manifest = await videoRepo.getVideoManifest(widget.lessonId);

      _manifest = manifest;

      if (manifest.streamingMode == 'direct') {
        await _loadAndPlayDirect();
      } else {
        if (manifest.resolutions.isEmpty) {
          throw Exception("No resolutions available");
        }

        await _measureNetworkSpeed();
        final selectedRes = _pickBestQuality(manifest);
        _currentResolution = selectedRes.resolution;

        dev.log(
          'Initial quality: ${selectedRes.resolution} (estimated speed: ${_estimatedSpeedKbps.toStringAsFixed(0)} kbps)',
        );

        await _loadAndPlay(selectedRes);
        _startAutoQualityTimer();
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load video: $e')));
      }
    }
  }

  Future<void> _measureNetworkSpeed() async {
    try {
      final videoRepo = context.read<VideoRepository>();
      final stopwatch = Stopwatch()..start();
      await videoRepo.getPlaylist(widget.lessonId, '360p');
      stopwatch.stop();
      final elapsedSec = stopwatch.elapsedMilliseconds / 1000;
      if (elapsedSec > 0) {
        _estimatedSpeedKbps = (2 * 8) / elapsedSec;
      }
    } catch (_) {
      _estimatedSpeedKbps = 0;
    }
  }

  Future<void> _loadAndPlayDirect() async {
    try {
      final videoRepo = context.read<VideoRepository>();
      final url = videoRepo.getRawVideoUrl(widget.lessonId);
      final oldController = _videoPlayerController;
      final oldChewie = _chewieController;

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: {
          'Authorization': 'Bearer ${context.read<ApiClient>().token}',
        },
      );
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        placeholder: const Center(child: CircularProgressIndicator()),
        allowPlaybackSpeedChanging: true,
      );

      await oldController?.dispose();
      oldChewie?.dispose();

      if (mounted) setState(() {});
      dev.log('Loaded direct stream from $url');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load direct stream: $e')),
        );
      }
    }
  }

  VideoResolution _pickBestQuality(VideoManifest manifest) {
    if (!_isAutoQuality) return manifest.resolutions.first;

    final sorted = List<VideoResolution>.from(manifest.resolutions)
      ..sort((a, b) => a.bitrate.compareTo(b.bitrate));

    for (int i = sorted.length - 1; i >= 0; i--) {
      if (_estimatedSpeedKbps >= sorted[i].bitrate / 500) {
        return sorted[i];
      }
    }
    return sorted.first;
  }

  Future<void> _loadAndPlay(VideoResolution resolution) async {
    try {
      final videoRepo = context.read<VideoRepository>();
      final apiClient = context.read<ApiClient>();

      final appDir = await getApplicationDocumentsDirectory();
      final downloader = VideoDownloader(
        baseUrl: apiClient.baseUrl,
        authToken: apiClient.token ?? '',
        baseDir: appDir.path,
      );

      final isDownloaded = await downloader.isDownloaded(
        widget.lessonId,
        resolution.resolution,
      );

      String videoUrl;
      Map<String, String> headers = {};
      String playlistContent;

      if (isDownloaded) {
        final prefs = await SharedPreferences.getInstance();
        await _localServer.start(
          '${appDir.path}/downloads',
          serverMode: prefs.getString('server_mode') ?? 'hybrid',
          mismatchAction: prefs.getString('mode_mismatch_action') ?? 'warn',
          downloadPolicy: prefs.getString('download_policy') ?? 'allow',
        );

        if (_localServer.blockReason != null) {
          setState(() {
            _modeMismatchWarning = true;
            _modeMismatchMessage =
                _localServer.blockReason!.startsWith('MODE_MISMATCH_BLOCK')
                ? 'This video was downloaded in a mode no longer supported by the server. Admin has blocked playback.'
                : 'This video was downloaded in a mode no longer supported. Auto-deleted per admin policy.';
          });

          if (_localServer.blockReason == 'MODE_MISMATCH_AUTO_DELETED') {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_modeMismatchMessage),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
          return;
        }

        videoUrl =
            'http://localhost:${_localServer.port}/playlist/${widget.lessonId}/${resolution.resolution}.m3u8';
        headers = {'Authorization': 'Bearer ${_localServer.authToken}'};
        _isLocal = true;

        final playlistFile = File(
          '${appDir.path}/downloads/${widget.lessonId}/${resolution.resolution}/playlist.m3u8',
        );
        playlistContent = await playlistFile.readAsString();

        final modeFile = File(
          '${appDir.path}/downloads/${widget.lessonId}/${resolution.resolution}/.mode',
        );
        if (await modeFile.exists()) {
          final dlMode = await modeFile.readAsString();
          final srvMode = prefs.getString('server_mode') ?? 'hybrid';
          if (dlMode != srvMode) {
            setState(() {
              _modeMismatchWarning = true;
              _modeMismatchMessage =
                  'Mode mismatch: downloaded in "$dlMode" mode, server is now in "$srvMode" mode.';
            });
          } else {
            setState(() {
              _modeMismatchWarning = false;
            });
          }
        }

        dev.log('Playing from local server: $videoUrl');
      } else {
        _isLocal = false;
        final cacheDir = await _getCacheDir();
        final cacheKey =
            'playlist_${widget.lessonId}_${resolution.resolution}.m3u8';
        final playlistFile = File('$cacheDir/$cacheKey');

        if (await playlistFile.exists()) {
          playlistContent = await playlistFile.readAsString();
          videoUrl = playlistFile.path;
        } else {
          playlistContent = await videoRepo.getPlaylist(
            widget.lessonId,
            resolution.resolution,
          );
          await playlistFile.writeAsString(playlistContent);
          videoUrl = playlistFile.path;
        }
      }

      _watermarkTimes = _parseWatermarkTimes(playlistContent);
      if (_watermarkTimes.isNotEmpty) {
        dev.log(
          'Watermarked segments at: ${_watermarkTimes.map((t) => '${t.toStringAsFixed(1)}s').join(', ')}',
        );
      }

      final oldController = _videoPlayerController;
      final oldChewie = _chewieController;

      if (_isLocal) {
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
          httpHeaders: headers,
        );
      } else {
        _videoPlayerController = VideoPlayerController.file(File(videoUrl));
      }

      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        placeholder: const Center(child: CircularProgressIndicator()),
        allowPlaybackSpeedChanging: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.blue,
          handleColor: Colors.blueAccent,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white70,
        ),
      );

      await oldController?.dispose();
      oldChewie?.dispose();

      if (mounted) setState(() {});

      dev.log('Loaded ${resolution.resolution}${_isLocal ? ' (LOCAL)' : ''}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load ${resolution.resolution}: $e'),
          ),
        );
      }
    }
  }

  Future<void> _startDownload(VideoResolution resolution) async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      final apiClient = context.read<ApiClient>();
      final videoRepo = context.read<VideoRepository>();

      final playlistContent = await videoRepo.getPlaylist(
        widget.lessonId,
        resolution.resolution,
      );

      final appDir = await getApplicationDocumentsDirectory();
      final prefs = await SharedPreferences.getInstance();
      final modeWhenDownloaded = prefs.getString('server_mode') ?? 'hybrid';
      final downloader = VideoDownloader(
        baseUrl: apiClient.baseUrl,
        authToken: apiClient.token ?? '',
        baseDir: appDir.path,
      );

      await downloader.downloadVideo(
        lessonId: widget.lessonId,
        resolution: resolution.resolution,
        playlistContent: playlistContent,
        modeWhenDownloaded: modeWhenDownloaded,
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _downloadProgress = p.progress;
            });
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Download complete!')));
        // Refresh player to play from local if it's the current resolution
        if (_currentResolution == resolution.resolution) {
          _loadAndPlay(resolution);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  void _startAutoQualityTimer() {
    _autoQualityTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted || !_isAutoQuality || _manifest == null) return;

      await _measureNetworkSpeed();
      final best = _pickBestQuality(_manifest!);
      if (best.resolution != _currentResolution) {
        dev.log('Auto-switch: $_currentResolution -> ${best.resolution}');
        _currentResolution = best.resolution;
        await _loadAndPlay(best);
      }
    });
  }

  void _startWatermarkTimer() {
    _watermarkTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        final random = Random();
        final size = MediaQuery.of(context).size;
        setState(() {
          _watermarkOffset = Offset(
            random.nextDouble() * (size.width - 200),
            random.nextDouble() * (size.height - 100),
          );
        });
      }
    });
  }

  void _showQualityPicker() async {
    if (_manifest == null) return;
    final appDir = await getApplicationDocumentsDirectory();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (ctx) => Column(
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
            title: const Text(
              'Auto Quality',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Estimated: ${_estimatedSpeedKbps.toStringAsFixed(0)} kbps',
              style: const TextStyle(color: Colors.white54),
            ),
            value: _isAutoQuality,
            onChanged: (val) {
              setState(() => _isAutoQuality = val);
              Navigator.pop(ctx);
              if (val) {
                _measureNetworkSpeed().then((_) {
                  if (_manifest != null) {
                    final best = _pickBestQuality(_manifest!);
                    if (best.resolution != _currentResolution) {
                      _currentResolution = best.resolution;
                      _loadAndPlay(best);
                    }
                  }
                });
              }
            },
          ),
          if (!_isAutoQuality)
            ..._manifest!.resolutions.map((res) {
              return FutureBuilder<bool>(
                future: VideoDownloader(
                  baseUrl: context.read<ApiClient>().baseUrl,
                  authToken: context.read<ApiClient>().token ?? '',
                  baseDir: appDir.path,
                ).isDownloaded(widget.lessonId, res.resolution),
                builder: (context, snapshot) {
                  final isDownloaded = snapshot.data ?? false;
                  return ListTile(
                    leading: Icon(
                      res.resolution == _currentResolution
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
                            icon: const Icon(
                              Icons.download,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _startDownload(res);
                            },
                          ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _currentResolution = res.resolution;
                      _loadAndPlay(res);
                    },
                  );
                },
              );
            }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _localServer.stop();
    _exitFullScreen();
    ScreenProtector.preventScreenshotOff();
    WakelockPlus.disable();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _watermarkTimer?.cancel();
    _autoQualityTimer?.cancel();
    super.dispose();
  }

  Color _hexColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  List<double> _parseWatermarkTimes(String playlist) {
    try {
      final line = playlist
          .split('\n')
          .firstWhere(
            (l) => l.startsWith('# Watermarked segments:'),
            orElse: () => '',
          );
      if (line.isEmpty) return [];
      final valStr = line.split(': ').last;
      return valStr.split(',').map((entry) {
        final parts = entry.trim().split(':');
        if (parts.length < 2) return 0.0;
        final timePart = parts[1].split('+')[0].split('-')[0];
        return double.tryParse(timePart.trim()) ?? 0.0;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool debugMode = true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _chewieController != null &&
                  _chewieController!.videoPlayerController.value.isInitialized
              ? Center(child: Chewie(controller: _chewieController!))
              : const Center(child: CircularProgressIndicator()),

          if (_manifest != null)
            AnimatedPositioned(
              duration: const Duration(seconds: 1),
              left: _watermarkOffset.dx,
              top: _watermarkOffset.dy,
              child: Opacity(
                opacity: _manifest!.watermarkOpacity.clamp(0.0, 1.0),
                child: Text(
                  '${widget.userEmail} — ${widget.studentId}',
                  style: TextStyle(
                    color: _hexColor(_manifest!.watermarkColor),
                    fontSize: _manifest!.watermarkFontSize.toDouble(),
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
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          Positioned(
            top: 40,
            right: 20,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    LucideIcons.messageSquare,
                    color: Colors.white,
                  ),
                  onPressed: () => CommentsSheet.show(
                    context,
                    lessonId: widget.lessonId,
                    currentUserId: widget.studentId,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _showQualityPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.monitor,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _currentResolution,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_modeMismatchWarning && _isLocal)
            Positioned(
              top: 80,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.shieldAlert,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _modeMismatchMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (debugMode && _manifest != null)
            Positioned(
              bottom: 80,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.shield,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'WATERMARK MODE: ${_manifest!.watermarkMode.toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (_watermarkTimes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'SEGMENTS AT: ${_watermarkTimes.map((t) => '${t.toStringAsFixed(1)}s').join(', ')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          if (debugMode)
            Positioned(
              bottom: 60,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_estimatedSpeedKbps.toStringAsFixed(0)} kbps | ${_isAutoQuality ? "AUTO" : "MANUAL"} | $_currentResolution${_isLocal ? " (LOCAL)" : ""}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          if (_isDownloading)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Downloading... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),

          if (debugMode &&
              _watermarkTimes.isNotEmpty &&
              _videoPlayerController != null)
            Positioned(
              bottom: 55,
              left: 0,
              right: 0,
              height: 4,
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final total =
                      _videoPlayerController!.value.duration.inMilliseconds /
                      1000.0;
                  if (total <= 0) return const SizedBox();
                  return Stack(
                    children: _watermarkTimes.map((t) {
                      final fraction = (t / total).clamp(0.0, 1.0);
                      return Positioned(
                        left: constraints.maxWidth * fraction,
                        top: 0,
                        child: Container(
                          width: 3,
                          height: 4,
                          color: Colors.yellow,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
