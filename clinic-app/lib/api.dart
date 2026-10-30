import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ClinicApi {
  ClinicApi({String? baseUrl})
      : baseUrl = baseUrl ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
                ? 'http://10.0.2.2:8080'
                : 'http://127.0.0.1:8080');

  final String baseUrl;
  String? token;

  Future<Map<String, dynamic>> get(String path, [Map<String, String>? query]) {
    return _send('GET', path, query: query);
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) {
    return _send('POST', path, body: body);
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) {
    return _send('PUT', path, body: body);
  }

  Future<Map<String, dynamic>> delete(String path) {
    return _send('DELETE', path);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json; charset=utf-8';
    if (token != null && token!.isNotEmpty) headers['Authorization'] = 'Bearer $token';

    http.Response response;
    try {
      final encoded = body == null ? null : jsonEncode(body);
      response = await switch (method) {
        'POST' => http.post(uri, headers: headers, body: encoded),
        'PUT' => http.put(uri, headers: headers, body: encoded),
        'DELETE' => http.delete(uri, headers: headers),
        _ => http.get(uri, headers: headers),
      }.timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Không kết nối được máy chủ ClinicCare. Hãy chạy API ở cổng 8080.');
    }

    Map<String, dynamic> data = {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) data = decoded.map((key, value) => MapEntry('$key', value));
    }
    if (response.statusCode >= 400) {
      throw ApiException('${data['message'] ?? 'Yêu cầu không thành công.'}');
    }
    return data;
  }
}
