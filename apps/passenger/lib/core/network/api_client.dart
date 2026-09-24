import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiClient {
  final http.Client _client;
  String? accessToken;

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

  Map<String, String> _authHeaders() {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      return {};
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> register(
    String phone,
    String password,
  ) async {
    final response = await request(
      'POST',
      '/auth/register',
      body: {
        'phone': phone,
        'password': password,
        'role': 'passenger',
      },
    );

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('INVALID_API_RESPONSE');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['error']?.toString() ?? 'ثبت نام ناموفق بود');
    }

    final token = data['accessToken'] ?? data['access_token'];
    if (token is String && token.isNotEmpty) {
      accessToken = token;
    }

    return data;
  }

  Future<Map<String, dynamic>> login(
    String phone,
    String password,
  ) async {
    final response = await request(
      'POST',
      '/auth/login',
      body: {
        'phone': phone,
        'password': password,
      },
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['error']?.toString() ?? 'ورود ناموفق بود',
      );
    }

    final token =
        data['accessToken'] ?? data['access_token'];

    if (token is String && token.isNotEmpty) {
      accessToken = token;
    }

    return data;
  }

  Future<Map<String, dynamic>> me() async {
    return _getJson('/auth/me');
  }

  Future<Map<String, dynamic>> trips() async {
    return _getJson('/passenger/trips');
  }

  Future<Map<String, dynamic>> activeTrip() async {
    return _getJson('/passenger/trips/active');
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await request(
      'GET',
      path,
      headers: _authHeaders(),
    );

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('INVALID_API_RESPONSE');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        decoded['error']?.toString() ?? 'درخواست ناموفق بود',
      );
    }

    return decoded;
  }

  void dispose() {
    _client.close();
  }
}
