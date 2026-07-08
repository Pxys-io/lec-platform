import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:agent/agent.dart';
import 'package:uuid/uuid.dart';
import '../lib/src/features/player/logic/local_video_server.dart';
import '../lib/src/features/player/logic/video_downloader.dart';

void main() async {
  print('Starting Self-Orchestrated E2E Secure Streaming Integration Test...');

  // 1. Configuration for non-default ports
  const mainPort = 9000;
  const videoPort = 9001;
  const dashboardPort = 9002;
  const baseUrl = 'http://localhost:$mainPort/api/v1';

  Process? setupProcess;

  try {
    // 2. Run setup.sh with local mode and custom ports
    print('Running setup.sh in local mode (Ports: $mainPort, $videoPort)...');

    setupProcess = await Process.start('bash', [
      'setup.sh',
      '--local',
      '--yes',
      '--main-port',
      mainPort.toString(),
      '--video-port',
      videoPort.toString(),
      '--dashboard-port',
      dashboardPort.toString(),
    ], workingDirectory: Directory.current.parent.path);

    setupProcess.stdout
        .transform(utf8.decoder)
        .listen((data) => stdout.write(data));
    setupProcess.stderr
        .transform(utf8.decoder)
        .listen((data) => stderr.write(data));

    final exitCode = await setupProcess.exitCode;
    if (exitCode != 0) {
      print('Setup failed with exit code $exitCode');
      exit(1);
    }
    print('Environment is ready.');

    // 3. Initialize Backend with random device ID for testing
    final testDeviceId = const Uuid().v7();
    final backend = Backend.create(baseUrl, deviceId: testDeviceId);
    final tempDir = Directory.systemTemp.createTempSync('e2e_video_test_auto');
    final downloadPath = '${tempDir.path}/downloads_root';

    final client = HttpClient();

    // 4. Login
    print('Logging in as student...');
    final token = await backend.auth.login(
      'student@lec.com',
      'student123',
      deviceId: testDeviceId,
    );
    print('Logged in successfully.');

    // 5. Find a lesson with a video
    print('Searching for a lesson with a video...');
    final courses = await backend.courses.getCourses();
    String? testLessonId;
    String? videoId;

    for (var course in courses) {
      final lessons = await backend.courses.getCourseLessons(course.id);
      for (var lesson in lessons) {
        if (lesson.videoId != null) {
          testLessonId = lesson.id;
          videoId = lesson.videoId;
          break;
        }
      }
      if (testLessonId != null) break;
    }

    if (testLessonId == null) {
      throw Exception('No lesson with a video found.');
    }
    print('Found lesson $testLessonId with video $videoId');

    // 6. Get Manifest and Playlist
    print('Getting video manifest...');
    final manifest = await backend.videos.getVideoManifest(testLessonId);
    final resolution = manifest.resolutions.first.resolution;
    print('Got manifest. Selected resolution: $resolution');

    print('Fetching playlist content from backend...');
    final playlistContent = await backend.videos.getPlaylist(
      testLessonId,
      resolution,
    );
    print('Playlist fetched.');

    // 7. Download Video (Encrypts segments)
    print('Downloading and encrypting video segments...');
    final downloader = VideoDownloader(
      baseUrl: baseUrl,
      authToken: token,
      baseDir: downloadPath,
    );

    await downloader.downloadVideo(
      lessonId: testLessonId,
      resolution: resolution,
      playlistContent: playlistContent,
      onProgress: (p) {
        stdout.write(
          '\r   Progress: ${(p.progress * 100).toStringAsFixed(1)}% (${p.downloadedSegments}/${p.totalSegments})',
        );
      },
    );
    print('\nDownload complete.');
    downloader.close();

    // 8. Start Local Server
    print('Starting LocalVideoServer using $downloadPath/downloads...');
    final server = LocalVideoServer();
    await server.start('$downloadPath/downloads');
    print('Server started on port ${server.port}');

    // 9. Verify Playlist through local server
    print('Fetching playlist through local server...');
    final playlistReq = await client.getUrl(
      Uri.parse(
        'http://localhost:${server.port}/playlist/$testLessonId/$resolution.m3u8',
      ),
    );
    playlistReq.headers.set('Authorization', 'Bearer ${server.authToken}');
    final playlistRes = await playlistReq.close();

    if (playlistRes.statusCode != 200) {
      throw Exception(
        'Failed to fetch playlist from local server: ${playlistRes.statusCode}',
      );
    }

    final updatedPlaylist = await playlistRes.transform(utf8.decoder).join();
    print('Playlist retrieved from local server.');

    if (!updatedPlaylist.contains(
      'http://localhost:${server.port}/segments/$testLessonId/$resolution/segment_0.ts',
    )) {
      throw Exception('Playlist URL rewriting failed.');
    }
    print('Playlist URL rewriting verified.');

    // 10. Verify Segment Decryption
    print('Fetching and decrypting segment_0.ts...');
    final segmentReq = await client.getUrl(
      Uri.parse(
        'http://localhost:${server.port}/segments/$testLessonId/$resolution/segment_0.ts',
      ),
    );
    segmentReq.headers.set('Authorization', 'Bearer ${server.authToken}');
    final segmentRes = await segmentReq.close();

    if (segmentRes.statusCode != 200) {
      throw Exception(
        'Failed to fetch segment from local server: ${segmentRes.statusCode}',
      );
    }

    final List<int> decryptedData = [];
    await for (var chunk in segmentRes) {
      decryptedData.addAll(chunk);
    }
    print('Received ${decryptedData.length} bytes of decrypted data.');

    if (decryptedData.isEmpty) {
      throw Exception('Decrypted data is empty.');
    }

    print('E2E Test Passed Successfully!');
    await server.stop();

    // Final cleanup of the servers we started
    _killServers(mainPort, videoPort, dashboardPort);
    tempDir.deleteSync(recursive: true);
    exit(0);
  } catch (e, stack) {
    print('\nE2E Test Failed: $e');
    print(stack);
    _killServers(mainPort, videoPort, dashboardPort);
    exit(1);
  }
}

void _killServers(int mainPort, int videoPort, int dashboardPort) {
  print(
    'Cleaning up servers on ports $mainPort, $videoPort, $dashboardPort...',
  );
  _killPort(mainPort);
  _killPort(videoPort);
  _killPort(dashboardPort);
}

void _killPort(int port) {
  try {
    final result = Process.runSync('lsof', ['-ti', ':$port']);
    final pids = result.stdout.toString().trim().split('\n');
    for (var pid in pids) {
      if (pid.isNotEmpty) {
        Process.runSync('kill', ['-9', pid]);
      }
    }
  } catch (_) {}
}
