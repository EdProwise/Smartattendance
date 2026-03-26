class Employee {
  final String id;
  final String employeeId;
  final String name;
  final String designation;
  final String grade;
  final String category;
  final String gender;
  final String mobile;
  final String? photoBase64;
  final DateTime? createdAt;

  const Employee({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.designation,
    required this.grade,
    required this.category,
    required this.gender,
    required this.mobile,
    this.photoBase64,
    this.createdAt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: json['id'] as String,
        employeeId: json['employeeId'] as String? ?? '',
        name: json['name'] as String,
        designation: json['designation'] as String? ?? '',
        grade: json['grade'] as String? ?? '',
        category: json['category'] as String? ?? '',
        gender: json['gender'] as String? ?? '',
        mobile: json['mobile'] as String? ?? '',
        photoBase64: json['photoBase64'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  bool get isEnrolled => photoBase64 != null && photoBase64!.isNotEmpty;
}

class AttendanceRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final String department;
  final DateTime timestamp;
  final String status;

  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.timestamp,
    required this.status,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) => AttendanceRecord(
        id: json['id'] as String,
        employeeId: json['employeeId'] as String,
        employeeName: json['employeeName'] as String,
        department: json['department'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        status: json['status'] as String,
      );
}

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
