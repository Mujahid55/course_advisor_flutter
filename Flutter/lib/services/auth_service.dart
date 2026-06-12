import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/user.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthService {
  static const _tokenKey = 'jwt_token';
  static const _roleKey = 'user_role';
  static const _fullNameKey = 'full_name';
  static const _emailKey = 'user_email';

  static String get baseUrl => AppConfig.baseUrl;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> login(String email, String password) async {
    final response = await http
        .post(
          Uri.parse('${AuthService.baseUrl}/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 30));

    final body = _decode(response);
    if (response.statusCode != 200) {
      throw AuthException(_extractDetail(body, response.statusCode));
    }

    final prefs = await _prefs;
    await prefs.setString(_tokenKey, body['access_token'] as String);
    await prefs.setString(_roleKey, body['role'] as String);
    await prefs.setString(_fullNameKey, body['full_name'] as String? ?? '');
    await prefs.setString(_emailKey, email);
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    final response = await http
        .post(
          Uri.parse('${AuthService.baseUrl}/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
            'full_name': fullName,
            'role': role,
          }),
        )
        .timeout(const Duration(seconds: 30));

    final body = _decode(response);
    if (response.statusCode != 201) {
      throw AuthException(_extractDetail(body, response.statusCode));
    }

    final prefs = await _prefs;
    await prefs.setString(_tokenKey, body['access_token'] as String);
    await prefs.setString(_roleKey, body['role'] as String);
    await prefs.setString(_fullNameKey, fullName);
    await prefs.setString(_emailKey, email);
  }

  Future<void> logout() async {
    final prefs = await _prefs;
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_fullNameKey);
    await prefs.remove(_emailKey);
  }

  Future<String?> getToken() async {
    final prefs = await _prefs;
    return prefs.getString(_tokenKey);
  }

  Future<String?> getRole() async {
    final prefs = await _prefs;
    return prefs.getString(_roleKey);
  }

  Future<String?> getFullName() async {
    final prefs = await _prefs;
    return prefs.getString(_fullNameKey);
  }

  Future<String?> getEmail() async {
    final prefs = await _prefs;
    return prefs.getString(_emailKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<User?> getCurrentUser() async {
    final token = await getToken();
    if (token == null) return null;

    final response = await http
        .get(
          Uri.parse('${AuthService.baseUrl}/auth/me'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return User.fromJson(_decode(response));
    }
    return null;
  }

  static Map<String, dynamic> _decode(http.Response r) {
    try {
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static String _extractDetail(Map<String, dynamic> body, int code) {
    final detail = body['detail'];
    if (detail is String) return detail;
    if (detail is List) {
      return detail.map((e) => e['msg'] ?? e.toString()).join('; ');
    }
    return 'Request failed (HTTP $code).';
  }
}
