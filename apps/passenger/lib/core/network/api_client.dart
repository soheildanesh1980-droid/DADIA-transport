import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiClient {
  final http.Client _client;
  String? accessToken;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path) {
    final base =
        AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/$'), '');
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

        final response =
            await http.Response.fromStream(streamed);

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

    throw Exception(
      'NETWORK_REQUEST_FAILED: $lastError',
    );
  }

  Map<String, String> _authHeaders() {
    final token = accessToken;

    if (token == null || token.isEmpty) {
      return {};
    }

    return {
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('INVALID_API_RESPONSE');
      }

      return decoded;
    } catch (_) {
      throw Exception(
        'INVALID_API_RESPONSE:${response.statusCode}',
      );
    }
  }

  void _throwIfFailed(
    http.Response response,
    Map<String, dynamic> data,
    String fallback,
  ) {
    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        data['error']?.toString() ?? fallback,
      );
    }
  }

  Future<Map<String, dynamic>> requestRegisterOtp(
    String phone, {
    String locale = 'fa',
  }) async {
    final response = await request(
      'POST',
      '/auth/register/request-otp',
      body: {
        'phone': phone,
        'role': 'passenger',
        'locale': locale,
      },
    );

    final data = _decode(response);

    _throwIfFailed(
      response,
      data,
      'ارسال کد تایید ناموفق بود',
    );

    return data;
  }

  Future<Map<String, dynamic>> verifyRegisterOtp(
    String phone,
    String code,
  ) async {
    final response = await request(
      'POST',
      '/auth/register/verify-otp',
      body: {
        'phone': phone,
        'code': code,
      },
    );

    final data = _decode(response);

    _throwIfFailed(
      response,
      data,
      'کد تایید نامعتبر است',
    );

    return data;
  }

  Future<Map<String, dynamic>> completeRegister(
    String verificationToken,
  ) async {
    final response = await request(
      'POST',
      '/auth/register/complete-otp',
      body: {
        'verificationToken': verificationToken,
      },
    );

    final data = _decode(response);

    _throwIfFailed(
      response,
      data,
      'تکمیل ثبت نام ناموفق بود',
    );

    final token =
        data['accessToken'] ?? data['access_token'];

    if (token is String && token.isNotEmpty) {
      accessToken = token;
    }

    return data;
  }

  Future<Map<String, dynamic>> requestLoginOtp(
    String phone, {
    String locale = 'fa',
  }) async {
    final response = await request(
      'POST',
      '/auth/login/request-otp',
      body: {
        'phone': phone,
        'locale': locale,
      },
    );

    final data = _decode(response);

    _throwIfFailed(
      response,
      data,
      'ارسال کد ورود ناموفق بود',
    );

    return data;
  }

  Future<Map<String, dynamic>> verifyLoginOtp(
    String phone,
    String code,
  ) async {
    final response = await request(
      'POST',
      '/auth/login/verify-otp',
      body: {
        'phone': phone,
        'code': code,
      },
    );

    final data = _decode(response);

    _throwIfFailed(
      response,
      data,
      'کد ورود نامعتبر است',
    );

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

  Future<Map<String, dynamic>> _getJson(
    String path,
  ) async {
    final response = await request(
      'GET',
      path,
      headers: _authHeaders(),
    );

    final decoded = _decode(response);

    _throwIfFailed(
      response,
      decoded,
      'درخواست ناموفق بود',
    );

    return decoded;
  }

  void dispose() {
    _client.close();
  }
}
