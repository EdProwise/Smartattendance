import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  // static const String baseUrl = 'https://smart-attendance-backend-production-0948.up.railway.app';
  static const String baseUrl = 'http://localhost:8080';

  static final _client = http.Client();

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ─── Schools ──────────────────────────────────────────────────────────────

  static Future<List<School>> getSchools() async {
    final res = await _client.get(Uri.parse('$baseUrl/schools'));
    _check(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => School.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<School> createSchool({
    required String schoolCode,
    required String name,
    String address = '',
    String phone = '',
    String email = '',
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/schools'),
      headers: _headers,
      body: jsonEncode({'schoolCode': schoolCode, 'name': name, 'address': address, 'phone': phone, 'email': email}),
    );
    _check(res);
    return School.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<School> updateSchool(String id, {String? name, String? address, String? phone, String? email}) async {
    final res = await _client.put(
      Uri.parse('$baseUrl/schools/$id'),
      headers: _headers,
      body: jsonEncode({
        if (name != null) 'name': name,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
      }),
    );
    _check(res);
    return School.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> deleteSchool(String id) async {
    final res = await _client.delete(Uri.parse('$baseUrl/schools/$id'));
    _check(res);
  }

  static Future<Map<String, dynamic>> createSchoolAdmin({
    required String schoolId,
    required String loginId,
    required String email,
    required String password,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/schools/$schoolId/admin'),
      headers: _headers,
      body: jsonEncode({'loginId': loginId, 'email': email, 'password': password}),
    );
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ─── Stats ────────────────────────────────────────────────────────────────

  static Future<AttendanceStats> getStats({String? schoolId}) async {
    final uri = schoolId != null
        ? Uri.parse('$baseUrl/attendance/stats?schoolId=$schoolId')
        : Uri.parse('$baseUrl/attendance/stats');
    final res = await _client.get(uri);
    _check(res);
    return AttendanceStats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ─── Employees ────────────────────────────────────────────────────────────

  static Future<List<Employee>> getEmployees({String? schoolId}) async {
    final uri = schoolId != null
        ? Uri.parse('$baseUrl/employees?schoolId=$schoolId')
        : Uri.parse('$baseUrl/employees');
    final res = await _client.get(uri);
    _check(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Employee> createEmployee({
    String? schoolId,
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
        if (schoolId != null) 'schoolId': schoolId,
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

  static Future<Map<String, dynamic>> bulkImportEmployees(
    List<Map<String, dynamic>> employees, {
    String? schoolId,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/employees/bulk'),
      headers: _headers,
      body: jsonEncode({
        'employees': employees,
        if (schoolId != null) 'schoolId': schoolId,
      }),
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

  static Future<Map<String, dynamic>> scanFace(
    String photoBase64, {
    String type = 'checkin',
    String? schoolId,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/attendance/scan'),
      headers: _headers,
      body: jsonEncode({
        'photoBase64': photoBase64,
        'type': type,
        if (schoolId != null) 'schoolId': schoolId,
      }),
    );
    _check(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<AttendanceRecord>> getAttendance({String? date, String? schoolId}) async {
    final params = <String, String>{};
    if (date != null) params['date'] = date;
    if (schoolId != null) params['schoolId'] = schoolId;
    final uri = Uri.parse('$baseUrl/attendance').replace(queryParameters: params.isEmpty ? null : params);
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
