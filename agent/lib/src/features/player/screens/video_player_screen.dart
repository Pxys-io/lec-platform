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
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../logic/local_video_server.dart';
import '../logic/video_downloader.dart';
import '../logic/watch_progress_tracker.dart';
import '../logic/player_debug.dart';
import '../widgets/player_error_view.dart';
import '../widgets/player_overlays.dart';
import '../widgets/quality_picker.dart';
import '../widgets/up_next_card.dart';
import '../../../repositories/video_repository.dart';
import '../../../repositories/misc_repository.dart';
import '../../../repositories/course_repository.dart';
import '../../../repositories/quiz_repository.dart';
import '../../../api/api_client.dart';
import '../../../models/video.dart';
import '../../../models/lesson.dart';
import '../../../models/quiz.dart';
import '../../../logic/stats/stats_cubit.dart';
import 'package:go_router/go_router.dart';
import '../../comments/screens/comments_sheet.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String lessonId;
  final String? courseId;
  final String userEmail;
  final String studentId;

  const VideoPlayerScreen({
    super.key,
    required this.lessonId,
    this.courseId,
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
  String? _loadError;

  bool _isDownloading = false;
  double _downloadProgress = 0;
  bool _isLocal = false;
  bool _modeMismatchWarning = false;
  String _modeMismatchMessage = '';
  final LocalVideoServer _localServer = LocalVideoServer();
  WatchProgressTracker? _watchTracker;

  @override
  void initState() {
    super.initState();
    try {
      _statsCubit = context.read<StatsCubit>();
    } catch (_) {
      _statsCubit = null;
    }
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

  /// Deletes legacy unversioned playlist cache files left by older app
  /// versions. Those may contain pre-proxy direct video-server URLs (now
  /// 401) or error bodies - never playable.
  Future<void> _purgeLegacyPlaylistCache(String cacheDirPath) async {
    try {
      final dir = Directory(cacheDirPath);
      if (!await dir.exists()) return;
      await for (final e in dir.list()) {
        if (e is File) {
          final name = e.path.split('/').last;
          if (name.startsWith('playlist_') &&
              name.endsWith('.m3u8') &&
              !name.contains('.$kPlaylistCacheVersion.m3u8')) {
            playerLog('purging legacy playlist cache $name');
            await e.delete().catchError((_) => e);
          }
        }
      }
    } catch (e) {
      playerLog('legacy purge failed: $e');
    }
  }

  Future<void> _initializePlayer() async {
    try {
      final videoRepo = context.read<VideoRepository>();
      playerLog('init lesson=${widget.lessonId}');
      final manifest = await videoRepo.getVideoManifest(widget.lessonId);

      _manifest = manifest;
      _loadError = null;
      playerLog(
        'manifest mode=${manifest.streamingMode} '
        'resolutions=${manifest.resolutions.map((r) => r.resolution).join(",")} '
        'watermark=${manifest.watermarkMode} encrypted-keys-in-playlist=yes',
      );

      _watchTracker = WatchProgressTracker(
        misc: context.read<MiscRepository>(),
        lessonId: widget.lessonId,
        deviceInfo: 'agent',
      );

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
        setState(() => _loadError = e.toString());
      }
    }
  }

  Future<void> _measureNetworkSpeed() async {
    try {
      final videoRepo = context.read<VideoRepository>();
      final stopwatch = Stopwatch()..start();
      String testRes = '270p';
      if (_manifest != null && _manifest!.resolutions.isNotEmpty) {
        final sorted = List<VideoResolution>.from(_manifest!.resolutions)
          ..sort((a, b) => a.bitrate.compareTo(b.bitrate));
        testRes = sorted.first.resolution;
      }
      await videoRepo.getPlaylist(widget.lessonId, testRes);
      stopwatch.stop();
      final elapsedSec = stopwatch.elapsedMilliseconds / 1000;
      if (elapsedSec > 0) {
        _estimatedSpeedKbps = (2 * 8) / elapsedSec;
      }
    } catch (_) {
      _estimatedSpeedKbps = 0;
    }
  }

  bool _playerErrorShown = false;

  // Up-next auto-advance (seek-proof: driven by max position reached).
  bool _upNextTriggered = false;
  Lesson? _upNextLesson;
  bool _upNextAuto = true;
  StatsCubit? _statsCubit;

  void _watchForPlayerErrors() {
    _playerErrorShown = false;
    _videoPlayerController?.addListener(() {
      final v = _videoPlayerController?.value;
      if (v != null) {
        _watchTracker?.update(v.position, v.duration);
        // Seek-proof auto-advance: max position reached >= 90% fires once,
        // whether by natural playback or seeking forward.
        if ((_watchTracker?.isComplete ?? false) && !_upNextTriggered) {
          _maybeShowUpNext();
        }
        if (v.hasError &&
            !_playerErrorShown &&
            mounted) {
          _playerErrorShown = true;
          playerLog('EXOPLAYER-ERROR: ${v.errorDescription ?? 'unknown'}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Player error: ${v.errorDescription ?? 'unknown playback error'}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 8),
            ),
          );
        }
      }
    });
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
      _watchForPlayerErrors();
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
      playerLog(
        'loadAndPlay res=${resolution.resolution} '
        'token=${tokenSummary(apiClient.token)} '
        'baseUrl=${apiClient.baseUrl}',
      );

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
        // Versioned cache key: legacy unversioned playlist_*.m3u8 files
        // (possibly poisoned with pre-proxy URLs) are never read again.
        final cacheKey =
            'playlist_${widget.lessonId}_${resolution.resolution}.$kPlaylistCacheVersion.m3u8';
        final playlistFile = File('$cacheDir/$cacheKey');
        // One-time purge of legacy cache files from older app versions.
        _purgeLegacyPlaylistCache(cacheDir);

        if (await playlistFile.exists()) {
          final cached = await playlistFile.readAsString();
          if (cachedPlaylistLooksValid(cached)) {
            playerLog('playlist source=CACHE-FILE $cacheKey');
            playlistContent = cached;
          } else {
            playerLog(
              'playlist source=CACHE-FILE $cacheKey INVALID '
              '(lines=${cached.split('\n').length}) -> refetch',
            );
            await playlistFile.delete().catchError((_) => playlistFile);
            playlistContent = await videoRepo.getPlaylist(
              widget.lessonId,
              resolution.resolution,
            );
            playerLog('playlist source=NETWORK refetch-after-invalid');
          }
        } else {
          playerLog('playlist source=NETWORK fetch');
          playlistContent = await videoRepo.getPlaylist(
            widget.lessonId,
            resolution.resolution,
          );
        }
        playerLog(
          'playlist lines=${playlistContent.split('\n').length} '
          'has-proxy=${playlistContent.contains('/proxy/')} '
          'has-key=${playlistContent.contains('EXT-X-KEY')}',
        );
        if (!cachedPlaylistLooksValid(playlistContent)) {
          playerLog('playlist INVALID from network -> error screen');
          if (mounted) {
            setState(() => _loadError =
                'Server returned an unplayable playlist for ${resolution.resolution}.');
          }
          return;
        }
        // Inject a FRESH auth token into proxy URIs (key / watermark /
        // overlay) so the native player can fetch them without headers
        // (file:// playback). Cached playlists may carry an expired token,
        // so any existing token param is always stripped first.
        final token = apiClient.token ?? '';
        int injected = 0;
        if (token.isNotEmpty && playlistContent.contains('/proxy/')) {
          final proxyPattern = RegExp(
            '${RegExp.escape(apiClient.baseUrl)}/videos/proxy[^\\s"\\n]+',
          );
          final matches = proxyPattern.allMatches(playlistContent).length;
          playlistContent = playlistContent.replaceAllMapped(
            proxyPattern,
            (m) {
              var url = m.group(0)!;
              // Strip any previous token (?token= or &token= with its value).
              url = url.replaceAll(RegExp(r'[?&]token=[^&\s"]*'), '');
              // Preserve other query params if present (unlikely).
              final sep = url.contains('?') ? '&' : '?';
              injected++;
              return '$url${sep}token=$token';
            },
          );
          playerLog('token-inject matched=$matches injected=$injected');
        } else {
          playerLog(
            'token-inject SKIPPED token-empty=${token.isEmpty} '
            'no-proxy=${!playlistContent.contains('/proxy/')}',
          );
        }
        // Log the exact key URI ExoPlayer will fetch (token redacted).
        final keyLine = playlistContent.split('\n').firstWhere(
              (l) => l.contains('EXT-X-KEY'),
              orElse: () => '',
            );
        if (keyLine.isNotEmpty) {
          playerLog(
            'key-uri=${keyLine.replaceAll(RegExp(r'token=[^"&\s]*'), 'token=...')}',
          );
        }
        await playlistFile.writeAsString(playlistContent);
        videoUrl = playlistFile.path;
      }

      final oldController = _videoPlayerController;
      final oldChewie = _chewieController;

      if (_isLocal) {
        playerLog('controller=NETWORK-URL local-server port=${_localServer.port}');
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
          httpHeaders: headers,
        );
      } else {
        playerLog('controller=FILE path=$videoUrl');
        _videoPlayerController = VideoPlayerController.file(File(videoUrl));
      }

      _watchForPlayerErrors();
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

      _watchTracker?.start();

      await oldController?.dispose();
      oldChewie?.dispose();

      if (mounted) setState(() {});

      dev.log('Loaded ${resolution.resolution}${_isLocal ? ' (LOCAL)' : ''}');
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = e.toString());
      }
    }
  }

  Future<void> _retry() async {
    playerLog('retry pressed');
    if (mounted) setState(() => _loadError = null);
    await _initializePlayer();
  }

  /// Shows the Up-next card once the lesson is >=90% watched. Flushes the
  /// final progress first so `previous_lesson` gates are satisfied before
  /// the next lesson's manifest is fetched.
  Future<void> _maybeShowUpNext() async {
    if (_upNextTriggered || !mounted) return;
    final courseId = widget.courseId;
    if (courseId == null || courseId.isEmpty) {
      playerLog('up-next skipped: no courseId');
      return;
    }
    _upNextTriggered = true;
    try {
      // Flush now (don't wait for dispose): the next lesson may be gated on
      // this lesson's completion.
      await _watchTracker?.report();
      final lessons = await context.read<CourseRepository>().getCourseLessons(courseId);
      lessons.sort((a, b) => a.order.compareTo(b.order));
      final idx = lessons.indexWhere((l) => l.id == widget.lessonId);
      final next = (idx >= 0 && idx + 1 < lessons.length) ? lessons[idx + 1] : null;
      if (!mounted) return;
      if (next == null) {
        playerLog('up-next: last lesson, no advance');
        return;
      }
      // previous_lesson gates are satisfied (we just hit >=90%); quiz gates
      // are not - show the card without auto-play for those.
      final auto = next.lockType != 'quiz';
      playerLog('up-next: ${next.title} auto=$auto');
      setState(() {
        _upNextLesson = next;
        _upNextAuto = auto;
      });
    } catch (e) {
      playerLog('up-next lookup failed: $e');
      if (mounted) setState(() => _upNextTriggered = false);
    }
  }

  Future<Quiz?> _loadQuizForLesson(Lesson lesson) async {
    final quizId = lesson.quizId;
    if (quizId == null) return null;
    final quizRepo = context.read<QuizRepository>();
    final quizData = await quizRepo.getQuiz(quizId);
    final questions = await quizRepo.getQuizQuestions(quizId);
    return Quiz(
      id: quizData.id,
      lessonId: quizData.lessonId,
      title: quizData.title,
      description: quizData.description,
      passingScore: quizData.passingScore,
      timeLimit: quizData.timeLimit,
      questions: questions.isNotEmpty ? questions : quizData.questions,
      createdAt: quizData.createdAt,
    );
  }

  Future<void> _playNext() async {
    final next = _upNextLesson;
    if (next == null || !mounted) return;
    playerLog('up-next play: ${next.title}');
    if (next.videoId != null) {
      context.pushReplacement('/video-player', extra: {
        'lessonId': next.id,
        'courseId': widget.courseId,
        'userEmail': widget.userEmail,
        'studentId': widget.studentId,
      });
    } else if (next.quizId != null) {
      try {
        final quiz = await _loadQuizForLesson(next);
        if (!mounted) return;
        if (quiz == null) return;
        context.pushReplacement('/quiz-session', extra: {
          'quiz': quiz,
          'isTutorMode': false,
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load next quiz: $e')),
          );
        }
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

  void _showQualityPicker() {
    final manifest = _manifest;
    if (manifest == null) return;
    final apiClient = context.read<ApiClient>();
    showQualityPicker(
      context,
      manifest: manifest,
      currentResolution: _currentResolution,
      isAutoQuality: _isAutoQuality,
      estimatedSpeedKbps: _estimatedSpeedKbps,
      lessonId: widget.lessonId,
      baseUrl: apiClient.baseUrl,
      authToken: apiClient.token ?? '',
      onAutoChanged: (val) {
        setState(() => _isAutoQuality = val);
        if (val) {
          _measureNetworkSpeed().then((_) {
            if (_manifest != null && mounted) {
              final best = _pickBestQuality(_manifest!);
              if (best.resolution != _currentResolution) {
                _currentResolution = best.resolution;
                _loadAndPlay(best);
              }
            }
          });
        }
      },
      onSelect: (res) {
        setState(() => _currentResolution = res.resolution);
        _loadAndPlay(res);
      },
      onDownload: (res) => _startDownload(res),
    );
  }

  @override
  void dispose() {
    // Flush final progress FIRST, then reload stats so continue-watching
    // picks up this session (sequential: GET must see the POSTed row).
    _watchTracker?.dispose().then((_) => _statsCubit?.loadStats());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _chewieController != null &&
                  _chewieController!.videoPlayerController.value.isInitialized
              ? Center(child: Chewie(controller: _chewieController!))
              : _loadError != null
                  ? PlayerErrorView(message: _loadError!, onRetry: _retry)
                  : const Center(child: CircularProgressIndicator()),

          PlayerOverlays(
            manifest: _manifest,
            watermarkOffset: _watermarkOffset,
            userEmail: widget.userEmail,
            studentId: widget.studentId,
            currentResolution: _currentResolution,
            modeMismatchWarning: _modeMismatchWarning && _isLocal,
            modeMismatchMessage: _modeMismatchMessage,
            isDownloading: _isDownloading,
            downloadProgress: _downloadProgress,
            onBack: () => Navigator.of(context).pop(),
            onComments: () => CommentsSheet.show(
              context,
              lessonId: widget.lessonId,
              currentUserId: widget.studentId,
            ),
            onQualityTap: _showQualityPicker,
          ),

          if (_upNextLesson != null)
            UpNextCard(
              nextTitle: _upNextLesson!.title,
              subtitle: _upNextLesson!.videoId != null
                  ? 'Video lesson'
                  : _upNextLesson!.quizId != null
                      ? 'Quiz'
                      : 'Lesson',
              autoPlay: _upNextAuto,
              onPlayNow: _playNext,
              onDismiss: () {
                if (mounted) setState(() => _upNextLesson = null);
              },
            ),
        ],
      ),
    );
  }
}
