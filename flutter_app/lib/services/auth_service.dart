import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthUser {
  final String id;
  final String loginId;
  final String email;
  final String role;       // 'admin' | 'school_admin' | 'user'
  final String? schoolId;

  const AuthUser({
    required this.id,
    required this.loginId,
    required this.email,
    this.role = 'user',
    this.schoolId,
  });

  bool get isSuperAdmin => role == 'admin';
  bool get isSchoolAdmin => role == 'school_admin';
  bool get canManage => role == 'admin' || role == 'school_admin';

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        loginId: json['loginId'] as String,
        email: json['email'] as String,
        role: json['role'] as String? ?? 'user',
        schoolId: json['schoolId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'loginId': loginId,
        'email': email,
        'role': role,
        'schoolId': schoolId,
      };
}

class AuthService {
  static const _userKey = 'auth_user';
  static const _baseUrl = ApiService.baseUrl;
  static final _client = http.Client();

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ─── Password policy ──────────────────────────────────────────────────────

  static String? validatePassword(String password) {
    if (password.length < 8) return 'Password must be at least 8 characters';
    if (!password.contains(RegExp(r'[A-Z]'))) return 'Must contain at least 1 uppercase letter';
    if (!password.contains(RegExp(r'[0-9]'))) return 'Must contain at least 1 number';
    if (!password.contains(RegExp(r'[!@#$%^&*()\-_=+\[\]{};:,./<>?\\|]'))) {
      return 'Must contain at least 1 symbol';
    }
    return null;
  }

  // ─── Session ──────────────────────────────────────────────────────────────

  static Future<AuthUser?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveSession(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  // ─── API calls ────────────────────────────────────────────────────────────

  static Future<AuthUser> login({
    required String loginId,
    required String password,
  }) async {
    final res = await _client.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'loginId': loginId, 'password': password}),
    );
    _check(res);
    final user = AuthUser.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    await _saveSession(user);
    return user;
  }

  static Future<AuthUser> register({
    required String loginId,
    required String email,
    required String password,
    required String schoolName,
    String schoolEmail = '',
  }) async {
    final res = await _client.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'loginId': loginId,
        'email': email,
        'password': password,
        'schoolName': schoolName,
        if (schoolEmail.isNotEmpty) 'schoolEmail': schoolEmail,
      }),
    );
    _check(res);
    final user = AuthUser.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    await _saveSession(user);
    return user;
  }

  static Future<String> forgotPassword(String email) async {
    final res = await _client.post(
      Uri.parse('$_baseUrl/auth/forgot-password'),
      headers: _headers,
      body: jsonEncode({'email': email}),
    );
    _check(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['resetCode'] as String? ?? '';
  }

  static Future<void> resetPassword({
    required String email,
    required String resetCode,
    required String newPassword,
  }) async {
    final res = await _client.post(
      Uri.parse('$_baseUrl/auth/reset-password'),
      headers: _headers,
      body: jsonEncode({'email': email, 'resetCode': resetCode, 'newPassword': newPassword}),
    );
    _check(res);
  }

  // ─── Helper ───────────────────────────────────────────────────────────────

  static void _check(http.Response res) {
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      throw ApiException(body?['error'] as String? ?? 'Request failed (${res.statusCode})');
    }
  }
}
