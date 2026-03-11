class User {
  final String id;
  final String name;
  final String role; // User, PowerUser, Admin, or BUManager
  final String? businessUnit; // For BU Managers to track their specific BU

  User({
    required this.id, 
    required this.name, 
    required this.role,
    this.businessUnit,
  });
}
