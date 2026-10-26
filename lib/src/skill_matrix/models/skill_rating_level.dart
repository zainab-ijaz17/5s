class SkillRatingLevel {
  const SkillRatingLevel({
    required this.value,
    required this.title,
    required this.description,
  });

  final int value;
  final String title;
  final String description;

  static const levels = [
    SkillRatingLevel(
      value: 0,
      title: 'Not assessed',
      description: 'No rating recorded yet',
    ),
    SkillRatingLevel(
      value: 1,
      title: 'Aware',
      description: 'Limited knowledge',
    ),
    SkillRatingLevel(
      value: 2,
      title: 'Needs supervision',
      description: 'Can perform with guidance',
    ),
    SkillRatingLevel(
      value: 3,
      title: 'Competent',
      description: 'Works independently',
    ),
    SkillRatingLevel(
      value: 4,
      title: 'Proficient',
      description: 'Can train others',
    ),
    SkillRatingLevel(
      value: 5,
      title: 'Expert',
      description: 'Subject matter expert',
    ),
  ];

  static SkillRatingLevel? byValue(int? value) {
    if (value == null) return null;
    for (final level in levels) {
      if (level.value == value) return level;
    }
    return null;
  }

  /// Title only, e.g. "Competent".
  static String labelFor(int? value) =>
      byValue(value)?.title ?? (value == null ? '—' : '$value');

  /// Same format as the worker "Rate a skill" screen: "3 — Competent".
  static String displayFor(int? value) {
    if (value == null) return '—';
    final level = byValue(value);
    if (level == null || level.value == 0) return labelFor(value);
    return '${level.value} — ${level.title}';
  }

  static String descriptionFor(int? value) =>
      byValue(value)?.description ?? '';
}
