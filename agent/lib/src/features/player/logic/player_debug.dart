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