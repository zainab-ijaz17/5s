import 'package:flutter/material.dart';

import '../services/skill_matrix_session_service.dart';
import '../theme/skill_matrix_theme.dart';
import '../widgets/skill_matrix_widgets.dart';

class SkillMatrixEtProfileScreen extends StatefulWidget {
  const SkillMatrixEtProfileScreen({super.key});

  @override
  State<SkillMatrixEtProfileScreen> createState() =>
      _SkillMatrixEtProfileScreenState();
}

class _SkillMatrixEtProfileScreenState extends State<SkillMatrixEtProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: SkillMatrixSessionService.instance.profile,
      builder: (context, snapshot) {
        final p = snapshot.data;
        final name = p?.fullName ?? 'E & T Admin';
        final initials = name.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join();

        return SkillMatrixPageBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              SkillMatrixHeroHeader(
                title: 'Profile',
                subtitle: 'E & T Admin account',
                trailing: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  child: Text(
                    initials.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SkillMatrixSectionCard(
                title: name,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Role', p?.roleName ?? 'E & T Admin'),
                    _row('Employee #', p?.employeeNumber ?? '—'),
                    _row('Email', p?.email ?? '—'),
                    _row('Department', p?.department ?? 'E&T'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: SkillMatrixTheme.slate)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
