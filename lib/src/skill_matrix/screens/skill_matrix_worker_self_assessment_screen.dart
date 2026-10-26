import 'package:flutter/material.dart';

import '../../../routes.dart';
import '../models/skill_matrix_models.dart';
import '../services/skill_matrix_api_service.dart';
import '../skill_matrix_nav.dart';
import '../theme/skill_matrix_theme.dart';
import '../widgets/skill_matrix_assessment_card.dart';
import '../widgets/skill_matrix_training_requirement_banner.dart';
import '../widgets/skill_matrix_widgets.dart';

class SkillMatrixWorkerSelfAssessmentScreen extends StatefulWidget {
  const SkillMatrixWorkerSelfAssessmentScreen({super.key});

  @override
  SkillMatrixWorkerSelfAssessmentScreenState createState() =>
      SkillMatrixWorkerSelfAssessmentScreenState();
}

class SkillMatrixWorkerSelfAssessmentScreenState
    extends State<SkillMatrixWorkerSelfAssessmentScreen> {
  static const _previewCount = 2;

  bool _loading = true;
  String? _error;
  String _cycleLabel = '';
  String _status = 'draft';
  List<SkillMatrixSkillRow> _rows = [];
  List<SkillMatrixSkillRow> _managerRows = [];
  bool _showManagerValidation = false;
  List<SkillMatrixTrainingItem> _trainingToRate = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await SkillMatrixApiService.instance.currentAssessment();
      _cycleLabel = data['cycleLabel']?.toString() ?? _cycleLabel;
      _status = data['status']?.toString() ?? 'draft';
      _rows = await SkillMatrixApiService.instance.fetchCurrentLines();
      final validated =
          await SkillMatrixApiService.instance.fetchValidatedForWorker();
      _showManagerValidation = validated.showManagerView;
      _managerRows = validated.lines;
      final trainings = await SkillMatrixApiService.instance.fetchMyTrainings();
      _trainingToRate =
          trainings.where((t) => t.canRateForTraining).toList();
    } catch (e) {
      _error = e.toString();
      _rows = [];
      _managerRows = [];
      _trainingToRate = [];
      _showManagerValidation = false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveForReview() async {
    try {
      await SkillMatrixApiService.instance.saveAssessmentForReview();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Assessment saved — your line manager can validate your ratings',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _openRateSkill([SkillMatrixTrainingItem? fromTraining]) async {
    if (!_canEditRatings) return;
    if (fromTraining != null) {
      final ok = await openRateSkillForTraining(context, fromTraining);
      if (ok == true && mounted) await _load();
      return;
    }
    final ok =
        await Navigator.of(context).pushNamed(Routes.skillMatrixWorkerRateSkill);
    if (ok == true && mounted) await _load();
  }

  Future<void> _openAllAssessments() async {
    await Navigator.of(context).pushNamed(Routes.skillMatrixWorkerAssessments);
    if (mounted) await _load();
  }

  bool get _canEditRatings =>
      _status == 'draft' || _status == 'submitted';

  bool get _canSaveForReview =>
      _canEditRatings && _rows.isNotEmpty;

  String get _badge {
    return switch (_status) {
      'submitted' => 'Saved · Awaiting manager',
      'reviewed' => 'Reviewed by manager',
      'approved' => 'Validated by manager',
      _ => _rows.isEmpty ? 'Not started' : 'Draft · In progress',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: SkillMatrixTheme.brandPrimary),
      );
    }

    final preview = _rows.take(_previewCount).toList();
    final remaining = _rows.length - preview.length;

    return SkillMatrixPageBackground(
      child: RefreshIndicator(
        color: SkillMatrixTheme.brandPrimary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SkillMatrixEmptyState(
                  title: 'Could not load assessment',
                  message: _error!,
                  icon: Icons.cloud_off_outlined,
                ),
              ),
            SkillMatrixHeroHeader(
              title: 'Self-Assessment',
              subtitle: _cycleLabel,
              badge: _badge,
            ),
            const SizedBox(height: 8),
            Text(
              _canEditRatings
                  ? 'Each skill you rate is saved immediately. When you are '
                      'ready, tap Save assessment so your line manager can validate.'
                  : 'Your assessment has been validated by your line manager.',
              style: const TextStyle(
                fontSize: 13.5,
                color: SkillMatrixTheme.slate,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_trainingToRate.isNotEmpty && _canEditRatings) ...[
              const SizedBox(height: 16),
              SkillMatrixSectionCard(
                title: 'Trainings requiring self-assessment',
                subtitle:
                    'Your line manager assigned these trainings — rate each linked skill',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final t in _trainingToRate) ...[
                      Text(
                        t.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      if (t.linkedGap.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Competency: ${t.linkedGap}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: SkillMatrixTheme.slate,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      SkillMatrixTrainingRequirementBanner(item: t),
                      const SizedBox(height: 10),
                      SkillMatrixPrimaryButton(
                        label: t.selfAssessmentPending
                            ? 'Rate skill for this training'
                            : 'Update rating for this training',
                        icon: Icons.add_chart_rounded,
                        onPressed: () => _openRateSkill(t),
                      ),
                      if (t != _trainingToRate.last) ...[
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ],
                ),
              ),
            ],
            if (_showManagerValidation && _managerRows.isNotEmpty) ...[
              const SizedBox(height: 16),
              SkillMatrixSectionCard(
                title: 'Line manager validation',
                subtitle: 'Validated ratings for this cycle',
                child: Column(
                  children: [
                    for (final row in _managerRows.take(3).toList()) ...[
                      SkillMatrixAssessmentCard(
                        row: row,
                        showManagerRating: true,
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_managerRows.length > 3)
                      TextButton(
                        onPressed: _openAllAssessments,
                        child: Text('View all (${_managerRows.length})'),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_canEditRatings)
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: _openRateSkill,
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          SkillMatrixTheme.brandPrimary.withValues(alpha: 0.08),
                          SkillMatrixTheme.brandTint,
                        ],
                      ),
                      border: Border.all(
                        color: SkillMatrixTheme.brandPrimary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Icon(Icons.add_chart_rounded,
                              color: SkillMatrixTheme.brandPrimary),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Rate a skill',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'My assessment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_rows.length > _previewCount)
                  TextButton(
                    onPressed: _openAllAssessments,
                    child: Text('View all (${_rows.length})'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_rows.isEmpty)
              SkillMatrixEmptyState(
                title: 'No skills rated yet',
                message: _canEditRatings
                    ? 'Rate a skill — it is saved to your assessment right away.'
                    : 'Your assessment has been saved.',
                actionLabel: _canEditRatings ? 'Rate a skill' : null,
                onAction: _canEditRatings ? _openRateSkill : null,
                icon: Icons.add_chart_outlined,
              )
            else ...[
              for (final row in preview) ...[
                SkillMatrixAssessmentCard(row: row),
                const SizedBox(height: 12),
              ],
              if (remaining > 0)
                Text(
                  '+ $remaining more in full list',
                  style: const TextStyle(color: SkillMatrixTheme.slate),
                ),
            ],
            if (_canSaveForReview) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saveForReview,
                style: FilledButton.styleFrom(
                  backgroundColor: SkillMatrixTheme.brandPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _status == 'submitted'
                      ? 'Update saved assessment'
                      : 'Save assessment',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
