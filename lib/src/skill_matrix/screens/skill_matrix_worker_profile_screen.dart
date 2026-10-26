import 'package:flutter/material.dart';

import '../models/skill_matrix_user_profile.dart';
import '../services/skill_matrix_api_service.dart';
import '../services/skill_matrix_session_service.dart';
import '../skill_matrix_format.dart';
import '../theme/skill_matrix_theme.dart';
import '../widgets/skill_matrix_widgets.dart';

class SkillMatrixWorkerProfileScreen extends StatefulWidget {
  const SkillMatrixWorkerProfileScreen({super.key});

  @override
  State<SkillMatrixWorkerProfileScreen> createState() =>
      _SkillMatrixWorkerProfileScreenState();
}

class _SkillMatrixWorkerProfileScreenState
    extends State<SkillMatrixWorkerProfileScreen> {
  bool _loading = true;
  SkillMatrixUserProfile? _profile;
  String _cycleLabel = '—';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _profile =
          await SkillMatrixApiService.instance.fetchMe();
      final assessment =
          await SkillMatrixApiService.instance.currentAssessment();
      _cycleLabel = assessment['cycleLabel']?.toString() ?? '—';
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

    final deptLevel = [
      if (p.department != null && p.department!.isNotEmpty) p.department,
      if (p.levelCode != null && p.levelCode!.isNotEmpty) p.levelCode,
    ].join(' · ');

    return SkillMatrixPageBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          SkillMatrixHeroHeader(
            title: 'Profile',
            subtitle: 'Employment record used for this assessment cycle.',
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
                if (deptLevel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    deptLevel,
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
                  icon: Icons.person_outline_rounded,
                  label: 'Line manager',
                  value: p.lineManagerName ?? '—',
                ),
                if (p.dateOfJoining != null && p.dateOfJoining!.isNotEmpty)
                  _ProfileRow(
                    icon: Icons.schedule_rounded,
                    label: 'Date of joining',
                    value: p.dateOfJoining!,
                  ),
                _ProfileRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Current cycle',
                  value: _cycleLabel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SkillMatrixTheme.brandTint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: SkillMatrixTheme.brandPrimary.withOpacity(0.2),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: SkillMatrixTheme.brandDark,
                  size: 22,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Details are sourced from the employee master. '
                    'Contact Education & Training if any information is incorrect.',
                    style: TextStyle(
                      fontSize: 13,
                      color: SkillMatrixTheme.brandDark,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
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
