class GembaUser {
  final String email;
  final String name;
  final String? costCenter;
  final String? companyName;
  final String employeeNumber;
  final String role;

  const GembaUser({
    required this.email,
    required this.name,
    required this.employeeNumber,
    this.costCenter,
    this.companyName,
    this.role = 'user',
  });

  bool get isAdmin => role.toLowerCase() == 'admin';

  factory GembaUser.fromJson(Map<String, dynamic> json) {
    final rawRole = (json['role'] ?? 'user').toString().toLowerCase();
    final isAdminFlag = json['isAdmin'] == true;
    final role = isAdminFlag || rawRole == 'admin' ? 'admin' : 'user';
    return GembaUser(
      email: (json['email'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      costCenter: json['costCenter']?.toString(),
      companyName: json['companyName']?.toString(),
      employeeNumber: (json['employeeNumber'] ?? '').toString(),
      role: role,
    );
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        'name': name,
        'costCenter': costCenter,
        'companyName': companyName,
        'employeeNumber': employeeNumber,
        'role': role,
        'isAdmin': isAdmin,
      };
}
