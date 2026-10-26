import 'package:flutter/material.dart';

import '../../routes.dart';
import 'models/skill_matrix_models.dart';
import 'models/skill_matrix_rate_skill_args.dart';

Future<bool?> openRateSkillForTraining(
  BuildContext context,
  SkillMatrixTrainingItem item,
) {
  if (!item.hasLinkedSkill) return Future.value(null);
  return Navigator.of(context).pushNamed(
    Routes.skillMatrixWorkerRateSkill,
    arguments: SkillMatrixRateSkillArgs(
      skillId: item.skillId,
      skillName: item.linkedGap.isNotEmpty ? item.linkedGap : null,
      categoryName: item.category.isNotEmpty ? item.category : null,
      trainingTitle: item.title,
      assignmentId: item.id,
      requiredLevel: item.requiredLevel,
    ),
  ).then((v) => v == true);
}
