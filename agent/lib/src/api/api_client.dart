import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException: $statusCode - $message';
}

class ApiClient {
  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final bool debugLogging;

  String? _token;
  Future<bool>? _refreshFuture;

  /// Called when a 401 is received. Must obtain a fresh access token and
  /// return true so the failed request can be retried once. When it returns
  /// false (or is null), [onUnauthorized] is invoked instead.
  Future<bool> Function()? onRefresh;

  /// Called when authentication can no longer be recovered (refresh failed,
  /// no refresh configured) — e.g. force logout.
  void Function()? onUnauthorized;

  String? get token => _token;

  ApiClient({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 20),
    this.receiveTimeout = const Duration(seconds: 30),
    this.debugLogging = false,
  });

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Uri _buildUri(String path, {Map<String, String>? queryParams}) {
    final uri = Uri.parse('$baseUrl$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  Future<dynamic> _makeRequest(
    String method,
    String path, {
    Map<String, String>? queryParams,
    String? requestBody,
    bool allowRetry = true,
  }) async {
    final uri = _buildUri(path, queryParams: queryParams);
    final headers = _getHeaders();

    if (debugLogging) {
      _printRequest(method, uri, headers, requestBody);
    }

    http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await http
              .get(uri, headers: headers)
              .timeout(receiveTimeout);
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: requestBody)
              .timeout(receiveTimeout);
        case 'PUT':
          response = await http
              .put(uri, headers: headers, body: requestBody)
              .timeout(receiveTimeout);
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers)
              .timeout(receiveTimeout);
        default:
          throw ArgumentError('Unsupported method: $method');
      }
    } on TimeoutException {
      throw ApiException(0, 'Request timed out');
    } on http.ClientException catch (e) {
      throw ApiException(0, 'Network error: ${e.message}');
    }

    if (debugLogging) {
      _printResponse(uri, response);
    }

    if (response.statusCode == 401 && allowRetry && onRefresh != null) {
      final refreshed = await _refreshOnce();
      if (refreshed) {
        return _makeRequest(
          method,
          path,
          queryParams: queryParams,
          requestBody: requestBody,
          allowRetry: false,
        );
      }
    }

    return _handleResponse(response);
  }

  /// Shared in-flight refresh: concurrent 401s await the same refresh instead
  /// of each firing their own (which would race the token rotation).
  Future<bool> _refreshOnce() {
    if (_refreshFuture != null) return _refreshFuture!;
    final completer = Completer<bool>();
    _refreshFuture = completer.future;
    (() async {
      try {
        final ok = await onRefresh?.call() ?? false;
        completer.complete(ok && _token != null);
      } catch (_) {
        completer.complete(false);
      } finally {
        _refreshFuture = null;
      }
    })();
    return _refreshFuture!;
  }

  void _printRequest(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? requestBody,
  ) {
    print('╔══════════════════════════════════════════');
    print('║ 🌐 REQUEST: $method $uri');
    print(
      '║ Headers: ${headers.entries.map((e) => '${e.key}: ${e.value.length > 80 ? '${e.value.substring(0, 80)}...' : e.value}').join(', ')}',
    );
    if (uri.queryParameters.isNotEmpty) {
      print('║ Query params: ${uri.queryParameters}');
    }
    if (requestBody != null) {
      print('║ Body:');
      for (final line in requestBody.split('\n')) {
        print('║   $line');
      }
    }
    print('╚══════════════════════════════════════════');
  }

  void _printResponse(Uri uri, http.Response response) {
    print('╔══════════════════════════════════════════');
    print('║ ✅ RESPONSE: ${response.statusCode} $uri');
    print(
      '║ Headers: ${response.headers.entries.map((e) => '${e.key}: ${e.value}').join(', ')}',
    );
    print('║ Body (${response.body.length} chars):');
    for (final line in response.body.split('\n')) {
      print('║   $line');
    }
    print('╚══════════════════════════════════════════');
  }

  static const _videoServerUrl = String.fromEnvironment(
    'VIDEO_SERVER_URL',
    defaultValue: 'https://video.lec.pxysio.top',
  );

  String _replaceLocalhost(String text) {
    var result = text.replaceAll('http://localhost:8000', baseUrl.replaceAll('/api/v1', ''));
    result = result.replaceAll('http://localhost:8001', _videoServerUrl);
    return result;
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    return _makeRequest('GET', path, queryParams: queryParams);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    return _makeRequest(
      'POST',
      path,
      queryParams: queryParams,
      requestBody: body != null ? jsonEncode(body) : null,
    );
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    return _makeRequest(
      'PUT',
      path,
      queryParams: queryParams,
      requestBody: body != null ? jsonEncode(body) : null,
    );
  }

  Future<dynamic> delete(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    return _makeRequest('DELETE', path, queryParams: queryParams);
  }

  Future<dynamic> upload(String path, String filePath) async {
    final uri = _buildUri(path);
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_getHeaders());
    request.headers.remove('Content-Type');

    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send().timeout(receiveTimeout);
    final response = await http.Response.fromStream(streamedResponse);

    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('application/json')) {
        var data = jsonDecode(response.body);
        data = _replaceLocalhostInJson(data);
        return data;
      }
      return _replaceLocalhost(response.body);
    }

    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }

    String message;
    try {
      final body = jsonDecode(response.body);
      message = body['detail'] ?? 'An error occurred';
    } catch (_) {
      message = response.reasonPhrase ?? 'An error occurred';
    }
    throw ApiException(response.statusCode, message);
  }

  dynamic _replaceLocalhostInJson(dynamic data) {
    if (data is Map) {
      return data.map(
        (key, value) => MapEntry(key, _replaceLocalhostInJson(value)),
      );
    } else if (data is List) {
      return data.map((item) => _replaceLocalhostInJson(item)).toList();
    } else if (data is String) {
      return _replaceLocalhost(data);
    }
    return data;
  }
}