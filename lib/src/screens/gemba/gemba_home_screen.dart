import 'package:flutter/material.dart';
import '../../theme/gemba_colors.dart';

import '../../../routes.dart';
import '../../services/gemba_auth_service.dart';
import '../../services/gemba_observations_service.dart';
import '../../services/gemba_session_service.dart';
import 'gemba_add_observation_screen.dart';
import 'gemba_dashboard_screen.dart';
import 'gemba_observations_screen.dart';
import 'gemba_profile_screen.dart';
import 'gemba_reports_screen.dart';

/// Gemba shell: Home · Add · Observations · Reports · Profile
class GembaHomeScreen extends StatefulWidget {
  const GembaHomeScreen({super.key});

  @override
  State<GembaHomeScreen> createState() => _GembaHomeScreenState();
}

class _GembaHomeScreenState extends State<GembaHomeScreen> {
  int _index = 0;
  bool _ready = false;
  final _observationsFilter = ValueNotifier(GembaObservationFilter.all);

  static const _titles = [
    'Home',
    'Add Observation',
    'Observations',
    'Reports',
    'Profile',
  ];

  static const _profileIndex = 4;

  @override
  void initState() {
    super.initState();
    _ensureSession();
  }

  @override
  void dispose() {
    _observationsFilter.dispose();
    super.dispose();
  }

  Future<void> _ensureSession() async {
    final session = await GembaSessionService.instance.loadSession();
    if (!mounted) return;
    if (session == null) {
      Navigator.of(context).pushReplacementNamed(Routes.gembaLogin);
      return;
    }
    setState(() => _ready = true);
  }

  Future<void> _signOut() async {
    await GembaAuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.appChooser,
      (route) => false,
    );
  }

  void _goApps() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.appChooser,
      (route) => false,
    );
  }

  void _openObservations(GembaObservationFilter filter) {
    _observationsFilter.value = filter;
    setState(() => _index = 2);
  }

  void _openAddObservation() {
    setState(() => _index = 1);
  }

  void _onTabSelected(int index) {
    setState(() => _index = index);
    if (index == 0 || index == 2 || index == 3) {
      GembaObservationsService.instance.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        backgroundColor: GembaColors.brandPrimary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.apps_rounded),
          tooltip: 'Apps',
          onPressed: _goApps,
        ),
        actions: [
          if (_index == _profileIndex)
            IconButton(
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Sign out',
            ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          GembaDashboardScreen(
            onNavigateToObservations: _openObservations,
            onNavigateToAdd: _openAddObservation,
          ),
          GembaAddObservationScreen(
            onObservationSubmitted: () =>
                _openObservations(GembaObservationFilter.all),
          ),
          GembaObservationsScreen(filterNotifier: _observationsFilter),
          const GembaReportsScreen(),
          const GembaProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? GembaColors.brandPrimary
                  : const Color(0xFF64748B),
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _onTabSelected,
          backgroundColor: Colors.white,
          indicatorColor: GembaColors.brandTint,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(
                Icons.dashboard_rounded,
                color: GembaColors.brandPrimary,
              ),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline_rounded),
              selectedIcon: Icon(
                Icons.add_circle_rounded,
                color: GembaColors.brandPrimary,
              ),
              label: 'Add',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt_rounded),
              selectedIcon: Icon(
                Icons.list_alt_rounded,
                color: GembaColors.brandPrimary,
              ),
              label: 'Observations',
            ),
            NavigationDestination(
              icon: Icon(Icons.assessment_outlined),
              selectedIcon: Icon(
                Icons.assessment_rounded,
                color: GembaColors.brandPrimary,
              ),
              label: 'Reports',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(
                Icons.person_rounded,
                color: GembaColors.brandPrimary,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
