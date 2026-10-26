import 'package:flutter/material.dart';

import '../theme/skill_matrix_theme.dart';
import 'skill_matrix_manager_skill_matrix_panel.dart';

class SkillMatrixManagerSkillMatrixScreen extends StatelessWidget {
  const SkillMatrixManagerSkillMatrixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SkillMatrixTheme.scaffoldTop,
      appBar: AppBar(
        title: const Text('Team skill matrix'),
        backgroundColor: SkillMatrixTheme.brandPrimary,
        foregroundColor: Colors.white,
      ),
      body: const SkillMatrixManagerSkillMatrixPanel(),
    );
  }
}
