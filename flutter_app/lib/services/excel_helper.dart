import 'package:excel/excel.dart';
import '../models/models.dart';

class ExcelHelper {
  /// Build an Excel workbook from a list of employees and return bytes.
  static List<int> exportEmployees(List<Employee> employees) {
    final excel = Excel.createExcel();
    final sheet = excel['Employees'];

      final headers = [
        'Employee ID', 'Name', 'Designation', 'Grade',
        'Category', 'Gender', 'Mobile', 'Face Enrolled',
      ];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true);
    }

    for (var r = 0; r < employees.length; r++) {
      final e = employees[r];
        final row = [
          e.employeeId, e.name, e.designation, e.grade,
          e.category, e.gender, e.mobile,
          e.isEnrolled ? 'Yes' : 'No',
        ];
      for (var c = 0; c < row.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
          .value = TextCellValue(row[c]);
      }
    }

    return excel.save()!;
  }

  /// Parse Excel bytes into a list of employee maps ready for bulk import.
  static List<Map<String, dynamic>> parseEmployees(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.sheets.values.first;
    final rows = sheet.rows;
    if (rows.isEmpty) return [];

    final headerRow = rows[0]
        .map((c) => c?.value?.toString().trim().toLowerCase() ?? '')
        .toList();

    int col(String name) => headerRow.indexOf(name);

    final employees = <Map<String, dynamic>>[];
    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      String cell(int idx) =>
          idx >= 0 && idx < row.length ? (row[idx]?.value?.toString().trim() ?? '') : '';

        final empId  = cell(col('employee id'));
        final name   = cell(col('name'));
        final mobile = cell(col('mobile'));
        if (empId.isEmpty && name.isEmpty && mobile.isEmpty) continue;

        employees.add({
          'employeeId':  empId.isNotEmpty  ? empId  : 'EMP-$r',
          'name':        name.isNotEmpty   ? name   : 'Unknown',
          'designation': cell(col('designation')),
          'grade':       cell(col('grade')),
          'category':    cell(col('category')),
          'gender':      cell(col('gender')),
          'mobile':      mobile,
        });
    }
    return employees;
  }
}
