import 'package:flutter/material.dart';

import '../models/skill_matrix_models.dart';
import '../services/skill_matrix_api_service.dart';
import '../theme/skill_matrix_theme.dart';
import '../widgets/skill_matrix_widgets.dart';

class SkillMatrixManagerSkillMatrixPanel extends StatefulWidget {
  const SkillMatrixManagerSkillMatrixPanel({super.key});

  @override
  State<SkillMatrixManagerSkillMatrixPanel> createState() =>
      _SkillMatrixManagerSkillMatrixPanelState();
}

class _SkillMatrixManagerSkillMatrixPanelState
    extends State<SkillMatrixManagerSkillMatrixPanel> {
  bool _loading = true;
  List<SkillMatrixEmployeeSummary> _team = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _team = await SkillMatrixApiService.instance.fetchManagerTeam();
    } catch (_) {
      _team = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: SkillMatrixTheme.brandPrimary),
      );
    }

    final members = _team;

    return SkillMatrixPageBackground(
      child: RefreshIndicator(
        onRefresh: _load,
        color: SkillMatrixTheme.brandPrimary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const Text(
              'Overall proficiency and open gaps for your direct reports '
              '(from live assessments).',
              style: TextStyle(
                fontSize: 13.5,
                color: SkillMatrixTheme.slate,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            if (members.isEmpty)
              const SkillMatrixEmptyState(
                title: 'No team scores yet',
                message:
                    'When your team completes assessments, scores will appear here.',
                icon: Icons.grid_on_outlined,
              )
            else
              SkillMatrixSectionCard(
                title: 'Team proficiency',
                subtitle: '${members.length} employees',
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 44,
                    dataRowMinHeight: 48,
                    columnSpacing: 16,
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Employee',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataColumn(label: Text('Level')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Avg score')),
                      DataColumn(label: Text('Open gaps')),
                    ],
                    rows: [
                      for (final member in members)
                        DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 120,
                                child: Text(
                                  member.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(member.level)),
                            DataCell(Text(member.assessmentStatus)),
                            DataCell(
                              _ScoreChip(score: member.overallScore?.round()),
                            ),
                            DataCell(
                              Text(
                                '${member.openGaps}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: member.openGaps > 0
                                      ? SkillMatrixTheme.gap
                                      : SkillMatrixTheme.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: const [
                _LegendDot(
                  color: SkillMatrixTheme.success,
                  label: 'On target (≥3)',
                ),
                _LegendDot(color: Color(0xFFCA8A04), label: 'Developing (2)'),
                _LegendDot(color: SkillMatrixTheme.gap, label: 'Gap (≤1)'),
                _LegendDot(
                  color: SkillMatrixTheme.slate,
                  label: 'Not assessed',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.score});

  final int? score;

  @override
  Widget build(BuildContext context) {
    if (score == null) {
      return const Text('—', style: TextStyle(color: SkillMatrixTheme.slate));
    }
    final color = score! >= 3
        ? SkillMatrixTheme.success
        : score! <= 1
            ? SkillMatrixTheme.gap
            : const Color(0xFFCA8A04);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$score',
        style: TextStyle(fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: SkillMatrixTheme.slate),
        ),
      ],
    );
  }
}
