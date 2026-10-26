import 'package:flutter/material.dart';

import '../models/skill_matrix_models.dart';
import '../models/skill_rating_level.dart';
import '../services/skill_matrix_api_service.dart';
import '../services/skill_matrix_session_service.dart';
import '../skill_matrix_nav.dart';
import '../theme/skill_matrix_theme.dart';
import '../widgets/skill_matrix_training_requirement_banner.dart';
import '../widgets/skill_matrix_widgets.dart';

class SkillMatrixWorkerGapsScreen extends StatefulWidget {
  const SkillMatrixWorkerGapsScreen({super.key});

  @override
  State<SkillMatrixWorkerGapsScreen> createState() =>
      _SkillMatrixWorkerGapsScreenState();
}

class _SkillMatrixWorkerGapsScreenState extends State<SkillMatrixWorkerGapsScreen> {
  bool _loading = true;
  List<SkillMatrixGapItem> _gaps = [];
  List<SkillMatrixTrainingItem> _trainings = [];
  String _header = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await SkillMatrixSessionService.instance.profile;
      _gaps = await SkillMatrixApiService.instance.fetchMyGaps();
      _trainings = await SkillMatrixApiService.instance.fetchMyTrainings();
      if (profile != null) {
        _header =
            '${profile.fullName} · ${profile.employeeNumber} · '
            '${profile.department ?? ''} · ${profile.levelCode ?? ''}';
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: SkillMatrixTheme.brandPrimary),
      );
    }

    final gaps = _gaps;
    final trainings = _trainings;

    return SkillMatrixPageBackground(
      child: RefreshIndicator(
        onRefresh: _load,
        color: SkillMatrixTheme.brandPrimary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            SkillMatrixHeroHeader(
              title: 'My Gaps & Trainings',
              subtitle: _header.isNotEmpty ? _header : 'Your skill gaps and trainings',
            ),
            const SizedBox(height: 16),
            SkillMatrixStatsGrid(
              tiles: [
                SkillMatrixStatTile(
                  label: 'Open gaps',
                  value: '${gaps.length}',
                  highlight: gaps.isNotEmpty,
                ),
                SkillMatrixStatTile(
                  label: 'Trainings assigned',
                  value: '${trainings.length}',
                ),
              ],
            ),
            const SizedBox(height: 18),
            SkillMatrixSectionCard(
              title: 'Skill gaps',
              subtitle: 'Areas below required proficiency for your level',
              child: gaps.isEmpty
                  ? const Text(
                      'No open gaps — great work.',
                      style: TextStyle(color: SkillMatrixTheme.slate),
                    )
                  : Column(
                      children: [
                        for (final gap in gaps) ...[
                          _GapRow(gap: gap),
                          const Divider(height: 20),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            SkillMatrixSectionCard(
              title: 'Assigned trainings',
              subtitle: 'Development actions from E & T or your line manager',
              child: trainings.isEmpty
                  ? const Text(
                      'No trainings assigned yet.',
                      style: TextStyle(color: SkillMatrixTheme.slate),
                    )
                  : Column(
                      children: [
                        for (final t in trainings) ...[
                          _TrainingRow(
                            item: t,
                            onRateSkill: t.canRateForTraining
                                ? () async {
                                    final ok = await openRateSkillForTraining(
                                      context,
                                      t,
                                    );
                                    if (ok == true && mounted) _load();
                                  }
                                : null,
                          ),
                          const Divider(height: 20),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GapRow extends StatelessWidget {
  const _GapRow({required this.gap});

  final SkillMatrixGapItem gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(gap.skill, style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(gap.category, style: const TextStyle(color: SkillMatrixTheme.slate, fontSize: 12)),
        const SizedBox(height: 6),
        Text(
          'Current ${SkillRatingLevel.displayFor(gap.current)} · '
          'Required ${SkillRatingLevel.displayFor(gap.required)} · '
          'Gap ${gap.gap}',
        ),
        if (gap.assignedTraining != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Training: ${gap.assignedTraining}',
              style: const TextStyle(
                fontSize: 12.5,
                color: SkillMatrixTheme.brandPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _TrainingRow extends StatelessWidget {
  const _TrainingRow({
    required this.item,
    this.onRateSkill,
  });

  final SkillMatrixTrainingItem item;
  final VoidCallback? onRateSkill;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        if (item.linkedGap.isNotEmpty)
          Text('Gap: ${item.linkedGap}', style: const TextStyle(fontSize: 12, color: SkillMatrixTheme.slate)),
        const SizedBox(height: 4),
        Text(
          '${item.status} · Due ${item.dueDate.isEmpty ? '—' : item.dueDate} · ${item.hours}',
          style: const TextStyle(fontSize: 12.5, color: SkillMatrixTheme.slate),
        ),
        Text(
          item.assignedByRole.isNotEmpty
              ? 'Assigned by ${item.assignedBy} (${item.assignedByRole})'
              : 'Assigned by ${item.assignedBy}',
          style: const TextStyle(fontSize: 12, color: SkillMatrixTheme.slate),
        ),
        SkillMatrixTrainingRequirementBanner(item: item),
        if (onRateSkill != null) ...[
          const SizedBox(height: 4),
          const SizedBox(height: 12),
          SkillMatrixPrimaryButton(
            label: item.selfAssessmentPending
                ? 'Complete required self-assessment'
                : 'Update self-assessment for training',
            icon: Icons.add_chart_rounded,
            onPressed: onRateSkill,
          ),
        ] else if (item.hasLinkedSkill && item.status == 'Completed') ...[
          const SizedBox(height: 8),
          Text(
            'Skill rated · training marked complete',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: SkillMatrixTheme.success.withValues(alpha: 0.9),
            ),
          ),
        ],
      ],
    );
  }
}
