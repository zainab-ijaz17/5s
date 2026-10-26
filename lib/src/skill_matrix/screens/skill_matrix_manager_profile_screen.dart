import 'package:flutter/material.dart';

import '../models/skill_matrix_user_profile.dart';
import '../services/skill_matrix_api_service.dart';
import '../services/skill_matrix_session_service.dart';
import '../skill_matrix_format.dart';
import '../theme/skill_matrix_theme.dart';
import '../widgets/skill_matrix_widgets.dart';

class SkillMatrixManagerProfileScreen extends StatefulWidget {
  const SkillMatrixManagerProfileScreen({super.key});

  @override
  State<SkillMatrixManagerProfileScreen> createState() =>
      _SkillMatrixManagerProfileScreenState();
}

class _SkillMatrixManagerProfileScreenState
    extends State<SkillMatrixManagerProfileScreen> {
  bool _loading = true;
  SkillMatrixUserProfile? _profile;
  int _teamCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _profile = await SkillMatrixApiService.instance.fetchMe();
      final team = await SkillMatrixApiService.instance.fetchManagerTeam();
      _teamCount = team.length;
    } catch (_) {
      _profile = await SkillMatrixSessionService.instance.profile;
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

    final p = _profile;
    if (p == null) {
      return const SkillMatrixPageBackground(
        child: Center(
          child: Text(
            'Sign in to view your profile.',
            style: TextStyle(color: SkillMatrixTheme.slate),
          ),
        ),
      );
    }

    final subtitle = [
      p.roleName,
      if (p.department != null && p.department!.isNotEmpty) p.department,
    ].join(' · ');

    return SkillMatrixPageBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          SkillMatrixHeroHeader(
            title: 'Profile',
            subtitle: 'Your line manager account for Skill Matrix.',
            trailing: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white.withOpacity(0.25),
              child: Text(
                skillMatrixInitials(p.fullName),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SkillMatrixTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.fullName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: SkillMatrixTheme.ink,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: SkillMatrixTheme.slate,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _ProfileRow(
                  icon: Icons.badge_outlined,
                  label: 'Employee ID',
                  value: p.employeeNumber,
                ),
                _ProfileRow(
                  icon: Icons.groups_outlined,
                  label: 'Direct reports',
                  value: '$_teamCount employees',
                ),
                if (p.department != null && p.department!.isNotEmpty)
                  _ProfileRow(
                    icon: Icons.apartment_outlined,
                    label: 'Department',
                    value: p.department!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: SkillMatrixTheme.brandPrimary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SkillMatrixTheme.slate,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: SkillMatrixTheme.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
