import 'package:flutter/material.dart';

import '../models/skill_matrix_models.dart';
import '../models/skill_rating_level.dart';
import '../theme/skill_matrix_theme.dart';
import '../widgets/skill_matrix_widgets.dart';

import '../services/skill_matrix_api_service.dart';

class SkillMatrixManagerReviewScreen extends StatefulWidget {
  const SkillMatrixManagerReviewScreen({
    super.key,
    required this.employeeId,
    this.workerUserId = '',
  });

  final String employeeId;
  final String workerUserId;

  @override
  State<SkillMatrixManagerReviewScreen> createState() =>
      _SkillMatrixManagerReviewScreenState();
}

class _SkillMatrixManagerReviewScreenState
    extends State<SkillMatrixManagerReviewScreen> {
  late List<SkillMatrixSkillRow> _rows;
  SkillMatrixEmployeeSummary? _employee;
  List<Map<String, dynamic>> _trainingCatalog = [];
  String? _assignTrainingId;
  String? _assignSkillId;
  String _assignPriority = 'High (gap ≥ 1)';
  String _assignDue = '';
  String _workerUserId = '';
  String _assessmentId = '';
  String _assessmentStatus = 'draft';
  String _cycleLabel = '';
  String? _loadError;
  bool _loading = true;
  bool _assigning = false;
  bool _saving = false;
  bool _managerRatingChosen = false;

  @override
  void initState() {
    super.initState();
    _rows = [];
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    _workerUserId = widget.workerUserId;
    try {
      final team = await SkillMatrixApiService.instance.fetchManagerTeam();
      for (final m in team) {
        if (m.id == widget.employeeId ||
            (widget.workerUserId.isNotEmpty && m.userId == widget.workerUserId)) {
          _employee = m;
          if (m.userId.isNotEmpty) {
            _workerUserId = m.userId;
          } else if (_workerUserId.isEmpty) {
            _workerUserId = m.id;
          }
          break;
        }
      }

      if (_workerUserId.isEmpty) {
        _loadError = 'Select an employee from your team to review.';
        _assessmentId = '';
        _rows = [];
      } else {
        final view = await SkillMatrixApiService.instance
            .fetchManagerAssessment(_workerUserId);
        _assessmentId = view.assessmentId;
        _assessmentStatus = view.status;
        _cycleLabel = view.cycleLabel;
        _managerRatingChosen = view.lines.any((r) => r.managerRating != null);
        _rows = view.lines
            .map(
              (r) => SkillMatrixSkillRow(
                id: r.id,
                skillId: r.skillId,
                category: r.category,
                skill: r.skill,
                requiredLevel: r.requiredLevel,
                selfRating: r.selfRating,
                managerRating: r.managerRating,
                workerComment: r.workerComment,
                managerComment: r.managerComment,
              ),
            )
            .toList();
        final skillRows = _rows
            .where((r) => r.skillId != null && r.skillId!.isNotEmpty)
            .toList();
        if (skillRows.isNotEmpty) {
          final gapFirst = skillRows.where((r) => r.hasGap).toList();
          _assignSkillId ??=
              (gapFirst.isNotEmpty ? gapFirst.first : skillRows.first).skillId;
        }
      }

      try {
        _trainingCatalog =
            await SkillMatrixApiService.instance.fetchTrainingCatalog();
        if (_trainingCatalog.isNotEmpty) {
          _assignTrainingId ??= _trainingCatalog.first['id']?.toString();
        }
      } catch (_) {
        _trainingCatalog = [];
      }
    } catch (e) {
      _loadError = e.toString();
      _assessmentId = '';
      _rows = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assignTraining() async {
    if (_workerUserId.isEmpty ||
        _assignTrainingId == null ||
        _assignTrainingId!.isEmpty) {
      return;
    }
    setState(() => _assigning = true);
    try {
      await SkillMatrixApiService.instance.assignTrainingToWorker(
        workerId: _workerUserId,
        trainingId: _assignTrainingId!,
        skillId: _assignSkillId,
        dueDate: _assignDue.trim().isEmpty ? null : _assignDue.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Training assigned to employee')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  List<SkillMatrixSkillRow> get _skillRowsForAssign => _rows
      .where((r) => r.skillId != null && r.skillId!.isNotEmpty)
      .toList();

  bool get _workerReadyForReview {
    final workerSavedSkills = _rows.any((r) => r.selfRating != null);
    return workerSavedSkills ||
        _assessmentStatus == 'submitted' ||
        _assessmentStatus == 'reviewed';
  }

  bool get _canSaveManagerRatings => _workerReadyForReview;

  bool get _managerRatingReady =>
      _managerRatingChosen || _rows.any((r) => r.managerRating != null);

  List<SkillMatrixSkillRow> get _linesToValidate => _rows
      .where((r) => r.managerRating != null || r.selfRating != null)
      .toList();

  bool get _canPressSave =>
      !_loading && !_saving && _assessmentId.isNotEmpty && _rows.isNotEmpty;

  String? get _saveHint {
    if (_loading) return null;
    if (_assessmentId.isEmpty) {
      return 'Assessment did not load. Pull down to refresh.';
    }
    if (_rows.isEmpty) {
      return 'No skills on this assessment yet.';
    }
    if (!_workerReadyForReview) {
      return 'Worker has not saved any skill ratings yet.';
    }
    if (_linesToValidate.isEmpty) {
      return 'No ratings to validate on these skills.';
    }
    return null;
  }

  Future<void> _persistManagerRatings() async {
    if (_assessmentId.isEmpty) {
      throw Exception('No assessment loaded for this employee');
    }
    if (!_canSaveManagerRatings) {
      throw Exception(
        'Worker must rate at least one skill (Save assessment) before you can validate',
      );
    }
    final toSave = _linesToValidate;
    if (toSave.isEmpty) {
      throw Exception('No worker skill ratings to validate yet');
    }
    final lines = toSave
        .map(
          (r) => {
            'lineId': r.id,
            'managerRating': r.managerRating ?? r.selfRating!,
            if (r.managerComment != null && r.managerComment!.isNotEmpty)
              'managerComment': r.managerComment,
          },
        )
        .toList();
    await SkillMatrixApiService.instance.saveManagerLines(
      assessmentId: _assessmentId,
      lines: lines,
    );
  }

  Future<void> _save() async {
    if (!_canPressSave) return;
    setState(() => _saving = true);
    try {
      await _persistManagerRatings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Assessment saved — worker can see your validated ratings',
          ),
        ),
      );
      Navigator.of(context).pop();
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
          title: const Text('Review Assessment'),
          backgroundColor: SkillMatrixTheme.brandPrimary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: SkillMatrixTheme.brandPrimary),
        ),
      );
    }

    if (_loadError != null && _rows.isEmpty && _workerUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Review Assessment'),
          backgroundColor: SkillMatrixTheme.brandPrimary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SkillMatrixTheme.slate),
            ),
          ),
        ),
      );
    }

    final employee = _employee;
    final name = employee?.name.isNotEmpty == true
        ? employee!.name
        : widget.employeeId;

    return Scaffold(
      backgroundColor: SkillMatrixTheme.scaffoldTop,
      appBar: AppBar(
        title: const Text('Review Assessment'),
        backgroundColor: SkillMatrixTheme.brandPrimary,
        foregroundColor: Colors.white,
      ),
      body: SkillMatrixPageBackground(
        child: RefreshIndicator(
          color: SkillMatrixTheme.brandPrimary,
          onRefresh: _load,
          child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            if (_loadError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _loadError!,
                  style: const TextStyle(
                    color: SkillMatrixTheme.gap,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            SkillMatrixHeroHeader(
              title: 'Review Assessment',
              subtitle: _cycleLabel.isNotEmpty
                  ? '$_cycleLabel · $name'
                  : name,
              badge: _assessmentStatusLabel,
            ),
            if (!_workerReadyForReview && _rows.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SkillMatrixTheme.warningBorder),
                ),
                child: const Text(
                  'Waiting for the worker to rate and save at least one skill.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: SkillMatrixTheme.ink,
                  ),
                ),
              ),
            ] else if (_assessmentStatus == 'draft' &&
                _workerReadyForReview) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SkillMatrixTheme.brandTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: SkillMatrixTheme.brandPrimary.withValues(alpha: 0.25),
                  ),
                ),
                child: const Text(
                  'Worker has saved skill ratings. Adjust manager ratings if '
                  'needed, then tap Save (self ratings are used where you '
                  'have not changed them).',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: SkillMatrixTheme.brandDark,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SkillMatrixSectionCard(
              title: 'Employee',
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = (constraints.maxWidth - 14) / 2;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _field('Employee', name, w),
                      _field('Employee ID', widget.employeeId, w),
                      _field('Department', employee?.department ?? '—', w),
                      _field('Level', employee?.level ?? '—', w),
                      _field(
                        'Assessment status',
                        employee?.assessmentStatus ?? '—',
                        w,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SkillMatrixSectionCard(
              title: 'Validate ratings',
              subtitle:
                  'Manager-validated rating — rows below requirement are highlighted',
              child: Column(
                children: [
                  for (final row in _rows) ...[
                    _ReviewRowCard(
                      row: row,
                      onManagerRating: (v) {
                        setState(() {
                          _managerRatingChosen = true;
                          final i = _rows.indexWhere((r) => r.id == row.id);
                          if (i < 0) return;
                          final old = _rows[i];
                          _rows[i] = SkillMatrixSkillRow(
                            id: old.id,
                            skillId: old.skillId,
                            category: old.category,
                            skill: old.skill,
                            requiredLevel: old.requiredLevel,
                            selfRating: old.selfRating,
                            managerRating: v,
                            workerComment: old.workerComment,
                            managerComment: old.managerComment,
                          );
                        });
                      },
                      onManagerComment: (comment) {
                        setState(() {
                          final i = _rows.indexWhere((r) => r.id == row.id);
                          if (i < 0) return;
                          final old = _rows[i];
                          _rows[i] = SkillMatrixSkillRow(
                            id: old.id,
                            skillId: old.skillId,
                            category: old.category,
                            skill: old.skill,
                            requiredLevel: old.requiredLevel,
                            selfRating: old.selfRating,
                            managerRating: old.managerRating,
                            workerComment: old.workerComment,
                            managerComment: comment,
                          );
                        });
                      },
                    ),
                    if (row != _rows.last) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SkillMatrixSectionCard(
              title: 'Assign training (optional)',
              subtitle:
                  'Only needed where there is a skill gap — on-target skills need no training',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SkillMatrixFieldLabel('Priority'),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _assignPriority,
                    decoration: _decoration(),
                    items: const [
                      DropdownMenuItem(
                        value: 'High (gap ≥ 1)',
                        child: Text('High (gap ≥ 1)'),
                      ),
                      DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'Low', child: Text('Low')),
                    ],
                    onChanged: (v) => setState(() => _assignPriority = v!),
                  ),
                  const SizedBox(height: 14),
                  if (_skillRowsForAssign.isNotEmpty) ...[
                    const SkillMatrixFieldLabel('Linked skill (optional)'),
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
                      value: _assignSkillId,
                      decoration: _decoration(),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No linked skill'),
                        ),
                        for (final r in _skillRowsForAssign)
                          DropdownMenuItem(
                            value: r.skillId,
                            child: Text(r.skill, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setState(() => _assignSkillId = v),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const SkillMatrixFieldLabel('Training (from catalog)'),
                  if (_trainingCatalog.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'No trainings in catalog yet. E & T can add courses.',
                        style: TextStyle(color: SkillMatrixTheme.slate, fontSize: 13),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _assignTrainingId,
                      decoration: _decoration(),
                      items: [
                        for (final t in _trainingCatalog)
                          DropdownMenuItem(
                            value: t['id']?.toString(),
                            child: Text(
                              t['name']?.toString() ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _assignTrainingId = v),
                    ),
                  const SizedBox(height: 14),
                  const SkillMatrixFieldLabel('Target date (YYYY-MM-DD)'),
                  TextFormField(
                    decoration: _decoration().copyWith(
                      hintText: 'Optional',
                    ),
                    onChanged: (v) => _assignDue = v,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _trainingCatalog.isEmpty ||
                            _assigning ||
                            _assignTrainingId == null ||
                            _assignTrainingId!.isEmpty
                        ? null
                        : _assignTraining,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Assign training'),
                    style: FilledButton.styleFrom(
                      backgroundColor: SkillMatrixTheme.brandPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _canPressSave ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: SkillMatrixTheme.brandPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save validation',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
            ),
            if (_saveHint != null) ...[
              const SizedBox(height: 10),
              Text(
                _saveHint!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: SkillMatrixTheme.slate,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }

  Widget _field(String label, String value, double width) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkillMatrixFieldLabel(label),
          SkillMatrixReadonlyField(value: value),
        ],
      ),
    );
  }

  InputDecoration _decoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: SkillMatrixTheme.border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  String get _assessmentStatusLabel {
    if (_assessmentStatus == 'draft' && _workerReadyForReview) {
      return 'Worker saved · Ready to validate';
    }
    return switch (_assessmentStatus) {
      'submitted' => 'Submitted · Awaiting review',
      'reviewed' => 'Reviewed',
      'approved' => 'Approved',
      'draft' => 'Draft · Not started',
      _ => _assessmentStatus,
    };
  }
}

class _ReviewRowCard extends StatelessWidget {
  const _ReviewRowCard({
    required this.row,
    required this.onManagerRating,
    required this.onManagerComment,
  });

  final SkillMatrixSkillRow row;
  final ValueChanged<int?> onManagerRating;
  final ValueChanged<String> onManagerComment;

  @override
  Widget build(BuildContext context) {
    final gap = row.requiredLevel - (row.managerRating ?? row.selfRating ?? 0);
    final highlight = gap > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? SkillMatrixTheme.warningBorder : SkillMatrixTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.category,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: SkillMatrixTheme.slate,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            row.skill,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 340;
              final managerRating = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SkillMatrixFieldLabel('Manager rating'),
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    value: row.managerRating,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      hintText: row.selfRating != null
                          ? 'Select · self ${SkillRatingLevel.displayFor(row.selfRating)}'
                          : 'Select manager rating',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: SkillMatrixTheme.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      for (final l
                          in SkillRatingLevel.levels.where((e) => e.value > 0))
                        DropdownMenuItem(
                          value: l.value,
                          child: Text(
                            SkillRatingLevel.displayFor(l.value),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) onManagerRating(v);
                    },
                  ),
                ],
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _stat('Required', SkillRatingLevel.displayFor(row.requiredLevel)),
                        _stat('Self', SkillRatingLevel.displayFor(row.selfRating)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    managerRating,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stat('Required', SkillRatingLevel.displayFor(row.requiredLevel)),
                  const SizedBox(width: 16),
                  _stat('Self', SkillRatingLevel.displayFor(row.selfRating)),
                  const SizedBox(width: 16),
                  Expanded(child: managerRating),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SkillMatrixPill(
                label: gap > 0 ? 'Gap $gap' : 'On target',
                tone: gap > 0 ? SkillMatrixPillTone.gap : SkillMatrixPillTone.ok,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: row.managerComment ?? '',
            decoration: _decoration().copyWith(labelText: 'Manager comment'),
            maxLines: 2,
            onChanged: onManagerComment,
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: SkillMatrixTheme.border),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: SkillMatrixTheme.slate)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ],
    );
  }
}
