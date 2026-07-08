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
  final List<VideoResolution> resolutions;
  final String defaultResolution;

  VideoManifest({
    required this.videoId,
    required this.resolutions,
    required this.defaultResolution,
  });

  factory VideoManifest.fromJson(Map<String, dynamic> json) {
    return VideoManifest(
      videoId: json['video_id'],
      resolutions: (json['resolutions'] as List)
          .map((res) => VideoResolution.fromJson(Map<String, dynamic>.from(res as Map)))
          .toList(),
      defaultResolution: json['default_resolution'] ?? '720p',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'video_id': videoId,
      'resolutions': resolutions.map((res) => res.toJson()).toList(),
      'default_resolution': defaultResolution,
    };
  }
}
