enum SkillMatrixRole {
  worker,
  lineManager,
  etAdmin;

  String get label => switch (this) {
        SkillMatrixRole.worker => 'Worker',
        SkillMatrixRole.lineManager => 'Line Manager',
        SkillMatrixRole.etAdmin => 'E & T Admin',
      };

  String get subtitle => switch (this) {
        SkillMatrixRole.worker =>
          'Self-assessment, skill gaps, and assigned trainings',
        SkillMatrixRole.lineManager =>
          'Team skill overview, reviews, and training assignment',
        SkillMatrixRole.etAdmin =>
          'Assign trainings, manage skills catalog, and user setup',
      };

  static SkillMatrixRole? fromApiName(String name) => switch (name.trim()) {
        'Worker' => SkillMatrixRole.worker,
        'Line Manager' => SkillMatrixRole.lineManager,
        'E & T Admin' => SkillMatrixRole.etAdmin,
        _ => null,
      };
}
