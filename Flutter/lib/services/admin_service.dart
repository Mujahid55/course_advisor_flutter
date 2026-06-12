import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class AdminException implements Exception {
  const AdminException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AdminService {
  static String get _baseUrl => AppConfig.baseUrl;

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response r) {
    try {
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  List<dynamic> _decodeList(http.Response r) {
    try {
      return jsonDecode(r.body) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  void _checkStatus(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      final body = _decode(r);
      final detail = body['detail'];
      final msg = detail is String
          ? detail
          : 'Request failed (${r.statusCode})';
      throw AdminException(msg);
    }
  }

  // ---------------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getUsers({
    int page = 1,
    int limit = 20,
    String? role,
    bool? isBlocked,
    String? search,
  }) async {
    final params = {
      'page': '$page',
      'limit': '$limit',
      if (role != null) 'role': role, // ignore: use_null_aware_elements
      if (isBlocked != null)
        'is_blocked': isBlocked.toString(), // ignore: use_null_aware_elements
      if (search?.isNotEmpty ?? false) 'search': search!,
    };
    final uri = Uri.parse(
      '$_baseUrl/admin/users',
    ).replace(queryParameters: params);
    final r = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 15));
    _checkStatus(r);
    return _decode(r);
  }

  Future<Map<String, dynamic>> getUserDetail(int userId) async {
    final r = await http
        .get(
          Uri.parse('$_baseUrl/admin/users/$userId'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    _checkStatus(r);
    return _decode(r);
  }

  Future<void> updateUserStatus(int userId, bool isActive) async {
    final r = await http
        .patch(
          Uri.parse('$_baseUrl/admin/users/$userId/status'),
          headers: await _authHeaders(),
          body: jsonEncode({'is_active': isActive}),
        )
        .timeout(const Duration(seconds: 15));
    _checkStatus(r);
  }

  Future<void> blockUser(int userId, String reason) async {
    final r = await http
        .post(
          Uri.parse('$_baseUrl/admin/users/$userId/block'),
          headers: await _authHeaders(),
          body: jsonEncode({'reason': reason}),
        )
        .timeout(const Duration(seconds: 15));
    _checkStatus(r);
  }

  Future<void> unblockUser(int userId) async {
    final r = await http
        .post(
          Uri.parse('$_baseUrl/admin/users/$userId/unblock'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    _checkStatus(r);
  }

  Future<void> warnUser(int userId, String message) async {
    final r = await http
        .post(
          Uri.parse('$_baseUrl/admin/users/$userId/warn'),
          headers: await _authHeaders(),
          body: jsonEncode({'message': message}),
        )
        .timeout(const Duration(seconds: 15));
    _checkStatus(r);
  }

  // ---------------------------------------------------------------------------
  // Activity Log
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getActivityLog({
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/admin/activity-log',
    ).replace(queryParameters: {'page': '$page', 'limit': '$limit'});
    final r = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 15));
    _checkStatus(r);
    return _decode(r);
  }

  // ---------------------------------------------------------------------------
  // Analytics
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getOverview() async {
    final r = await http
        .get(
          Uri.parse('$_baseUrl/analytics/overview'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    _checkStatus(r);
    return _decode(r);
  }

  Future<List<dynamic>> getDailyActiveUsers({int days = 30}) async {
    final uri = Uri.parse(
      '$_baseUrl/analytics/daily-active-users',
    ).replace(queryParameters: {'days': '$days'});
    final r = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 15));
    _checkStatus(r);
    return _decodeList(r);
  }

  Future<List<dynamic>> getUsageByHour() async {
    final r = await http
        .get(
          Uri.parse('$_baseUrl/analytics/usage-by-hour'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    _checkStatus(r);
    return _decodeList(r);
  }

  Future<List<dynamic>> getFeatureUsage() async {
    final r = await http
        .get(
          Uri.parse('$_baseUrl/analytics/feature-usage'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    _checkStatus(r);
    return _decodeList(r);
  }

  Future<Map<String, dynamic>> getUsersByRole() async {
    final r = await http
        .get(
          Uri.parse('$_baseUrl/analytics/users-by-role'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    _checkStatus(r);
    return _decode(r);
  }

  Future<List<dynamic>> getTopActiveUsers({int limit = 10}) async {
    final uri = Uri.parse(
      '$_baseUrl/analytics/top-active-users',
    ).replace(queryParameters: {'limit': '$limit'});
    final r = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 15));
    _checkStatus(r);
    return _decodeList(r);
  }

  // ---------------------------------------------------------------------------
  // Warnings (for students/doctors)
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> getMyWarnings() async {
    final r = await http
        .get(
          Uri.parse('$_baseUrl/users/warnings'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 15));
    _checkStatus(r);
    return _decodeList(r);
  }
}
