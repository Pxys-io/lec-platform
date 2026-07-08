class VideoResolution {
  final String id;
  final String videoId;
  final String resolution;
  final int width;
  final int height;
  final int bitrate;
  final String? playlistUrl;
  final int segmentsCount;
  final int totalSizeBytes;
  final String status;
  final DateTime createdAt;

  VideoResolution({
    required this.id,
    required this.videoId,
    required this.resolution,
    required this.width,
    required this.height,
    required this.bitrate,
    this.playlistUrl,
    required this.segmentsCount,
    required this.totalSizeBytes,
    required this.status,
    required this.createdAt,
  });

  factory VideoResolution.fromJson(Map<String, dynamic> json) {
    return VideoResolution(
      id: json['id'],
      videoId: json['video_id'],
      resolution: json['resolution'],
      width: json['width'],
      height: json['height'],
      bitrate: json['bitrate'],
      playlistUrl: json['playlist_url'],
      segmentsCount: json['segments_count'],
      totalSizeBytes: json['total_size_bytes'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'video_id': videoId,
      'resolution': resolution,
      'width': width,
      'height': height,
      'bitrate': bitrate,
      'playlist_url': playlistUrl,
      'segments_count': segmentsCount,
      'total_size_bytes': totalSizeBytes,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class VideoManifest {
  final String videoId;
  final String folder;
  final String streamingMode;
  final bool watermarkEnabled;
  final String watermarkMode;
  final String watermarkColor;
  final int watermarkFontSize;
  final double watermarkOpacity;
  final int watermarkOverlayCount;
  final double watermarkInsertDuration;
  final int watermarkInsertRepeat;
  final String watermarkPosition;
  final List<VideoResolution> resolutions;
  final String defaultResolution;
  final String serverMode;
  final String downloadPolicy;
  final String modeMismatchAction;
  final VideoModePolicyInfo? videoPolicy;

  VideoManifest({
    required this.videoId,
    required this.folder,
    required this.streamingMode,
    required this.watermarkEnabled,
    required this.watermarkMode,
    required this.watermarkColor,
    required this.watermarkFontSize,
    required this.watermarkOpacity,
    required this.watermarkOverlayCount,
    required this.watermarkInsertDuration,
    required this.watermarkInsertRepeat,
    required this.watermarkPosition,
    required this.resolutions,
    required this.defaultResolution,
    this.serverMode = 'hybrid',
    this.downloadPolicy = 'allow',
    this.modeMismatchAction = 'warn',
    this.videoPolicy,
  });

  factory VideoManifest.fromJson(Map<String, dynamic> json) {
    VideoModePolicyInfo? videoPolicy;
    if (json['video_policy'] != null) {
      videoPolicy = VideoModePolicyInfo.fromJson(
        Map<String, dynamic>.from(json['video_policy']),
      );
    }

    return VideoManifest(
      videoId: json['video_id'],
      folder: json['folder'] ?? 'General',
      streamingMode: json['streaming_mode'] ?? 'hls',
      watermarkEnabled: json['watermark_enabled'] ?? true,
      watermarkMode: json['watermark_mode'] ?? 'insert',
      watermarkColor: json['watermark_color'] ?? '#FFFFFF',
      watermarkFontSize: json['watermark_font_size'] ?? 20,
      watermarkOpacity: (json['watermark_opacity'] as num?)?.toDouble() ?? 0.4,
      watermarkOverlayCount: json['watermark_overlay_count'] ?? 1,
      watermarkInsertDuration:
          (json['watermark_insert_duration'] as num?)?.toDouble() ?? 1.0,
      watermarkInsertRepeat: json['watermark_insert_repeat'] ?? 1,
      watermarkPosition: json['watermark_position'] ?? 'random',
      resolutions: (json['resolutions'] as List)
          .map(
            (res) =>
                VideoResolution.fromJson(Map<String, dynamic>.from(res as Map)),
          )
          .toList(),
      defaultResolution: json['default_resolution'] ?? '720p',
      serverMode: json['server_mode'] ?? 'hybrid',
      downloadPolicy: json['download_policy'] ?? 'allow',
      modeMismatchAction: json['mode_mismatch_action'] ?? 'warn',
      videoPolicy: videoPolicy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'video_id': videoId,
      'folder': folder,
      'streaming_mode': streamingMode,
      'watermark_enabled': watermarkEnabled,
      'watermark_mode': watermarkMode,
      'watermark_color': watermarkColor,
      'watermark_font_size': watermarkFontSize,
      'watermark_opacity': watermarkOpacity,
      'watermark_overlay_count': watermarkOverlayCount,
      'watermark_insert_duration': watermarkInsertDuration,
      'watermark_insert_repeat': watermarkInsertRepeat,
      'watermark_position': watermarkPosition,
      'resolutions': resolutions.map((res) => res.toJson()).toList(),
      'default_resolution': defaultResolution,
      'server_mode': serverMode,
      'download_policy': downloadPolicy,
      'mode_mismatch_action': modeMismatchAction,
      'video_policy': videoPolicy?.toJson(),
    };
  }
}

class VideoModePolicyInfo {
  final String? currentAction;
  final bool banned;
  final String? modeWhenDownloaded;

  VideoModePolicyInfo({
    this.currentAction,
    required this.banned,
    this.modeWhenDownloaded,
  });

  factory VideoModePolicyInfo.fromJson(Map<String, dynamic> json) {
    return VideoModePolicyInfo(
      currentAction: json['current_action'] as String?,
      banned: json['banned'] as bool? ?? false,
      modeWhenDownloaded: json['mode_when_downloaded'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_action': currentAction,
      'banned': banned,
      'mode_when_downloaded': modeWhenDownloaded,
    };
  }
}
