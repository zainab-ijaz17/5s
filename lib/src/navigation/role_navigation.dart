import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../routes.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../state/app_state.dart';
import 'role_section.dart';

class RoleNavigation {
  RoleNavigation._();

  static const Map<String, String> buNames = {
    'BUFC': 'Finished Goods Converters',
    'BUFP': 'Flexible Packaging',
    'BUCP': 'Consumer Products',
  };

  static bool showSwitcherFor(AppState appState) =>
      appState.isPowerUser || appState.isBUManager;

  static List<RoleSection> sectionsFor(AppState appState) {
    if (appState.isPowerUser) {
      return RoleSection.values;
    }
    if (appState.isBUManager) {
      return const [RoleSection.takeTest, RoleSection.buDashboard];
    }
    return const [];
  }

  static String labelFor(RoleSection section) {
    switch (section) {
      case RoleSection.takeTest:
        return 'Take Test';
      case RoleSection.buDashboard:
        return 'BU Dashboard';
      case RoleSection.powerDashboard:
        return 'Power Dashboard';
    }
  }

  static IconData iconFor(RoleSection section) {
    switch (section) {
      case RoleSection.takeTest:
        return Icons.quiz_outlined;
      case RoleSection.buDashboard:
        return Icons.business_outlined;
      case RoleSection.powerDashboard:
        return Icons.dashboard_outlined;
    }
  }

  static Future<void> navigate(
    BuildContext context,
    RoleSection section, {
    RoleSection? current,
  }) async {
    if (current == section) return;

    switch (section) {
      case RoleSection.takeTest:
        await _goToTakeTest(context);
      case RoleSection.buDashboard:
        await _goToBuDashboard(context);
      case RoleSection.powerDashboard:
        await _goToPowerDashboard(context);
    }
  }

  static Future<void> _goToTakeTest(BuildContext context) async {
    final appState = context.read<AppState>();
    final user = appState.currentUser;
    if (user == null) return;

    var auditor = appState.auditorName;
    var auditee = appState.auditeeName;

    if (auditor == null ||
        auditee == null ||
        auditor.isEmpty ||
        auditee.isEmpty) {
      final names = await _showAuditorAuditeeDialog(context);
      if (names == null) return;
      auditor = names['auditor'];
      auditee = names['auditee'];
      appState.setLogin(user, auditor: auditor, auditee: auditee);
    }

    await _persistSession(
      context,
      route: Routes.takeTest,
      auditor: auditor,
      auditee: auditee,
    );
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, Routes.takeTest);
  }

  static Future<void> _goToBuDashboard(BuildContext context) async {
    final appState = context.read<AppState>();
    if (appState.isPowerUser) {
      await _persistSession(context, route: Routes.buSelection);
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, Routes.buSelection);
      return;
    }

    if (appState.isBUManager) {
      final bu = appState.currentUser?.businessUnit ?? '';
      await _persistSession(context, route: Routes.buManagerDashboard);
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(
        context,
        Routes.buManagerDashboard,
        arguments: <String, String>{
          'buCode': bu,
          'buName': buNames[bu] ?? bu,
        },
      );
    }
  }

  static Future<void> _goToPowerDashboard(BuildContext context) async {
    final appState = context.read<AppState>();
    if (!appState.isPowerUser) return;

    await _persistSession(context, route: Routes.powerUser);
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, Routes.powerUser);
  }

  static Future<void> _persistSession(
    BuildContext context, {
    required String route,
    String? auditor,
    String? auditee,
  }) async {
    final appState = context.read<AppState>();
    final user = appState.currentUser;
    if (user == null) return;

    final token = await ApiService.getAccessToken();
    if (token == null || token.isEmpty) return;

    await SessionService.instance.saveSession(
      user: user,
      accessToken: token,
      auditor: auditor ?? appState.auditorName,
      auditee: auditee ?? appState.auditeeName,
      lastRoute: route,
      company: appState.selectedCompany,
      bu: appState.selectedBU,
      section: appState.selectedSection,
    );
  }

  /// Prompts for auditor/auditee when missing. Returns false if cancelled.
  static Future<bool> ensureAuditorAuditee(BuildContext context) async {
    final appState = context.read<AppState>();
    final user = appState.currentUser;
    if (user == null) return false;

    var auditor = appState.auditorName?.trim() ?? '';
    var auditee = appState.auditeeName?.trim() ?? '';

    if (auditor.isNotEmpty && auditee.isNotEmpty) return true;

    final names = await _showAuditorAuditeeDialog(context);
    if (names == null) return false;

    auditor = names['auditor'] ?? '';
    auditee = names['auditee'] ?? '';
    if (auditor.isEmpty || auditee.isEmpty) return false;

    appState.setLogin(user, auditor: auditor, auditee: auditee);
    await SessionService.instance.saveAssessmentContext(
      auditor: auditor,
      auditee: auditee,
      company: appState.selectedCompany,
      bu: appState.selectedBU,
      section: appState.selectedSection,
      lastRoute: Routes.takeTest,
    );
    return true;
  }

  static Future<Map<String, String>?> _showAuditorAuditeeDialog(
    BuildContext context,
  ) {
    final auditorController = TextEditingController();
    final auditeeController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Assessment Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: auditorController,
              decoration: const InputDecoration(labelText: 'Auditor Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: auditeeController,
              decoration: const InputDecoration(labelText: 'Auditee Name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final auditor = auditorController.text.trim();
              final auditee = auditeeController.text.trim();
              if (auditor.isNotEmpty && auditee.isNotEmpty) {
                Navigator.pop(ctx, {
                  'auditor': auditor,
                  'auditee': auditee,
                });
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
