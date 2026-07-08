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
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import '../../../repositories/video_repository.dart';
import '../../../repositories/lesson_repository.dart';
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
  final TextEditingController _notesController = TextEditingController();

  VideoManifest? _manifest;
  String _currentResolution = '';
  bool _isAutoQuality = true;
  double _estimatedSpeedKbps = 0;
  String? _cacheDir;

  @override
  void initState() {
    super.initState();
    _enterFullScreen();
    _protectScreen();
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

      if (manifest.resolutions.isEmpty) {
        throw Exception("No resolutions available");
      }

      _manifest = manifest;

      await _measureNetworkSpeed();
      final selectedRes = _pickBestQuality(manifest);
      _currentResolution = selectedRes.resolution;

      dev.log('Initial quality: ${selectedRes.resolution} (estimated speed: ${_estimatedSpeedKbps.toStringAsFixed(0)} kbps)');

      await _loadAndPlay(selectedRes);
      _startAutoQualityTimer();

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load video: $e')),
        );
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
      final cacheDir = await _getCacheDir();
      final cacheKey = 'playlist_${widget.lessonId}_${resolution.resolution}.m3u8';
      final playlistFile = File('$cacheDir/$cacheKey');

      String playlistContent;
      bool fromCache = false;

      if (await playlistFile.exists()) {
        playlistContent = await playlistFile.readAsString();
        fromCache = true;
      } else {
        playlistContent = await videoRepo.getPlaylist(widget.lessonId, resolution.resolution);
        await playlistFile.writeAsString(playlistContent);
      }

      final oldController = _videoPlayerController;
      final oldChewie = _chewieController;

      _videoPlayerController = VideoPlayerController.file(playlistFile);
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

      dev.log('Loaded ${resolution.resolution}${fromCache ? ' (cached)' : ''}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load ${resolution.resolution}: $e')),
        );
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

  void _showQualityPicker() {
    if (_manifest == null) return;

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
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            title: const Text('Auto Quality', style: TextStyle(color: Colors.white)),
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
            ..._manifest!.resolutions.map((res) => ListTile(
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
                  onTap: () {
                    Navigator.pop(ctx);
                    _currentResolution = res.resolution;
                    _loadAndPlay(res);
                  },
                )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _exitFullScreen();
    ScreenProtector.preventScreenshotOff();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _watermarkTimer?.cancel();
    _autoQualityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool debugMode = true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
              ? Center(child: Chewie(controller: _chewieController!))
              : const Center(child: CircularProgressIndicator()),

          AnimatedPositioned(
            duration: const Duration(seconds: 1),
            left: _watermarkOffset.dx,
            top: _watermarkOffset.dy,
            child: Opacity(
              opacity: 0.22,
              child: Text(
                '${widget.userEmail} — ${widget.studentId}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 2, color: Colors.black)],
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
            right: 80,
            child: IconButton(
              icon: const Icon(LucideIcons.messageSquare, color: Colors.white),
              onPressed: () => CommentsSheet.show(
                context,
                lessonId: widget.lessonId,
                currentUserId: widget.studentId,
              ),
            ),
          ),

          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: _showQualityPicker,
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
                      _currentResolution,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (debugMode)
            Positioned(
              bottom: 80,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.shield, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'WATERMARK MODE: RANDOM POSITION (every 10s)',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
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
                  '${_estimatedSpeedKbps.toStringAsFixed(0)} kbps | ${_isAutoQuality ? "AUTO" : "MANUAL"} | $_currentResolution',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _notesController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a note...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black54,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onSubmitted: (value) async {
                      if (value.isNotEmpty) {
                        try {
                          await context
                              .read<LessonRepository>()
                              .createComment(widget.lessonId, {'content': value});
                          _notesController.clear();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Note saved!')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to save note: $e')),
                            );
                          }
                        }
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: () async {
                    if (_notesController.text.isNotEmpty) {
                      try {
                        await context
                            .read<LessonRepository>()
                            .createComment(widget.lessonId, {'content': _notesController.text});
                        _notesController.clear();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Note saved!')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to save note: $e')),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
