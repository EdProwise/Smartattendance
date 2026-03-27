// ─── School ───────────────────────────────────────────────────────────────────

class School {
  final String id;
  final String schoolCode;
  final String name;
  final String address;
  final String phone;
  final String email;
  final int employeeCount;
  final DateTime? createdAt;

  const School({
    required this.id,
    required this.schoolCode,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    this.employeeCount = 0,
    this.createdAt,
  });

  factory School.fromJson(Map<String, dynamic> json) => School(
        id: json['id'] as String,
        schoolCode: json['schoolCode'] as String,
        name: json['name'] as String,
        address: json['address'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
        employeeCount: json['employeeCount'] as int? ?? 0,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}

// ─── Employee ─────────────────────────────────────────────────────────────────

class Employee {
  final String id;
  final String? schoolId;
  final String employeeId;
  final String name;
  final String designation;
  final String grade;
  final String category;
  final String gender;
  final String mobile;
  final String? photoBase64;
  final bool isEnrolled;
  final DateTime? createdAt;

  const Employee({
    required this.id,
    this.schoolId,
    required this.employeeId,
    required this.name,
    required this.designation,
    required this.grade,
    required this.category,
    required this.gender,
    required this.mobile,
    this.photoBase64,
    this.isEnrolled = false,
    this.createdAt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: json['id'] as String,
        schoolId: json['schoolId'] as String?,
        employeeId: json['employeeId'] as String? ?? '',
        name: json['name'] as String,
        designation: json['designation'] as String? ?? '',
        grade: json['grade'] as String? ?? '',
        category: json['category'] as String? ?? '',
        gender: json['gender'] as String? ?? '',
        mobile: json['mobile'] as String? ?? '',
        photoBase64: json['photoBase64'] as String?,
        isEnrolled: json['isEnrolled'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}

// ─── AttendanceRecord ─────────────────────────────────────────────────────────

class AttendanceRecord {
  final String id;
  final String? schoolId;
  final String employeeId;
  final String employeeName;
  final String department;
  final DateTime timestamp;
  final String status;
  final String type;

  const AttendanceRecord({
    required this.id,
    this.schoolId,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.timestamp,
    required this.status,
    this.type = 'checkin',
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
        id: json['id'] as String,
        schoolId: json['schoolId'] as String?,
        employeeId: json['employeeId'] as String,
        employeeName: json['employeeName'] as String,
        department: json['department'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        status: json['status'] as String,
        type: json['type'] as String? ?? 'checkin',
      );
}

// ─── AttendanceStats ──────────────────────────────────────────────────────────

class AttendanceStats {
  final int totalEmployees;
  final int enrolledEmployees;
  final int presentToday;
  final int unrecognizedToday;
  final int totalRecords;

  const AttendanceStats({
    required this.totalEmployees,
    required this.enrolledEmployees,
    required this.presentToday,
    required this.unrecognizedToday,
    required this.totalRecords,
  });

  factory AttendanceStats.fromJson(Map<String, dynamic> json) => AttendanceStats(
        totalEmployees: json['totalEmployees'] as int,
        enrolledEmployees: json['enrolledEmployees'] as int,
        presentToday: json['presentToday'] as int,
        unrecognizedToday: json['unrecognizedToday'] as int,
        totalRecords: json['totalRecords'] as int,
      );
}
