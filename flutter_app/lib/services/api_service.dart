import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  // Change this to your backend URL (ngrok URL or local IP for device testing)
  static const String baseUrl = 'http://localhost:8080';

  static final _client = http.Client();

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ─── Stats ────────────────────────────────────────────────────────────────

  static Future<AttendanceStats> getStats() async {
    final res = await _client.get(Uri.parse('$baseUrl/attendance/stats'));
    _check(res);
    return AttendanceStats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ─── Employees ────────────────────────────────────────────────────────────

  static Future<List<Employee>> getEmployees() async {
    final res = await _client.get(Uri.parse('$baseUrl/employees'));
    _check(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Employee> createEmployee({
    required String employeeId,
    required String name,
    required String designation,
    required String grade,
    required String category,
    required String gender,
    required String mobile,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/employees'),
      headers: _headers,
      body: jsonEncode({
        'employeeId': employeeId,
        'name': name,
        'designation': designation,
        'grade': grade,
        'category': category,
        'gender': gender,
        'mobile': mobile,
      }),
    );
    _check(res);
    return Employee.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> bulkImportEmployees(List<Map<String, dynamic>> employees) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/employees/bulk'),
      headers: _headers,
      body: jsonEncode({'employees': employees}),
    );
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> deleteEmployee(String id) async {
    final res = await _client.delete(Uri.parse('$baseUrl/employees/$id'));
    _check(res);
  }

  static Future<void> enrollFace({
    required String employeeId,
    required String photoBase64,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/employees/$employeeId/enroll'),
      headers: _headers,
      body: jsonEncode({'photoBase64': photoBase64}),
    );
    _check(res);
  }

  // ─── Attendance ───────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> scanFace(String photoBase64) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/attendance/scan'),
      headers: _headers,
      body: jsonEncode({'photoBase64': photoBase64}),
    );
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<AttendanceRecord>> getAttendance({String? date}) async {
    final uri = date != null
        ? Uri.parse('$baseUrl/attendance?date=$date')
        : Uri.parse('$baseUrl/attendance');
    final res = await _client.get(uri);
    _check(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static void _check(http.Response res) {
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      throw ApiException(body?['error'] as String? ?? 'Request failed (${res.statusCode})');
    }
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}
