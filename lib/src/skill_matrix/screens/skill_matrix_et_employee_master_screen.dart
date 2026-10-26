import 'package:flutter/material.dart';

import '../models/skill_matrix_user_profile.dart';
import '../services/skill_matrix_api_service.dart';
import '../theme/skill_matrix_theme.dart';
import '../widgets/skill_matrix_widgets.dart';

/// E&amp;T Admin · Employee Master (HTML reference).
class SkillMatrixEtEmployeeMasterScreen extends StatefulWidget {
  const SkillMatrixEtEmployeeMasterScreen({super.key});

  @override
  State<SkillMatrixEtEmployeeMasterScreen> createState() =>
      _SkillMatrixEtEmployeeMasterScreenState();
}

class _SkillMatrixEtEmployeeMasterScreenState
    extends State<SkillMatrixEtEmployeeMasterScreen> {
  bool _loading = true;
  List<SkillMatrixUserProfile> _users = [];
  String _filter = 'All';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _users = await SkillMatrixApiService.instance.fetchAdminUsers();
    } catch (_) {
      _users = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<SkillMatrixUserProfile> get _filtered {
    var list = _filter == 'All'
        ? _users
        : _users.where((u) => u.roleName == _filter).toList();
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where(
          (u) =>
              u.fullName.toLowerCase().contains(q) ||
              u.employeeNumber.contains(q) ||
              (u.department ?? '').toLowerCase().contains(q),
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

    final workers = _users.where((u) => u.roleName == 'Worker').length;
    final active = _users.length;

    return SkillMatrixPageBackground(
      child: RefreshIndicator(
        onRefresh: _load,
        color: SkillMatrixTheme.brandPrimary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const SkillMatrixHeroHeader(
              title: 'Employee Master',
              subtitle: 'E & T Admin · workforce records for Skill Matrix',
              badge: 'Master data',
            ),
            const SizedBox(height: 8),
            const Text(
              'Maintain employee attributes used in assessments: role, level, '
              'department, line manager, and status.',
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
                  label: 'Total records',
                  value: '$active',
                  icon: Icons.badge_outlined,
                  accentColor: SkillMatrixTheme.brandPrimary,
                ),
                SkillMatrixStatTile(
                  label: 'Workers',
                  value: '$workers',
                  icon: Icons.engineering_outlined,
                  accentColor: const Color(0xFF0D9488),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SkillMatrixSearchBar(
              hint: 'Search name, ID, or department…',
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final f in ['All', 'Worker', 'Line Manager', 'E & T Admin'])
                  FilterChip(
                    label: Text(f),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                    selectedColor: SkillMatrixTheme.brandTint,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_filtered.isEmpty)
              const SkillMatrixEmptyState(
                title: 'No employees found',
                message: 'Adjust your search or role filter.',
                icon: Icons.person_search_outlined,
              )
            else
              for (final user in _filtered) ...[
                _EmployeeCard(user: user),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.user});

  final SkillMatrixUserProfile user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SkillMatrixTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: SkillMatrixTheme.brandTint,
                child: Text(
                  _initials(user.fullName),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: SkillMatrixTheme.brandPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${user.employeeNumber} · ${user.roleName}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: SkillMatrixTheme.slate,
                      ),
                    ),
                  ],
                ),
              ),
              SkillMatrixPill(
                label: user.roleName,
                tone: SkillMatrixPillTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _detailRow('Email', user.email),
          _detailRow('Department', user.department ?? '—'),
          _detailRow('Area / Line', user.areaLine ?? '—'),
          _detailRow('Level', user.levelCode ?? '—'),
          _detailRow('Designation', user.designation ?? '—'),
          _detailRow('Line manager', user.lineManagerName ?? '—'),
          if (user.dateOfJoining != null)
            _detailRow('Date of joining', user.dateOfJoining!.substring(0, 10)),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: SkillMatrixTheme.slate,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
