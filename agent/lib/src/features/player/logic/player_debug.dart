import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Player debug logging. Always on (debugPrint is stripped from release
/// builds) and concise: no bodies, no full tokens - only prefixes, counts,
/// and expiries. Enough to diagnose playback failures from logcat.
void playerLog(String msg) {
  debugPrint('[PLAYER] $msg');
}

/// Returns seconds until the JWT access token expires (null if unreadable).
/// Decodes the payload client-side without verifying - for diagnostics only.
int? tokenSecondsLeft(String? token) {
  if (token == null || token.isEmpty) return null;
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    var payload = parts[1];
    payload += '=' * ((4 - payload.length % 4) % 4);
    final json = jsonDecode(utf8.decode(base64Url.decode(payload)));
    final exp = json['exp'];
    if (exp is! num) return null;
    return exp.toInt() - DateTime.now().millisecondsSinceEpoch ~/ 1000;
  } catch (_) {
    return null;
  }
}

String tokenSummary(String? token) {
  if (token == null || token.isEmpty) return 'EMPTY';
  final left = tokenSecondsLeft(token);
  final expStr = left == null ? 'unreadable-exp' : '${left}s-left';
  return 'len=${token.length} prefix=${token.substring(0, 12)}... $expStr';
}

/// Cache filename version for temp remote playlists. Bump when the playlist
/// format handling changes so poisoned/legacy cache files are never read.
const String kPlaylistCacheVersion = 'v3';

/// A cached playlist is usable only if it looks like a real HLS playlist
/// served through the main-server proxy. Stale files from older app versions
/// (direct video-server URLs, error bodies, truncated downloads) must be
/// discarded so the player fetches a fresh one instead of playing garbage.
bool cachedPlaylistLooksValid(String content) {  if (!content.contains('#EXTM3U')) return false;
  // Direct video-server origins (pre-proxy format) are dead since the
  // internal API requires the service token - segments fetched from them
  // 401. Only proxied playlists are playable.
  if (content.contains('/internal/videos/') && !content.contains('/proxy/')) {
    return false;
  }
  // Must contain at least one media segment reference.
  final hasSegment = content.split('\n').any((l) {
    final t = l.trim();
    return t.isNotEmpty &&
        !t.startsWith('#') &&
        (t.startsWith('http') ||
            t.endsWith('.ts') ||
            t.endsWith('.m4s') ||
            t.endsWith('.mp4'));
  });
  return hasSegment;
}

/// A STORED offline playlist (encrypted-at-rest format) is playable only if
/// it is fully self-contained: every media/key/init reference must be a
/// relative local file. Anything pointing at the network (proxy URLs needing
/// auth, R2, video-server origins) would fail offline and must be rejected
/// so the user gets a clear error instead of a hung player.
bool localOfflinePlaylistLooksValid(String content) {
  if (!content.contains('#EXTM3U')) return false;
  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#EXT-X-KEY:') || line.startsWith('#EXT-X-MAP:')) {
      final m = RegExp(r'URI="([^"]+)"').firstMatch(line);
      final uri = m?.group(1) ?? '';
      if (uri.isEmpty || uri.contains('://') || uri.startsWith('/')) {
        return false;
      }
      continue;
    }
    if (line.startsWith('#')) continue;
    // Media segment: must be a relative local file.
    if (line.contains('://') ||
        line.startsWith('/') ||
        line.contains('/internal/videos/')) {
      return false;
    }
  }
  final hasSegment = content.split('\n').any((l) {
    final t = l.trim();
    return t.isNotEmpty &&
        !t.startsWith('#') &&
        (t.endsWith('.ts') || t.endsWith('.m4s') || t.endsWith('.mp4'));
  });
  return hasSegment;
}