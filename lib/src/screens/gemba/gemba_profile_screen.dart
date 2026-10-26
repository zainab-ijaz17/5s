import 'package:flutter/material.dart';
import '../../theme/gemba_colors.dart';

import '../../../routes.dart';
import '../../models/gemba_user.dart';
import '../../services/gemba_session_service.dart';

class GembaProfileScreen extends StatefulWidget {
  const GembaProfileScreen({super.key});

  @override
  State<GembaProfileScreen> createState() => _GembaProfileScreenState();
}

class _GembaProfileScreenState extends State<GembaProfileScreen> {
  GembaUser? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await GembaSessionService.instance.loadSession();
    if (!mounted) return;
    if (session == null) {
      Navigator.of(context).pushReplacementNamed(Routes.gembaLogin);
      return;
    }
    setState(() {
      _user = session.user;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = _user!;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            GembaColors.brandTint,
            Color(0xFFE2E8F0),
          ],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text(
            'Welcome, ${user.name}',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: GembaColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your SuccessFactors profile for this Digital Gemba session.',
            style: TextStyle(
              fontSize: 14.5,
              color: Color(0xFF475569),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          _ProfileTile(
            label: 'Role',
            value: user.isAdmin ? 'Admin' : 'User',
            icon: Icons.shield_outlined,
          ),
          _ProfileTile(
            label: 'Name',
            value: user.name,
            icon: Icons.person_outline_rounded,
          ),
          _ProfileTile(
            label: 'Email',
            value: user.email.isEmpty ? '—' : user.email,
            icon: Icons.email_outlined,
          ),
          _ProfileTile(
            label: 'Employee number',
            value: user.employeeNumber,
            icon: Icons.badge_outlined,
          ),
          _ProfileTile(
            label: 'Cost center',
            value: (user.costCenter == null || user.costCenter!.isEmpty)
                ? '—'
                : user.costCenter!,
            icon: Icons.account_balance_outlined,
          ),
          _ProfileTile(
            label: 'Company',
            value: (user.companyName == null || user.companyName!.isEmpty)
                ? '—'
                : user.companyName!,
            icon: Icons.business_outlined,
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: GembaColors.brandTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: GembaColors.brandPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
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
