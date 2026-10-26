import 'package:flutter/material.dart';

import '../models/skill_matrix_models.dart';
import '../models/skill_rating_level.dart';
import '../theme/skill_matrix_theme.dart';
import 'skill_matrix_widgets.dart';

class SkillMatrixAssessmentCard extends StatelessWidget {
  const SkillMatrixAssessmentCard({
    super.key,
    required this.row,
    this.onEdit,
    this.compact = false,
    this.showManagerRating = false,
  });

  final SkillMatrixSkillRow row;
  final VoidCallback? onEdit;
  final bool compact;
  final bool showManagerRating;

  @override
  Widget build(BuildContext context) {
    final self = row.selfRating;
    final manager = row.managerRating;
    final validated = manager ?? self;
    final gap = row.hasGap;
    final accent = gap ? SkillMatrixTheme.gap : SkillMatrixTheme.brandPrimary;
    final padding = EdgeInsets.fromLTRB(
      16,
      compact ? 14 : 16,
      16,
      compact ? 14 : 16,
    );

    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: accent, width: 5),
              top: const BorderSide(color: SkillMatrixTheme.border),
              right: const BorderSide(color: SkillMatrixTheme.border),
              bottom: const BorderSide(color: SkillMatrixTheme.border),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                row.skill,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 14.5 : 15.5,
                  color: SkillMatrixTheme.ink,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: SkillMatrixPill(
                  label: row.category,
                  tone: SkillMatrixPillTone.neutral,
                ),
              ),
              SizedBox(height: compact ? 12 : 14),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Required',
                      value: SkillRatingLevel.displayFor(row.requiredLevel),
                      sub: SkillRatingLevel.descriptionFor(row.requiredLevel),
                    ),
                  ),
                  Expanded(
                    child: _MetricTile(
                      label: showManagerRating ? 'Your self-rating' : 'Your rating',
                      value: SkillRatingLevel.displayFor(self),
                      sub: self == null
                          ? 'Not assessed'
                          : SkillRatingLevel.descriptionFor(self),
                    ),
                  ),
                ],
              ),
              if (showManagerRating && manager != null) ...[
                const SizedBox(height: 10),
                _MetricTile(
                  label: 'Manager validation',
                  value: SkillRatingLevel.displayFor(manager),
                  sub: SkillRatingLevel.descriptionFor(manager),
                  fullWidth: true,
                ),
              ],
              if (!showManagerRating && validated != null) ...[
                const SizedBox(height: 8),
                Text(
                  gap
                      ? 'Below required (${SkillRatingLevel.displayFor(validated)} vs ${SkillRatingLevel.displayFor(row.requiredLevel)})'
                      : 'Meets required proficiency',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: gap ? SkillMatrixTheme.gap : SkillMatrixTheme.success,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SkillMatrixPill(
                    label: gap ? 'Below requirement' : 'Meets requirement',
                    tone: gap ? SkillMatrixPillTone.gap : SkillMatrixPillTone.ok,
                  ),
                  if (onEdit != null)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit rating'),
                      style: TextButton.styleFrom(
                        foregroundColor: SkillMatrixTheme.brandDark,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.sub,
    this.fullWidth = false,
  });

  final String label;
  final String value;
  final String sub;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      margin: EdgeInsets.only(right: fullWidth ? 0 : 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SkillMatrixTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: SkillMatrixTheme.slate,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SkillMatrixTheme.ink,
            ),
          ),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: SkillMatrixTheme.slate),
          ),
        ],
      ),
    );
  }
}
