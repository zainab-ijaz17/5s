import 'package:flutter/material.dart';

import '../../../routes.dart';
import '../../widgets/packages_branded_shell.dart';
import '../models/skill_matrix_role.dart';
import '../services/skill_matrix_api_service.dart';
import '../theme/skill_matrix_theme.dart';
import '../widgets/skill_matrix_widgets.dart';

class SkillMatrixRoleScreen extends StatefulWidget {
  const SkillMatrixRoleScreen({super.key});

  @override
  State<SkillMatrixRoleScreen> createState() => _SkillMatrixRoleScreenState();
}

class _SkillMatrixRoleScreenState extends State<SkillMatrixRoleScreen> {
  final _employeeController = TextEditingController(text: '50021446');
  final _passwordController = TextEditingController(text: 'skill123');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _employeeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await SkillMatrixApiService.instance.login(
        employeeNumber: _employeeController.text,
        password: _passwordController.text,
      );
      final role = SkillMatrixRole.fromApiName(profile.roleName);
      if (role == null) {
        throw Exception('Unknown role: ${profile.roleName}');
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(Routes.skillMatrixHome);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fillDemo(String emp, SkillMatrixRole role) {
    _employeeController.text = emp;
    _passwordController.text = 'skill123';
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FA),
      appBar: AppBar(
        backgroundColor: SkillMatrixTheme.brandPrimary,
        foregroundColor: Colors.white,
        title: const Text('Skill Matrix'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
            Routes.appChooser,
            (route) => false,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: SkillMatrixTheme.headerGradient,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sign in',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Skill Matrix portal',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Use your employee number and password. Role (Worker, Line Manager, or E & T Admin) comes from your profile.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _employeeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Employee number',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _login(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: SkillMatrixTheme.gap, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: SkillMatrixTheme.gap, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SkillMatrixPrimaryButton(
                    label: 'Sign in',
                    loading: _busy,
                    onPressed: _login,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Demo accounts (password: skill123)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: SkillMatrixTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Worker · 50021446'),
                        onPressed: () => _fillDemo('50021446', SkillMatrixRole.worker),
                      ),
                      ActionChip(
                        label: const Text('Line Manager · 50021001'),
                        onPressed: () =>
                            _fillDemo('50021001', SkillMatrixRole.lineManager),
                      ),
                      ActionChip(
                        label: const Text('E & T Admin · 50021999'),
                        onPressed: () => _fillDemo('50021999', SkillMatrixRole.etAdmin),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
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
