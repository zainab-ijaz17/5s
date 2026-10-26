import 'package:flutter/material.dart';

import '../../../routes.dart';
import '../models/skill_matrix_role.dart';
import '../services/skill_matrix_session_service.dart';
import '../theme/skill_matrix_theme.dart';
import 'skill_matrix_manager_assessments_panel.dart';
import 'skill_matrix_manager_home_screen.dart';
import 'skill_matrix_manager_profile_screen.dart';
import 'skill_matrix_manager_skill_matrix_panel.dart';
import 'skill_matrix_worker_gaps_screen.dart';
import 'skill_matrix_worker_profile_screen.dart';
import 'skill_matrix_et_employee_master_screen.dart';
import 'skill_matrix_et_log_training_screen.dart';
import 'skill_matrix_et_profile_screen.dart';
import 'skill_matrix_et_skill_setup_screen.dart';
import 'skill_matrix_worker_self_assessment_screen.dart';

class SkillMatrixHomeScreen extends StatefulWidget {
  const SkillMatrixHomeScreen({super.key});

  @override
  State<SkillMatrixHomeScreen> createState() => _SkillMatrixHomeScreenState();
}

class _SkillMatrixHomeScreenState extends State<SkillMatrixHomeScreen> {
  SkillMatrixRole? _role;
  int _index = 0;
  String? _userSubtitle;
  final _workerAssessmentKey = GlobalKey<SkillMatrixWorkerSelfAssessmentScreenState>();

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await SkillMatrixSessionService.instance.loadRole();
    final profile = await SkillMatrixSessionService.instance.profile;
    if (!mounted) return;
    if (role == null) {
      Navigator.of(context).pushReplacementNamed(Routes.skillMatrixRole);
      return;
    }
    setState(() {
      _role = role;
      _userSubtitle = profile != null
          ? '${profile.fullName} · ${role.label}'
          : role.label;
    });
  }

  Future<void> _switchRole() async {
    await SkillMatrixSessionService.instance.clearRole();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(Routes.skillMatrixRole);
  }

  void _goApps() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.appChooser,
      (route) => false,
    );
  }

  List<NavigationDestination> get _managerDestinations {
    return const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Overview',
      ),
      NavigationDestination(
        icon: Icon(Icons.rate_review_outlined),
        selectedIcon: Icon(Icons.rate_review),
        label: 'Reviews',
      ),
      NavigationDestination(
        icon: Icon(Icons.grid_on_outlined),
        selectedIcon: Icon(Icons.grid_on_rounded),
        label: 'Matrix',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ];
  }

  List<NavigationDestination> get _workerDestinations {
    return const [
      NavigationDestination(
        icon: Icon(Icons.fact_check_outlined),
        selectedIcon: Icon(Icons.fact_check),
        label: 'Assessment',
      ),
      NavigationDestination(
        icon: Icon(Icons.school_outlined),
        selectedIcon: Icon(Icons.school),
        label: 'Training',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ];
  }

  List<String> get _managerTitles {
    return const [
      'Team overview',
      'Team assessments',
      'Skill matrix',
      'Profile',
    ];
  }

  List<String> get _workerTitles {
    return const ['Self-Assessment', 'Gaps & Trainings', 'Profile'];
  }

  List<NavigationDestination> get _etAdminDestinations {
    return const [
      NavigationDestination(
        icon: Icon(Icons.badge_outlined),
        selectedIcon: Icon(Icons.badge),
        label: 'Employees',
      ),
      NavigationDestination(
        icon: Icon(Icons.tune_outlined),
        selectedIcon: Icon(Icons.tune),
        label: 'Skills',
      ),
      NavigationDestination(
        icon: Icon(Icons.school_outlined),
        selectedIcon: Icon(Icons.school),
        label: 'Training',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ];
  }

  List<String> get _etAdminTitles {
    return const [
      'Employee Master',
      'Skill & Requirement Setup',
      'Log Training Session',
      'Profile',
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_role == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: SkillMatrixTheme.brandPrimary),
        ),
      );
    }

    final isManager = _role == SkillMatrixRole.lineManager;
    final isEtAdmin = _role == SkillMatrixRole.etAdmin;
    final titles = isEtAdmin
        ? _etAdminTitles
        : isManager
            ? _managerTitles
            : _workerTitles;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titles[_index],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (_userSubtitle != null)
              Text(
                _userSubtitle!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
          ],
        ),
        backgroundColor: SkillMatrixTheme.brandPrimary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.apps_rounded),
          tooltip: 'Apps',
          onPressed: _goApps,
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'role') _switchRole();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'role',
                child: Text('Switch role (${_role!.label})'),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: isEtAdmin
            ? const [
                SkillMatrixEtEmployeeMasterScreen(),
                SkillMatrixEtSkillSetupScreen(),
                SkillMatrixEtLogTrainingScreen(),
                SkillMatrixEtProfileScreen(),
              ]
            : isManager
                ? [
                    SkillMatrixManagerHomeScreen(
                      onReview: _openReview,
                      onOpenSkillMatrix: () => setState(() => _index = 2),
                      onOpenAllAssessments: () => setState(() => _index = 1),
                    ),
                    SkillMatrixManagerAssessmentsPanel(onReview: _openReview),
                    const SkillMatrixManagerSkillMatrixPanel(),
                    const SkillMatrixManagerProfileScreen(),
                  ]
                : [
                    SkillMatrixWorkerSelfAssessmentScreen(
                      key: _workerAssessmentKey,
                    ),
                    const SkillMatrixWorkerGapsScreen(),
                    const SkillMatrixWorkerProfileScreen(),
                  ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (!isEtAdmin && !isManager && i == 0) {
            _workerAssessmentKey.currentState?.refresh();
          }
        },
        destinations: isEtAdmin
            ? _etAdminDestinations
            : isManager
                ? _managerDestinations
                : _workerDestinations,
        indicatorColor: SkillMatrixTheme.brandTint,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 68,
        animationDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  void _openReview(String employeeId, String userId) {
    Navigator.of(context).pushNamed(
      Routes.skillMatrixManagerReview,
      arguments: {'employeeId': employeeId, 'userId': userId},
    );
  }
}
