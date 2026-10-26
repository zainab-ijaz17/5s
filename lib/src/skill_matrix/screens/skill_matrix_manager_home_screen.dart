import 'package:flutter/material.dart';

import '../../../routes.dart';
import '../models/skill_matrix_models.dart';
import '../services/skill_matrix_api_service.dart';
import '../theme/skill_matrix_theme.dart';
import '../widgets/skill_matrix_team_member_card.dart';
import '../widgets/skill_matrix_widgets.dart';

class SkillMatrixManagerHomeScreen extends StatefulWidget {
  const SkillMatrixManagerHomeScreen({
    super.key,
    required this.onReview,
    this.onOpenSkillMatrix,
    this.onOpenAllAssessments,
  });

  final void Function(String employeeId, String userId) onReview;
  final VoidCallback? onOpenSkillMatrix;
  final VoidCallback? onOpenAllAssessments;

  static const _previewAwaitingCount = 3;

  @override
  State<SkillMatrixManagerHomeScreen> createState() =>
      _SkillMatrixManagerHomeScreenState();
}

class _SkillMatrixManagerHomeScreenState extends State<SkillMatrixManagerHomeScreen> {
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

    final team = _team;
    final awaiting = team.where((m) => m.awaitingReview).toList();
    final previewAwaiting = awaiting.take(SkillMatrixManagerHomeScreen._previewAwaitingCount).toList();
    final awaitingCount = awaiting.length;
    final openGaps = team.fold<int>(0, (sum, m) => sum + m.openGaps);
    final scored = team.where((m) => m.overallScore != null).toList();
    final teamAvg = scored.isEmpty
        ? '—'
        : (scored.map((m) => m.overallScore!).reduce((a, b) => a + b) /
                scored.length)
            .toStringAsFixed(1);

    return SkillMatrixPageBackground(
      child: RefreshIndicator(
        onRefresh: _load,
        color: SkillMatrixTheme.brandPrimary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            SkillMatrixHeroHeader(
              title: 'Team overview',
              subtitle: 'Line Manager · current assessment cycle',
              badge: '${team.length} direct reports',
            ),
            const SizedBox(height: 8),
            const Text(
              'Monitor team readiness, review submitted assessments, and '
              'assign development where skill gaps exist.',
              style: TextStyle(
                fontSize: 13.5,
                color: SkillMatrixTheme.slate,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            SkillMatrixStatsGrid(
              tiles: [
                SkillMatrixStatTile(
                  label: 'Team average score',
                  value: '$teamAvg / 5',
                  icon: Icons.leaderboard_rounded,
                  accentColor: SkillMatrixTheme.brandPrimary,
                ),
                SkillMatrixStatTile(
                  label: 'Awaiting your review',
                  value: '$awaitingCount',
                  highlight: awaitingCount > 0,
                  icon: Icons.pending_actions_rounded,
                  accentColor: const Color(0xFFEA580C),
                ),
                SkillMatrixStatTile(
                  label: 'Open skill gaps',
                  value: '$openGaps',
                  icon: Icons.warning_amber_rounded,
                  accentColor: SkillMatrixTheme.gap,
                ),
                const SkillMatrixStatTile(
                  label: 'Trainings overdue',
                  value: '—',
                  icon: Icons.event_busy_rounded,
                  accentColor: Color(0xFF7C3AED),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SkillMatrixHubActionCard(
              title: 'Team skill matrix',
              subtitle:
                  'Category scores across your direct reports — heat map view.',
              icon: Icons.grid_on_rounded,
              onTap: () {
                if (widget.onOpenSkillMatrix != null) {
                  widget.onOpenSkillMatrix!();
                } else {
                  Navigator.of(context).pushNamed(
                    Routes.skillMatrixManagerSkillMatrix,
                  );
                }
              },
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Awaiting your review',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: SkillMatrixTheme.ink,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Priority submissions for this cycle',
                        style: TextStyle(
                          fontSize: 13,
                          color: SkillMatrixTheme.slate,
                        ),
                      ),
                    ],
                  ),
                ),
                if (awaitingCount > SkillMatrixManagerHomeScreen._previewAwaitingCount)
                  TextButton(
                    onPressed: () => _openAllAssessments(context),
                    child: Text(
                      'View all ($awaitingCount)',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (previewAwaiting.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SkillMatrixTheme.border),
                ),
                child: const Text(
                  'No assessments are waiting for your review right now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SkillMatrixTheme.slate, height: 1.4),
                ),
              )
            else ...[
              for (final member in previewAwaiting) ...[
                SkillMatrixTeamMemberCard(
                  member: member,
                  compact: true,
                  onReview: () => widget.onReview(
                    member.id,
                    member.userId.isNotEmpty ? member.userId : member.id,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
            const SizedBox(height: 16),
            SkillMatrixHubActionCard(
              title: 'All team assessments',
              subtitle:
                  'Filter by level and status · review, remind, or view history.',
              icon: Icons.groups_rounded,
              accent: SkillMatrixTheme.brandDark,
              onTap: () => _openAllAssessments(context),
            ),
          ],
        ),
      ),
    );
  }

  void _openAllAssessments(BuildContext context) {
    if (widget.onOpenAllAssessments != null) {
      widget.onOpenAllAssessments!();
      return;
    }
    Navigator.of(context).pushNamed(Routes.skillMatrixManagerAssessments);
  }
}
