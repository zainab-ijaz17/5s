class SkillMatrixUserProfile {
  const SkillMatrixUserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.employeeNumber,
    required this.roleName,
    this.department,
    this.areaLine,
    this.designation,
    this.levelCode,
    this.categoryName,
    this.lineManagerName,
    this.photoUrl,
    this.dateOfJoining,
  });

  final String id;
  final String fullName;
  final String email;
  final String employeeNumber;
  final String roleName;
  final String? department;
  final String? areaLine;
  final String? designation;
  final String? levelCode;
  final String? categoryName;
  final String? lineManagerName;
  final String? photoUrl;
  final String? dateOfJoining;

  factory SkillMatrixUserProfile.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    final level = json['level'];
    final category = json['category'];
    final lm = json['lineManager'];
    return SkillMatrixUserProfile(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      employeeNumber: json['employeeNumber']?.toString() ?? '',
      roleName: role is Map ? role['name']?.toString() ?? '' : '',
      department: json['department']?.toString(),
      areaLine: json['areaLine']?.toString(),
      designation: json['designation']?.toString(),
      levelCode: level is Map ? level['code']?.toString() : null,
      categoryName: category is Map ? category['name']?.toString() : null,
      lineManagerName: lm is Map ? lm['fullName']?.toString() : null,
      photoUrl: json['photoUrl']?.toString(),
      dateOfJoining: json['dateOfJoining']?.toString(),
    );
  }
}
