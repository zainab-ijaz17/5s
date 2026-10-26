import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_http_client.dart';
import '../config/api_config.dart';

class ApiService {
  static const String _tokenKey = 'api_access_token';
  static const String _refreshTokenKey = 'api_refresh_token';
  static String get _baseUrl => ApiConfig.baseUrl;

  static const Duration _connectTimeout = Duration(seconds: 45);
  static const Duration _idleTimeout = Duration(seconds: 45);
  static const Duration _uploadIdleTimeout = Duration(minutes: 3);

  static Future<http.Client>? _httpClient;
  static Future<http.Client>? _uploadHttpClient;

  static Future<http.Client> get _client async {
    _httpClient ??= _createPinnedClient(idleTimeout: _idleTimeout);
    return _httpClient!;
  }

  static Future<http.Client> get _uploadClient async {
    _uploadHttpClient ??= _createPinnedClient(idleTimeout: _uploadIdleTimeout);
    return _uploadHttpClient!;
  }

  static Future<http.Client> _createPinnedClient({
    required Duration idleTimeout,
  }) {
    return createApiHttpClient(
      connectTimeout: _connectTimeout,
      idleTimeout: idleTimeout,
    );
  }

  static String? _accessToken;

  static String get baseUrl => _baseUrl;

  static Future<void> setAccessToken(String token) async {
    _accessToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> setRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, token);
  }

  static Future<String?> getAccessToken() async {
    if (_accessToken != null) return _accessToken;
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenKey);
    return _accessToken;
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  static Future<void> clearTokens() async {
    _accessToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  static Future<void> clearAccessToken() async {
    await clearTokens();
  }

  static Future<String?> _getToken() async => getAccessToken();

  static Future<Map<String, String>> _headers({
    bool json = true,
    bool auth = true,
    String? accessToken,
  }) async {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (auth) {
      final token = accessToken ?? await _getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static Uri _uri(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$normalized');
  }

  static String resolveUrl(String urlOrPath) {
    if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
      return urlOrPath;
    }
    final normalized = urlOrPath.startsWith('/') ? urlOrPath : '/$urlOrPath';
    return '$_baseUrl$normalized';
  }

  /// Downloads a remote assessment image (uses auth when required).
  static Future<List<int>> downloadBytes(
    String urlOrPath, {
    bool auth = true,
    String? accessToken,
  }) async {
    return _withNetworkRetry(() async {
      final client = await _client;
      final response = await client.get(
        Uri.parse(resolveUrl(urlOrPath)),
        headers: await _headers(
          auth: auth,
          json: false,
          accessToken: accessToken,
        ),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Download failed (${response.statusCode}) for ${resolveUrl(urlOrPath)}',
        );
      }
      return response.bodyBytes;
    });
  }

  /// Retries once on transient socket drops (common on mobile / Samsung).
  static Future<T> _withNetworkRetry<T>(Future<T> Function() action) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await action();
      } on SocketException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('connection abort') ||
            msg.contains('connection reset') ||
            msg.contains('failed host lookup') ||
            msg.contains('network is unreachable')) {
          lastError = e;
        } else {
          rethrow;
        }
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    }
    throw lastError!;
  }

  static Future<dynamic> get(
    String path, {
    bool auth = true,
    String? accessToken,
    Map<String, String>? queryParameters,
  }) async {
    return _withNetworkRetry(() async {
      final client = await _client;
      final uri = _uri(path);
      final response = await client.get(
        queryParameters == null || queryParameters.isEmpty
            ? uri
            : uri.replace(queryParameters: queryParameters),
        headers: await _headers(auth: auth, accessToken: accessToken),
      );
      return _decode(response);
    });
  }

  static Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
    String? accessToken,
  }) async {
    return _withNetworkRetry(() async {
      final client = await _client;
      final response = await client.post(
        _uri(path),
        headers: await _headers(auth: auth, accessToken: accessToken),
        body: jsonEncode(body),
      );
      return _decode(response);
    });
  }

  static Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
    String? accessToken,
  }) async {
    return _withNetworkRetry(() async {
      final client = await _client;
      final response = await client.patch(
        _uri(path),
        headers: await _headers(auth: auth, accessToken: accessToken),
        body: jsonEncode(body),
      );
      return _decode(response);
    });
  }

  static Future<dynamic> delete(
    String path, {
    bool auth = true,
  }) async {
    return _withNetworkRetry(() async {
      final client = await _client;
      final response =
          await client.delete(_uri(path), headers: await _headers(auth: auth));
      return _decode(response);
    });
  }

  static Future<dynamic> uploadFiles(
    String path,
    List<File> files, {
    String fieldName = 'files',
    Map<String, String>? fields,
    String? accessToken,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    final headers = await _headers(
      json: false,
      auth: true,
      accessToken: accessToken,
    );
    request.headers.addAll(headers);

    if (fields != null) {
      request.fields.addAll(fields);
    }

    for (final file in files) {
      request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));
    }

    final streamed = await _withNetworkRetry(() async {
      final client = await _uploadClient;
      return client.send(request);
    });
    final responseBody = await streamed.stream.bytesToString();
    final response = http.Response(responseBody, streamed.statusCode,
        headers: streamed.headers);
    return _decode(response);
  }

  static dynamic _decode(http.Response response) {
    final raw = response.body.trim();
    final contentType = response.headers['content-type'] ?? '';
    final expectsJson = contentType.contains('application/json');
    dynamic parsed;
    if (raw.isEmpty) {
      parsed = <String, dynamic>{};
    } else if (expectsJson || raw.startsWith('{') || raw.startsWith('[')) {
      try {
        parsed = jsonDecode(raw);
      } on FormatException {
        parsed = {'message': 'Invalid JSON response from server'};
      }
    } else {
      // Non-JSON payloads (commonly HTML error pages from reverse proxies)
      // should not crash decoding.
      parsed = {'message': raw};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final serverMessage = parsed is Map ? parsed['message']?.toString() : null;
      final snippet = raw.length > 180 ? '${raw.substring(0, 180)}...' : raw;
      final message = serverMessage?.isNotEmpty == true
          ? 'Request failed (${response.statusCode}): $serverMessage'
          : 'Request failed (${response.statusCode}): $snippet';
      throw Exception(message);
    }
    return parsed;
  }
}
