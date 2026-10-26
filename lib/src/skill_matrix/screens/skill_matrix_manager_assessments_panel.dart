import 'package:flutter/material.dart';

import '../models/skill_matrix_models.dart';
import '../services/skill_matrix_api_service.dart';
import '../theme/skill_matrix_theme.dart';
import '../widgets/skill_matrix_team_member_card.dart';
import '../widgets/skill_matrix_widgets.dart';

class SkillMatrixManagerAssessmentsPanel extends StatefulWidget {
  const SkillMatrixManagerAssessmentsPanel({
    super.key,
    required this.onReview,
  });

  final void Function(String employeeId, String userId) onReview;

  @override
  State<SkillMatrixManagerAssessmentsPanel> createState() =>
      _SkillMatrixManagerAssessmentsPanelState();
}

class _SkillMatrixManagerAssessmentsPanelState
    extends State<SkillMatrixManagerAssessmentsPanel> {
  String _levelFilter = 'All';
  String _statusFilter = 'All';
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

  List<SkillMatrixEmployeeSummary> get _filtered {
    return _team.where((m) {
      if (_levelFilter != 'All' && m.level != _levelFilter) return false;
      if (_statusFilter != 'All' && m.assessmentStatus != _statusFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  List<String> get _levelOptions {
    final levels = _team.map((m) => m.level).where((l) => l.isNotEmpty).toSet().toList()
      ..sort();
    return ['All', ...levels];
  }

  List<String> get _statusOptions {
    final statuses =
        _team.map((m) => m.assessmentStatus).where((s) => s.isNotEmpty).toSet().toList()
          ..sort();
    return ['All', ...statuses];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: SkillMatrixTheme.brandPrimary),
      );
    }

    final filtered = _filtered;
    final levelOptions = _levelOptions;
    final statusOptions = _statusOptions;
    if (!levelOptions.contains(_levelFilter)) _levelFilter = 'All';
    if (!statusOptions.contains(_statusFilter)) _statusFilter = 'All';

    return SkillMatrixPageBackground(
      child: RefreshIndicator(
        onRefresh: _load,
        color: SkillMatrixTheme.brandPrimary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              '${filtered.length} of ${_team.length} direct reports shown',
              style: const TextStyle(
                fontSize: 14,
                color: SkillMatrixTheme.slate,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            SkillMatrixSectionCard(
              title: 'Filters',
              subtitle: 'Narrow the list by role level or assessment status',
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 400;
                  final level = _filterDropdown(
                    label: 'Level',
                    value: _levelFilter,
                    options: levelOptions,
                    onChanged: (v) => setState(() => _levelFilter = v!),
                  );
                  final status = _filterDropdown(
                    label: 'Assessment status',
                    value: _statusFilter,
                    options: statusOptions,
                    onChanged: (v) => setState(() => _statusFilter = v!),
                  );
                  if (stacked) {
                    return Column(
                      children: [
                        level,
                        const SizedBox(height: 14),
                        status,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: level),
                      const SizedBox(width: 12),
                      Expanded(child: status),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_team.isEmpty)
              const SkillMatrixEmptyState(
                title: 'No team data',
                message: 'Your direct reports will appear here once loaded from the server.',
                icon: Icons.groups_outlined,
              )
            else if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SkillMatrixTheme.border),
                ),
                child: const Text(
                  'No team members match these filters.',
                  style: TextStyle(color: SkillMatrixTheme.slate),
                ),
              )
            else
              for (final member in filtered) ...[
                SkillMatrixTeamMemberCard(
                  member: member,
                  onReview: () => widget.onReview(
                    member.id,
                    member.userId.isNotEmpty ? member.userId : member.id,
                  ),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkillMatrixFieldLabel(label),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: options.contains(value) ? value : options.first,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: SkillMatrixTheme.border),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          selectedItemBuilder: (context) => [
            for (final o in options)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  o,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          items: [
            for (final o in options)
              DropdownMenuItem(
                value: o,
                child: Text(o, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
