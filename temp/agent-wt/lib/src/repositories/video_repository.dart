import '../models/video.dart';
import '../api/api_client.dart';

class VideoRepository {
  final ApiClient apiClient;

  VideoRepository({required this.apiClient});

  Future<VideoManifest> getVideoManifest(String lessonId) async {
    final response = await apiClient.get('/videos/$lessonId/manifest');
    return VideoManifest.fromJson(Map<String, dynamic>.from(response as Map));
  }

  // Returns the proxied m3u8 playlist content
  Future<String> getPlaylist(String lessonId, String resolution) async {
    final response = await apiClient.get('/videos/$lessonId/playlist/$resolution');
    // ApiClient might try to jsonDecode it, we need to handle plain text
    return response.toString();
  }
}
