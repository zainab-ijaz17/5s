import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation/role_navigation.dart';
import '../navigation/role_section.dart';
import '../state/app_state.dart';

class RoleBottomNav extends StatelessWidget {
  const RoleBottomNav({
    super.key,
    required this.current,
  });

  final RoleSection current;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        if (!RoleNavigation.showSwitcherFor(appState)) {
          return const SizedBox.shrink();
        }

        final sections = RoleNavigation.sectionsFor(appState);
        final selectedIndex = sections.indexOf(current);
        if (selectedIndex < 0) return const SizedBox.shrink();

        return NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            RoleNavigation.navigate(
              context,
              sections[index],
              current: current,
            );
          },
          destinations: [
            for (final section in sections)
              NavigationDestination(
                icon: Icon(RoleNavigation.iconFor(section)),
                selectedIcon: Icon(RoleNavigation.iconFor(section)),
                label: RoleNavigation.labelFor(section),
              ),
          ],
        );
      },
    );
  }
}
