import 'package:flutter/material.dart';

import '../../../routes.dart';
import '../theme/skill_matrix_theme.dart';
import 'skill_matrix_manager_assessments_panel.dart';

class SkillMatrixManagerAssessmentsScreen extends StatelessWidget {
  const SkillMatrixManagerAssessmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SkillMatrixTheme.scaffoldTop,
      appBar: AppBar(
        title: const Text('Team assessments'),
        backgroundColor: SkillMatrixTheme.brandPrimary,
        foregroundColor: Colors.white,
      ),
      body: SkillMatrixManagerAssessmentsPanel(
        onReview: (employeeId, userId) {
          Navigator.of(context).pushNamed(
            Routes.skillMatrixManagerReview,
            arguments: {'employeeId': employeeId, 'userId': userId},
          );
        },
      ),
    );
  }
}
