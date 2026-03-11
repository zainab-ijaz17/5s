class Assessment {
  final String id;
  final String employeeId;
  final String companyId;
  final Map<String, String> answers; // questionId -> answer (Yes/No/NA)
  final Map<String, String> remarks; // questionId -> remark

  Assessment({
    required this.id,
    required this.employeeId,
    required this.companyId,
    required this.answers,
    required this.remarks,
  });
}
