import 'package:flutter/material.dart';

import '../models/skill_matrix_models.dart';
import '../theme/skill_matrix_theme.dart';
import 'skill_matrix_widgets.dart';

class SkillMatrixTeamMemberCard extends StatelessWidget {
  const SkillMatrixTeamMemberCard({
    super.key,
    required this.member,
    required this.onReview,
    this.compact = false,
  });

  final SkillMatrixEmployeeSummary member;
  final VoidCallback onReview;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    SkillMatrixPillTone statusTone;
    switch (member.assessmentStatus) {
      case 'Approved':
        statusTone = SkillMatrixPillTone.ok;
      case 'Awaiting my review':
        statusTone = SkillMatrixPillTone.warning;
      case 'Not started':
        statusTone = SkillMatrixPillTone.neutral;
      default:
        statusTone = SkillMatrixPillTone.draft;
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onReview,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 14 : 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: member.awaitingReview
                  ? SkillMatrixTheme.warningBorder
                  : SkillMatrixTheme.border,
            ),
            borderRadius: BorderRadius.circular(16),
            color: member.awaitingReview
                ? const Color(0xFFFFFBF5)
                : Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: compact ? 20 : 22,
                    backgroundColor: SkillMatrixTheme.brandTint,
                    child: Text(
                      _initials(member.name),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: SkillMatrixTheme.brandDark,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: SkillMatrixTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${member.id} · ${member.department} · ${member.level}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: SkillMatrixTheme.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (member.overallScore != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: SkillMatrixTheme.brandTint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        member.overallScore!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: SkillMatrixTheme.brandPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SkillMatrixPill(
                    label: member.assessmentStatus,
                    tone: statusTone,
                  ),
                  if (member.openGaps > 0)
                    SkillMatrixPill(
                      label:
                          '${member.openGaps} gap${member.openGaps == 1 ? '' : 's'}',
                      tone: SkillMatrixPillTone.gap,
                    ),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: member.awaitingReview
                      ? FilledButton.icon(
                          onPressed: onReview,
                          icon: const Icon(Icons.rate_review_outlined, size: 18),
                          label: const Text('Review now'),
                          style: FilledButton.styleFrom(
                            backgroundColor: SkillMatrixTheme.brandPrimary,
                            foregroundColor: Colors.white,
                          ),
                        )
                      : OutlinedButton(
                          onPressed: onReview,
                          child: const Text('View assessment'),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
