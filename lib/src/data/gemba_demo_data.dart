import '../models/gemba_employee.dart';

/// Demo-only helpers for Digital Gemba (not backed by SuccessFactors).
class GembaDemoData {
  GembaDemoData._();

  static const GembaEmployee demoEmployee = GembaEmployee(
    employeeNumber: '10009729',
    name: 'Muhammad Anas Babar',
  );

  /// Ensures the demo assignee appears in employee pickers once per list.
  static List<GembaEmployee> withDemoEmployee(List<GembaEmployee> employees) {
    final merged = List<GembaEmployee>.from(employees);
    final hasDemo = merged.any(
      (e) => normalizeEmployeeNumber(e.employeeNumber) ==
          normalizeEmployeeNumber(demoEmployee.employeeNumber),
    );
    if (hasDemo) return merged;

    merged.add(demoEmployee);
    merged.sort((a, b) {
      final nameA = (a.name ?? a.employeeNumber).toLowerCase();
      final nameB = (b.name ?? b.employeeNumber).toLowerCase();
      final byName = nameA.compareTo(nameB);
      if (byName != 0) return byName;
      return a.employeeNumber.compareTo(b.employeeNumber);
    });
    return merged;
  }

  static String normalizeEmployeeNumber(String? value) =>
      (value ?? '').trim();
}
