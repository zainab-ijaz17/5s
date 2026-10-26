class SkillMatrixEmployeeSummary {
  const SkillMatrixEmployeeSummary({
    required this.id,
    required this.name,
    required this.department,
    required this.level,
    required this.assessmentStatus,
    required this.overallScore,
    required this.openGaps,
    required this.awaitingReview,
    this.userId = '',
  });

  final String id;
  final String userId;
  final String name;
  final String department;
  final String level;
  final String assessmentStatus;
  final double? overallScore;
  final int openGaps;
  final bool awaitingReview;
}

class SkillMatrixSkillRow {
  const SkillMatrixSkillRow({
    required this.id,
    required this.category,
    required this.skill,
    required this.requiredLevel,
    this.skillId,
    this.selfRating,
    this.managerRating,
    this.workerComment,
    this.managerComment,
  });

  final String id;
  final String? skillId;
  final String category;
  final String skill;
  final int requiredLevel;
  final int? selfRating;
  final int? managerRating;
  final String? workerComment;
  final String? managerComment;

  int? get validatedRating => managerRating ?? selfRating;

  int get gap {
    final r = validatedRating;
    if (r == null) return requiredLevel;
    return (requiredLevel - r).clamp(0, 99);
  }

  bool get hasGap => gap > 0;
}

class SkillMatrixGapItem {
  const SkillMatrixGapItem({
    required this.category,
    required this.skill,
    required this.current,
    required this.required,
    required this.assignedTraining,
  });

  final String category;
  final String skill;
  final int current;
  final int required;
  final String? assignedTraining;

  int get gap => required - current;
}

class SkillMatrixTrainingItem {
  const SkillMatrixTrainingItem({
    required this.title,
    required this.category,
    required this.linkedGap,
    required this.assignedBy,
    required this.dueDate,
    required this.status,
    required this.hours,
    this.id,
    this.skillId,
    this.requiredLevel,
    this.assignedByRole = '',
    this.requiresSelfAssessment = false,
    this.canRateForTraining = false,
    this.selfAssessmentPending = false,
  });

  final String? id;
  final String? skillId;
  final int? requiredLevel;
  final String title;
  final String category;
  final String linkedGap;
  final String assignedBy;
  final String assignedByRole;
  final String dueDate;
  final String status;
  final String hours;
  final bool requiresSelfAssessment;
  final bool canRateForTraining;
  final bool selfAssessmentPending;

  bool get hasLinkedSkill => skillId != null && skillId!.isNotEmpty;

  String get assessmentRequirementMessage {
    if (!canRateForTraining || !hasLinkedSkill) {
      if (hasLinkedSkill && status == 'Completed') {
        return 'Training completed — self-assessment was recorded for this skill.';
      }
      if (hasLinkedSkill && status == 'Scheduled' && !canRateForTraining) {
        return 'Link this training to a skill from your line manager to enable assessment.';
      }
      return '';
    }
    final skill = linkedGap.isNotEmpty ? linkedGap : 'the linked skill';
    if (selfAssessmentPending) {
      return 'Training required: complete self-assessment for $skill '
          'to progress this assignment.';
    }
    return 'Training in progress: you can update your self-assessment for $skill '
        'any time while this assignment is open.';
  }
}
