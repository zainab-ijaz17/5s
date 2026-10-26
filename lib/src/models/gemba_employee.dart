class GembaEmployee {
  final String employeeNumber;
  final String? name;

  const GembaEmployee({
    required this.employeeNumber,
    this.name,
  });

  factory GembaEmployee.fromJson(Map<String, dynamic> json) {
    return GembaEmployee(
      employeeNumber: (json['employeeNumber'] ?? json['userId'] ?? '')
          .toString(),
      name: json['name']?.toString() ?? json['displayName']?.toString(),
    );
  }

  String get label {
    final n = name?.trim();
    if (n == null || n.isEmpty) return employeeNumber;
    return '$employeeNumber  $n';
  }
}
