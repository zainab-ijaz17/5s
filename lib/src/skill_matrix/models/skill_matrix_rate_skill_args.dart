class SkillMatrixRateSkillArgs {
  const SkillMatrixRateSkillArgs({
    this.skillId,
    this.skillName,
    this.categoryName,
    this.trainingTitle,
    this.assignmentId,
    this.requiredLevel,
  });

  final String? skillId;
  final String? skillName;
  final String? categoryName;
  final String? trainingTitle;
  final String? assignmentId;
  final int? requiredLevel;

  static SkillMatrixRateSkillArgs? fromRoute(Object? arguments) {
    if (arguments is SkillMatrixRateSkillArgs) return arguments;
    if (arguments is Map) {
      return SkillMatrixRateSkillArgs(
        skillId: arguments['skillId']?.toString(),
        skillName: arguments['skillName']?.toString(),
        categoryName: arguments['categoryName']?.toString(),
        trainingTitle: arguments['trainingTitle']?.toString(),
        assignmentId: arguments['assignmentId']?.toString(),
        requiredLevel: (arguments['requiredLevel'] as num?)?.toInt(),
      );
    }
    return null;
  }
}
