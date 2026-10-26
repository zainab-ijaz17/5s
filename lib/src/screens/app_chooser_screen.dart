import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../routes.dart';
import '../theme/gemba_colors.dart';
import '../services/connectivity_service.dart';
import '../services/gemba_session_service.dart';
import '../skill_matrix/services/skill_matrix_session_service.dart';
import '../services/session_service.dart';
import '../services/sync_service.dart';
import '../state/app_state.dart';
import '../widgets/packages_branded_shell.dart';

/// Hub screen: pick 5S Assessment or Digital Gemba.
class AppChooserScreen extends StatefulWidget {
  const AppChooserScreen({super.key});

  @override
  State<AppChooserScreen> createState() => _AppChooserScreenState();
}

class _AppChooserScreenState extends State<AppChooserScreen> {
  bool _busy = false;

  static const Map<String, String> buNames = {
    'BUFC': 'Finished Goods Converters',
    'BUFP': 'Flexible Packaging',
    'BUCP': 'Consumer Products',
  };

  Future<void> _openFiveS() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final session = await SessionService.instance.loadSession();
      if (session == null) {
        if (!mounted) return;
        Navigator.of(context).pushNamed(Routes.login);
        return;
      }

      final restored = await SessionService.instance.restoreAndRefreshToken();
      if (!restored) {
        await SessionService.instance.clearSession();
        if (!mounted) return;
        Navigator.of(context).pushNamed(Routes.login);
        return;
      }

      if (!mounted) return;
      final appState = context.read<AppState>();
      appState.setLogin(
        session.user,
        auditor: session.auditor,
        auditee: session.auditee,
      );
      if (session.company != null && session.company!.isNotEmpty) {
        appState.selectCompany(session.company!);
      }
      if (session.bu != null && session.bu!.isNotEmpty) {
        appState.selectBU(session.bu!);
      }
      if (session.section != null && session.section!.isNotEmpty) {
        appState.selectSection(session.section);
      }

      if (await ConnectivityService.instance.isOnline()) {
        SyncService.instance.scheduleSync(appState);
      }

      if (!mounted) return;
      _navigateFiveS(session);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _navigateFiveS(StoredSession session) {
    final role = session.user.role.toLowerCase();
    final isPowerUser = role == 'poweruser' || role == 'power_user';
    final isBUManager =
        role == 'bumanager' || role == 'bu_manager' || role == 'manager';

    final route = session.lastRoute;
    if (route != null && route.isNotEmpty) {
      if (route == Routes.buManagerDashboard && isBUManager) {
        Navigator.of(context).pushNamed(
          Routes.buManagerDashboard,
          arguments: <String, String>{
            'buCode': session.user.businessUnit ?? '',
            'buName': buNames[session.user.businessUnit ?? ''] ?? '',
          },
        );
        return;
      }
      Navigator.of(context).pushNamed(route);
      return;
    }

    if (isPowerUser) {
      Navigator.of(context).pushNamed(Routes.powerUser);
      return;
    }
    if (isBUManager) {
      Navigator.of(context).pushNamed(
        Routes.buManagerDashboard,
        arguments: <String, String>{
          'buCode': session.user.businessUnit ?? '',
          'buName': buNames[session.user.businessUnit ?? ''] ?? '',
        },
      );
      return;
    }

    Navigator.of(context).pushNamed(Routes.takeTest);
  }

  Future<void> _openSkillMatrix() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final role = await SkillMatrixSessionService.instance.loadRole();
      if (!mounted) return;
      Navigator.of(context).pushNamed(
        role != null ? Routes.skillMatrixHome : Routes.skillMatrixRole,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openGemba() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final session = await GembaSessionService.instance.loadSession();
      if (!mounted) return;
      if (session != null) {
        Navigator.of(context).pushNamed(Routes.gembaHome);
      } else {
        Navigator.of(context).pushNamed(Routes.gembaLogin);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0891B2).withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          PackagesBrandedShell.logoAsset,
                          width: 132,
                          height: 110,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Choose an application to continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _AppOptionCard(
                    title: '5S Digital Assessment',
                    subtitle:
                        'Digital workplace audits, scoring, and follow-ups',
                    icon: Icons.checklist_rtl_rounded,
                    accent: const Color(0xFF0891B2),
                    accentSoft: const Color(0xFFE0F2FE),
                    onTap: _busy ? null : _openFiveS,
                  ),
                  const SizedBox(height: 14),
                  _AppOptionCard(
                    title: 'Digital Gemba',
                    subtitle:
                        'Shop-floor observations with SuccessFactors sign-in',
                    icon: Icons.factory_outlined,
                    accent: GembaColors.brandPrimary,
                    accentSoft: GembaColors.brandTint,
                    onTap: _busy ? null : _openGemba,
                  ),
                  const SizedBox(height: 14),
                  _AppOptionCard(
                    title: 'Skill Matrix',
                    subtitle:
                        'Worker self-assessment and line manager team reviews',
                    icon: Icons.grid_view_rounded,
                    accent: const Color(0xFF0D9488),
                    accentSoft: const Color(0xFFCCFBF1),
                    onTap: _busy ? null : _openSkillMatrix,
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 28),
                    const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF0891B2),
                        ),
                      ),
                    ),
                  ],
                  const PackagesCopyrightFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppOptionCard extends StatelessWidget {
  const _AppOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.accentSoft,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color accentSoft;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: accentSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accent, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
