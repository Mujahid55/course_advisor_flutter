import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiService {
  static String get _baseUrl => AppConfig.baseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  static Future<String> uploadSyllabus({
    required String sessionId,
    required PlatformFile platformFile,
  }) async {
    final uri = Uri.parse('$_baseUrl/upload?session_id=$sessionId');
    final request = http.MultipartRequest('POST', uri);

    final authHeaders = await _authHeaders();
    request.headers.addAll(authHeaders);

    if (kIsWeb) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          platformFile.bytes!,
          filename: platformFile.name,
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath('file', platformFile.path!),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);
    return _parseReply(response);
  }

  static Future<String> sendMessage({
    required String sessionId,
    required String message,
  }) async {
    final uri = Uri.parse('$_baseUrl/chat?session_id=$sessionId');
    final authHeaders = await _authHeaders();
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json', ...authHeaders},
          body: jsonEncode({'message': message}),
        )
        .timeout(const Duration(seconds: 45));
    return _parseReply(response);
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  static String _parseReply(http.Response response) {
    final body = _decodeBody(response);

    if (response.statusCode == 200) {
      final reply = body['reply'];
      if (reply is String) return reply;
      throw const ApiException('Unexpected response format from server.');
    }

    final detail = body['detail'];
    final message = detail is String
        ? detail
        : detail is List
        ? detail.map((e) => e['msg'] ?? e.toString()).join('; ')
        : 'Request failed (HTTP ${response.statusCode}).';

    throw ApiException(message);
  }

  static Map<String, dynamic> _decodeBody(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw ApiException(
        'Could not parse server response (HTTP ${response.statusCode}).',
      );
    }
  }
}
