// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The three-tab frame of the app: Games, New game, Settings. Each tab keeps
/// its own navigation stack; tapping the active tab pops it to its root.
class TabShell extends StatelessWidget {
  const TabShell({super.key, required this.navigationShell, this.banner});

  final StatefulNavigationShell navigationShell;

  /// A strip between the tab's content and the navigation bar, on every tab:
  /// the submit queue's status. It takes no room while it has nothing to say.
  final Widget? banner;

  /// Branch indices, in the order of the destinations below and of the
  /// branches in `router.dart`.
  static const int gamesTab = 0;
  static const int newGameTab = 1;
  static const int settingsTab = 2;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: banner == null
          ? navigationShell
          : Column(
              children: [
                Expanded(child: navigationShell),
                banner!,
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.library_books_outlined),
            selectedIcon: const Icon(Icons.library_books),
            label: l10n.tabGames,
          ),
          NavigationDestination(
            icon: const Icon(Icons.add_circle_outline),
            selectedIcon: const Icon(Icons.add_circle),
            label: l10n.tabNewGame,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.tabSettings,
          ),
        ],
      ),
    );
  }
}
