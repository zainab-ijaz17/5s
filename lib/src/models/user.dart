class User {
  final String id;
  final String name;
  final String role; // User, PowerUser, Admin, or BUManager
  final String? businessUnit; // For BU Managers to track their specific BU
  final int? employeeId;
  final String? email;

  User({
    required this.id,
    required this.name,
    required this.role,
    this.businessUnit,
    this.employeeId,
    this.email,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'businessUnit': businessUnit,
        'employeeId': employeeId,
        'email': email,
      };

  factory User.fromJson(Map<String, dynamic> json) {
    final employeeIdRaw = json['employeeId'];
    final int? employeeId = employeeIdRaw is int
        ? employeeIdRaw
        : int.tryParse(employeeIdRaw?.toString() ?? '');
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'normal_user',
      businessUnit: json['businessUnit']?.toString() ??
          json['business_unit']?.toString(),
      employeeId: employeeId,
      email: json['email']?.toString(),
    );
  }
}
