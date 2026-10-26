import 'package:flutter/material.dart';

import '../models/skill_rating_level.dart';
import '../models/skill_matrix_rate_skill_args.dart';
import '../services/skill_matrix_api_service.dart';
import '../theme/skill_matrix_theme.dart';
import '../widgets/skill_matrix_widgets.dart';

class SkillMatrixWorkerRateSkillScreen extends StatefulWidget {
  const SkillMatrixWorkerRateSkillScreen({super.key});

  @override
  State<SkillMatrixWorkerRateSkillScreen> createState() =>
      _SkillMatrixWorkerRateSkillScreenState();
}

class _SkillMatrixWorkerRateSkillScreenState
    extends State<SkillMatrixWorkerRateSkillScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _skills = [];
  List<String> _categories = [];
  String? _category;
  String? _skillId;
  int? _rating = 2;
  int _requiredLevel = 3;
  bool _saving = false;
  SkillMatrixRateSkillArgs? _fromTraining;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    _fromTraining = SkillMatrixRateSkillArgs.fromRoute(
      ModalRoute.of(context)?.settings.arguments,
    );
    try {
      _skills = await SkillMatrixApiService.instance.fetchSkillsForMe();
      _categories = await SkillMatrixApiService.instance.fetchCategories();
      if (_categories.isNotEmpty) _category = _categories.first;
      if (_fromTraining?.skillId != null) {
        _applyTrainingSkill(_fromTraining!);
      } else {
        _pickFirstSkillForCategory();
      }
    } catch (_) {
      _categories = ['Troubleshooting'];
      _category = _categories.first;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyTrainingSkill(SkillMatrixRateSkillArgs args) {
    final id = args.skillId;
    if (id == null) return;
    Map<String, dynamic>? match;
    for (final s in _skills) {
      if (s['id']?.toString() == id) {
        match = s;
        break;
      }
    }
    if (match != null) {
      _skillId = id;
      final cat = match['category'];
      if (cat is Map) {
        _category = cat['name']?.toString();
      }
      final reqs = match['requirements'] as List?;
      if (reqs != null && reqs.isNotEmpty) {
        _requiredLevel = (reqs.first['requiredLevel'] as num?)?.toInt() ?? 3;
      }
    } else {
      _skillId = id;
      if (args.categoryName != null) _category = args.categoryName;
    }
    if (args.requiredLevel != null) {
      _requiredLevel = args.requiredLevel!;
    }
  }

  void _pickFirstSkillForCategory() {
    final filtered = _skillsForCategory;
    if (filtered.isEmpty) {
      _skillId = null;
      return;
    }
    _skillId = filtered.first['id']?.toString();
    final reqs = filtered.first['requirements'] as List?;
    if (reqs != null && reqs.isNotEmpty) {
      _requiredLevel = (reqs.first['requiredLevel'] as num?)?.toInt() ?? 3;
    }
  }

  List<Map<String, dynamic>> get _skillsForCategory {
    if (_category == null) return _skills;
    return _skills.where((s) {
      final cat = s['category'];
      final name = cat is Map ? cat['name']?.toString() : '';
      return name == _category;
    }).toList();
  }

  String _skillLabel(Map<String, dynamic> s) => s['name']?.toString() ?? '';

  Future<void> _save() async {
    if (_skillId == null || _rating == null) return;
    setState(() => _saving = true);
    try {
      await SkillMatrixApiService.instance.upsertSelfLine(
        skillId: _skillId!,
        selfRating: _rating!,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Rate a skill'),
          backgroundColor: SkillMatrixTheme.brandPrimary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: SkillMatrixTheme.brandPrimary),
        ),
      );
    }

    final filtered = _skillsForCategory;
    final belowRequired = (_rating ?? 0) < _requiredLevel;

    return Scaffold(
      backgroundColor: SkillMatrixTheme.scaffoldTop,
      appBar: AppBar(
        title: const Text('Rate a skill'),
        backgroundColor: SkillMatrixTheme.brandPrimary,
        foregroundColor: Colors.white,
      ),
      body: SkillMatrixPageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            if (_fromTraining?.trainingTitle != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SkillMatrixTheme.brandTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: SkillMatrixTheme.brandPrimary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.school_outlined,
                      color: SkillMatrixTheme.brandPrimary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Training required: ${_fromTraining!.trainingTitle}\n'
                        'Your line manager assigned this training. Rate '
                        '${_fromTraining!.skillName ?? 'the linked skill'} '
                        'in your self-assessment to record progress.',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: SkillMatrixTheme.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              _fromTraining != null
                  ? 'Confirm or update your proficiency after this training.'
                  : 'Add a competency to your self-assessment. '
                      'Select the skill and rate your current proficiency honestly.',
              style: TextStyle(
                fontSize: 14,
                color: SkillMatrixTheme.slate,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            SkillMatrixSectionCard(
              title: 'Skill details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SkillMatrixFieldLabel('Category'),
                  _dropdown<String>(
                    value: _category,
                    options: _categories,
                    onChanged: (v) => setState(() {
                      _category = v;
                      _pickFirstSkillForCategory();
                    }),
                  ),
                  const SizedBox(height: 16),
                  const SkillMatrixFieldLabel('Skill / competency'),
                  _dropdown<String>(
                    value: _skillId,
                    options: filtered.map((s) => s['id']!.toString()).toList(),
                    labelBuilder: (id) {
                      final s = filtered.firstWhere(
                        (e) => e['id']!.toString() == id,
                        orElse: () => {},
                      );
                      return _skillLabel(s);
                    },
                    onChanged: (v) => setState(() {
                      _skillId = v;
                      final s = filtered.firstWhere(
                        (e) => e['id']!.toString() == v,
                      );
                      final reqs = s['requirements'] as List?;
                      _requiredLevel =
                          (reqs?.first['requiredLevel'] as num?)?.toInt() ?? 3;
                    }),
                  ),
                  const SizedBox(height: 16),
                  const SkillMatrixFieldLabel('Required level for your role'),
                  SkillMatrixReadonlyField(
                    value: SkillRatingLevel.displayFor(_requiredLevel),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SkillMatrixSectionCard(
              title: 'Your proficiency rating',
              subtitle: 'Choose the level that best reflects your ability today.',
              child: Column(
                children: [
                  for (final level
                      in SkillRatingLevel.levels.where((l) => l.value > 0))
                    _RatingTile(
                      level: level,
                      selected: _rating == level.value,
                      onTap: () => setState(() => _rating = level.value),
                      displayLabel: SkillRatingLevel.displayFor(level.value),
                    ),
                ],
              ),
            ),
            if (belowRequired) ...[
              const SizedBox(height: 12),
              Text(
                'This rating is below the required level — a gap may be recorded after manager validation.',
                style: TextStyle(
                  color: SkillMatrixTheme.gap.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving || _skillId == null ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: SkillMatrixTheme.brandPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save to my assessment'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required T? value,
    required List<T> options,
    required ValueChanged<T?> onChanged,
    String Function(T)? labelBuilder,
  }) {
    return DropdownButtonFormField<T>(
      value: options.contains(value) ? value : (options.isNotEmpty ? options.first : null),
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: options
          .map(
            (o) => DropdownMenuItem(
              value: o,
              child: Text(
                labelBuilder != null ? labelBuilder(o) : o.toString(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _RatingTile extends StatelessWidget {
  const _RatingTile({
    required this.level,
    required this.selected,
    required this.onTap,
    required this.displayLabel,
  });

  final SkillRatingLevel level;
  final bool selected;
  final VoidCallback onTap;
  final String displayLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? SkillMatrixTheme.brandTint : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? SkillMatrixTheme.brandPrimary
                    : SkillMatrixTheme.border,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? SkillMatrixTheme.brandPrimary
                              : SkillMatrixTheme.ink,
                        ),
                      ),
                      Text(
                        level.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: SkillMatrixTheme.slate,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, color: SkillMatrixTheme.brandPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
