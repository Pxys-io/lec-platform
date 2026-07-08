import 'dart:io';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/player/logic/video_downloader.dart';
import '../../api/api_client.dart';
import '../../repositories/video_repository.dart';
import 'downloads_state.dart';

class DownloadsCubit extends Cubit<DownloadsState> {
  final ApiClient apiClient;
  final VideoRepository videoRepository;
  final Map<String, VideoDownloader> _activeDownloaders = {};

  DownloadsCubit({
    required this.apiClient,
    required this.videoRepository,
  }) : super(const DownloadsState());

  Future<void> init() async {
    await refresh();
  }

  Future<void> refresh() async {
    emit(state.copyWith(isLoading: true));
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/downloads');
      
      if (!await downloadsDir.exists()) {
        emit(state.copyWith(completed: [], isLoading: false));
        return;
      }

      List<CompletedDownload> completed = [];
      final lessons = downloadsDir.listSync();
      
      for (var lessonFolder in lessons) {
        if (lessonFolder is Directory) {
          final lessonId = lessonFolder.path.split('/').last;
          final resolutions = lessonFolder.listSync();
          
          for (var resFolder in resolutions) {
            if (resFolder is Directory) {
              final resolution = resFolder.path.split('/').last;
              final playlist = File('${resFolder.path}/playlist.m3u8');
              
              if (await playlist.exists()) {
                // Calculate size
                int totalSize = 0;
                final files = resFolder.listSync();
                for (var file in files) {
                  if (file is File) totalSize += await file.length();
                }

                completed.add(CompletedDownload(
                  lessonId: lessonId,
                  title: 'Lesson $lessonId', // In a real app, we'd store titles in a DB
                  resolution: resolution,
                  path: resFolder.path,
                  downloadedAt: (await playlist.lastModified()),
                  sizeInBytes: totalSize,
                ));
              }
            }
          }
        }
      }

      emit(state.copyWith(completed: completed, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> startDownload({
    required String lessonId,
    required String title,
    required String resolution,
  }) async {
    // Check if already downloading
    final downloadKey = '${lessonId}_$resolution';
    if (_activeDownloaders.containsKey(downloadKey)) return;

    final appDir = await getApplicationDocumentsDirectory();
    final downloader = VideoDownloader(
      baseUrl: apiClient.baseUrl,
      authToken: apiClient.token ?? '',
      baseDir: appDir.path,
    );

    _activeDownloaders[downloadKey] = downloader;

    final activeItem = ActiveDownload(
      lessonId: lessonId,
      title: title,
      resolution: resolution,
      progress: 0,
      totalSegments: 0,
      downloadedSegments: 0,
    );

    emit(state.copyWith(active: [...state.active, activeItem]));

    try {
      final playlistContent = await videoRepository.getPlaylist(lessonId, resolution);
      
      await downloader.downloadVideo(
        lessonId: lessonId,
        resolution: resolution,
        playlistContent: playlistContent,
        onProgress: (p) {
          final currentActive = state.active.map((item) {
            if (item.lessonId == lessonId && item.resolution == resolution) {
              return ActiveDownload(
                lessonId: lessonId,
                title: title,
                resolution: resolution,
                progress: p.progress,
                totalSegments: p.totalSegments,
                downloadedSegments: p.downloadedSegments,
              );
            }
            return item;
          }).toList();
          emit(state.copyWith(active: currentActive));
        },
      );

      _activeDownloaders.remove(downloadKey);
      final remainingActive = state.active.where((item) => 
        item.lessonId != lessonId || item.resolution != resolution).toList();
      
      emit(state.copyWith(active: remainingActive));
      await refresh(); // Refresh completed list
    } catch (e) {
      _activeDownloaders.remove(downloadKey);
      final remainingActive = state.active.where((item) => 
        item.lessonId != lessonId || item.resolution != resolution).toList();
      emit(state.copyWith(active: remainingActive));
    }
  }

  void cancelDownload(String lessonId, String resolution) {
    final downloadKey = '${lessonId}_$resolution';
    if (_activeDownloaders.containsKey(downloadKey)) {
      // Note: VideoDownloader needs cancel support. 
      // For now we'll just remove it from state and stop the loop if possible
      // Realistically we need a way to stop the 'downloadVideo' future.
      _activeDownloaders[downloadKey]?.close();
      _activeDownloaders.remove(downloadKey);
    }
    
    final remainingActive = state.active.where((item) => 
      item.lessonId != lessonId || item.resolution != resolution).toList();
    emit(state.copyWith(active: remainingActive));
  }

  Future<void> deleteDownload(String lessonId, String resolution) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/downloads/$lessonId/$resolution');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      await refresh();
    } catch (e) {
      // Handle error
    }
  }

  Future<bool> isDownloaded(String lessonId, String resolution) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/downloads/$lessonId/$resolution/playlist.m3u8');
    return await file.exists();
  }
}
