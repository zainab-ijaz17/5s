import 'package:flutter/material.dart';

import '../../../routes.dart';
import '../models/skill_rating_level.dart';
import '../services/skill_matrix_api_service.dart';
import '../theme/skill_matrix_theme.dart';
import '../widgets/skill_matrix_widgets.dart';

/// E&amp;T Admin · Skill &amp; Requirement Setup (HTML reference).
class SkillMatrixEtSkillSetupScreen extends StatefulWidget {
  const SkillMatrixEtSkillSetupScreen({super.key});

  @override
  State<SkillMatrixEtSkillSetupScreen> createState() =>
      _SkillMatrixEtSkillSetupScreenState();
}

class _SkillMatrixEtSkillSetupScreenState
    extends State<SkillMatrixEtSkillSetupScreen> {
  bool _loading = true;
  List<SkillMatrixAdminSkill> _skills = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _skills = await SkillMatrixApiService.instance.fetchAdminSkills();
    } catch (_) {
      _skills = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAddSkill() async {
    final created = await Navigator.of(context).pushNamed(
      Routes.skillMatrixEtAddSkill,
    );
    if (created == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skill added to catalog')),
      );
    }
  }

  List<SkillMatrixAdminSkill> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _skills;
    return _skills
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              s.categoryName.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: SkillMatrixTheme.brandPrimary),
      );
    }

    final filtered = _filtered;

    return SkillMatrixPageBackground(
      child: RefreshIndicator(
        onRefresh: _load,
        color: SkillMatrixTheme.brandPrimary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 88),
          children: [
            const SkillMatrixHeroHeader(
              title: 'Skill & Requirement Setup',
              subtitle: 'E & T Admin · competency catalog and level targets',
              badge: 'Catalog',
            ),
            const SizedBox(height: 8),
            const Text(
              'Browse, search, and add skills. Each skill defines category, '
              'applicable operator levels, and required proficiency.',
              style: TextStyle(
                fontSize: 13.5,
                color: SkillMatrixTheme.slate,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            SkillMatrixPrimaryButton(
              label: 'Add new skill',
              icon: Icons.add_rounded,
              onPressed: _openAddSkill,
            ),
            const SizedBox(height: 16),
            SkillMatrixSearchBar(
              hint: 'Search by skill or category…',
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 16),
            SkillMatrixStatsGrid(
              tiles: [
                SkillMatrixStatTile(
                  label: 'Skills in catalog',
                  value: '${_skills.length}',
                  icon: Icons.library_books_outlined,
                  accentColor: SkillMatrixTheme.brandPrimary,
                ),
                SkillMatrixStatTile(
                  label: 'Showing',
                  value: '${filtered.length}',
                  icon: Icons.filter_list_rounded,
                  accentColor: SkillMatrixTheme.brandDark,
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (filtered.isEmpty)
              SkillMatrixEmptyState(
                title: _skills.isEmpty ? 'No skills yet' : 'No matches',
                message: _skills.isEmpty
                    ? 'Start building your competency catalog with your first skill.'
                    : 'Try a different search term or clear the filter.',
                actionLabel: _skills.isEmpty ? 'Add skill' : null,
                onAction: _skills.isEmpty ? _openAddSkill : null,
                icon: Icons.psychology_outlined,
              )
            else
              for (final skill in filtered) ...[
                _SkillTile(skill: skill),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _SkillTile extends StatefulWidget {
  const _SkillTile({required this.skill});

  final SkillMatrixAdminSkill skill;

  @override
  State<_SkillTile> createState() => _SkillTileState();
}

class _SkillTileState extends State<_SkillTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final skill = widget.skill;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: SkillMatrixTheme.border),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          skill.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          skill.categoryName,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: SkillMatrixTheme.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SkillMatrixPill(
                    label: '${skill.applicableLevels.length} levels',
                    tone: SkillMatrixPillTone.neutral,
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: SkillMatrixTheme.slate,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 12),
                if (skill.description != null && skill.description!.isNotEmpty)
                  Text(
                    skill.description!,
                    style: const TextStyle(color: SkillMatrixTheme.slate, height: 1.4),
                  ),
                const SizedBox(height: 8),
                Text(
                  '${skill.department ?? '—'} · ${skill.area ?? '—'}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final code in skill.applicableLevels)
                      Chip(
                        label: Text(code, style: const TextStyle(fontSize: 11)),
                        backgroundColor: SkillMatrixTheme.brandTint,
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
