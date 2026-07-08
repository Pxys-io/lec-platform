import 'package:equatable/equatable.dart';

abstract class DownloadItem extends Equatable {
  final String lessonId;
  final String title;
  final String resolution;

  const DownloadItem({
    required this.lessonId,
    required this.title,
    required this.resolution,
  });

  @override
  List<Object?> get props => [lessonId, resolution];
}

class CompletedDownload extends DownloadItem {
  final String path;
  final DateTime downloadedAt;
  final int sizeInBytes;

  const CompletedDownload({
    required super.lessonId,
    required super.title,
    required super.resolution,
    required this.path,
    required this.downloadedAt,
    required this.sizeInBytes,
  });

  @override
  List<Object?> get props => [...super.props, path, downloadedAt, sizeInBytes];
}

class ActiveDownload extends DownloadItem {
  final double progress;
  final int totalSegments;
  final int downloadedSegments;

  const ActiveDownload({
    required super.lessonId,
    required super.title,
    required super.resolution,
    required this.progress,
    required this.totalSegments,
    required this.downloadedSegments,
  });

  @override
  List<Object?> get props => [...super.props, progress, totalSegments, downloadedSegments];
}

class DownloadsState extends Equatable {
  final List<CompletedDownload> completed;
  final List<ActiveDownload> active;
  final bool isLoading;

  const DownloadsState({
    this.completed = const [],
    this.active = const [],
    this.isLoading = false,
  });

  DownloadsState copyWith({
    List<CompletedDownload>? completed,
    List<ActiveDownload>? active,
    bool? isLoading,
  }) {
    return DownloadsState(
      completed: completed ?? this.completed,
      active: active ?? this.active,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object> get props => [completed, active, isLoading];
}
