import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path) {
    final base = AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$base$path');
  }

  Future<http.Response> request(
    String method,
    String path, {
    Map<String, String>? headers,
    Object? body,
    int retries = 3,
  }) async {
    Object? lastError;

    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final request = http.Request(method, _uri(path));

        request.headers.addAll({
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          ...?headers,
        });

        if (body != null) {
          request.body = jsonEncode(body);
        }

        final streamed = await _client
            .send(request)
            .timeout(const Duration(seconds: 30));

        final response = await http.Response.fromStream(streamed);

        if (response.statusCode < 500 || attempt == retries) {
          return response;
        }
      } on Object catch (e) {
        lastError = e;
        if (attempt == retries) rethrow;
      }

      await Future<void>.delayed(
        Duration(milliseconds: 500 * (attempt + 1)),
      );
    }

    throw Exception('NETWORK_REQUEST_FAILED: $lastError');
  }

  Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
  }) =>
      request('GET', path, headers: headers);

  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) =>
      request('POST', path, headers: headers, body: body);

  void dispose() {
    _client.close();
  }
}
