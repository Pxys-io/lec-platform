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
  String? _token;
  void Function()? onUnauthorized;

  String? get token => _token;

  ApiClient({required this.baseUrl});

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
  }) async {
    final uri = _buildUri(path, queryParams: queryParams);
    final headers = _getHeaders();

    _printRequest(method, uri, headers, requestBody);

    http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
      case 'POST':
        response = await http.post(uri, headers: headers, body: requestBody);
      case 'PUT':
        response = await http.put(uri, headers: headers, body: requestBody);
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
      default:
        throw ArgumentError('Unsupported method: $method');
    }

    _printResponse(uri, response);
    return _handleResponse(response);
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

  String _replaceLocalhost(String text) {
    final serverIp = baseUrl.split('://')[1].split('/')[0];
    var result = text.replaceAll('http://localhost:8000', 'http://$serverIp');
    result = result.replaceAll('http://localhost:8001', 'http://$serverIp');
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

    final streamedResponse = await request.send();
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
