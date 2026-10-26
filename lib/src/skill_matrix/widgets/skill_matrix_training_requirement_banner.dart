import 'package:flutter/material.dart';

import '../models/skill_matrix_models.dart';
import '../theme/skill_matrix_theme.dart';

class SkillMatrixTrainingRequirementBanner extends StatelessWidget {
  const SkillMatrixTrainingRequirementBanner({
    super.key,
    required this.item,
  });

  final SkillMatrixTrainingItem item;

  @override
  Widget build(BuildContext context) {
    final message = item.assessmentRequirementMessage;
    if (message.isEmpty) return const SizedBox.shrink();

    final pending = item.selfAssessmentPending;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pending
            ? const Color(0xFFFFF7ED)
            : SkillMatrixTheme.brandTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: pending
              ? SkillMatrixTheme.warningBorder
              : SkillMatrixTheme.brandPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            pending ? Icons.assignment_late_outlined : Icons.check_circle_outline,
            size: 20,
            color: pending ? SkillMatrixTheme.gap : SkillMatrixTheme.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: pending ? SkillMatrixTheme.ink : SkillMatrixTheme.brandDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
