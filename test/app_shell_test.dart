// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/features/entry/ui/entry_screen.dart';
import 'package:bogner_chess/features/import/ui/import_screen.dart';
import 'package:bogner_chess/features/legal/ui/about_screen.dart';
import 'package:bogner_chess/features/library/ui/library_screen.dart';
import 'package:bogner_chess/features/new_game/ui/new_game_screen.dart';
import 'package:bogner_chess/features/settings/ui/settings_screen.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers/pump_app.dart';

void main() {
  group('tabs', () {
    testWidgets('the app opens on the games tab', (tester) async {
      await pumpApp(tester);

      expect(locationOf(tester), AppRoutes.games);
      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(find.text('No games yet'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
    });

    testWidgets('tapping a tab switches to it', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('New game').last);
      await tester.pumpAndSettle();
      expect(locationOf(tester), AppRoutes.newGame);
      expect(find.byType(NewGameScreen), findsOneWidget);
      expect(find.text('Enter moves'), findsOneWidget);
      expect(find.text('Import PGN'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(locationOf(tester), AppRoutes.settings);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Version 1.2.3 (45)'), findsOneWidget);

      await tester.tap(find.text('Games').last);
      await tester.pumpAndSettle();
      expect(locationOf(tester), AppRoutes.games);
    });

    testWidgets('the empty library leads to the new-game tab', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'New game'));
      await tester.pumpAndSettle();

      expect(locationOf(tester), AppRoutes.newGame);
    });

    testWidgets('entry and import open above the tab bar and pop back', (
      tester,
    ) async {
      await pumpApp(tester);
      routerOf(tester).go(AppRoutes.newGame);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('new-game-entry')));
      await tester.pumpAndSettle();
      expect(locationOf(tester), AppRoutes.newGameEntry);
      expect(find.byType(EntryScreen), findsOneWidget);
      expect(find.byType(NavigationBar).hitTestable(), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(locationOf(tester), AppRoutes.newGame);

      await tester.tap(find.byKey(const ValueKey('new-game-import')));
      await tester.pumpAndSettle();
      expect(locationOf(tester), AppRoutes.newGameImport);
      expect(find.byType(ImportScreen), findsOneWidget);
    });

    testWidgets(
      'settings pages stay inside the tab; the tab pops to its root',
      (tester) async {
        await pumpApp(tester);
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('About and licences'));
        await tester.pumpAndSettle();
        expect(locationOf(tester), AppRoutes.settingsAbout);
        expect(find.byType(AboutScreen), findsOneWidget);
        expect(find.byType(NavigationBar).hitTestable(), findsOneWidget);

        // Leaving and coming back keeps the tab's stack ...
        await tester.tap(find.text('Games'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(locationOf(tester), AppRoutes.settingsAbout);

        // ... and tapping the active tab pops it.
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(locationOf(tester), AppRoutes.settings);
      },
    );
  });

  group('env banner', () {
    testWidgets('names the environment when it is not production', (
      tester,
    ) async {
      await pumpApp(tester);

      final banner = tester.widget<Banner>(find.byType(Banner));
      expect(banner.message, 'FAKE');
    });

    testWidgets('is absent in production', (tester) async {
      await pumpApp(
        tester,
        env: testEnv(envName: 'prod', authMode: AuthMode.real),
      );

      expect(find.byType(Banner), findsNothing);
    });
  });

  group('themes', () {
    testWidgets('light system setting builds the light theme', (tester) async {
      await pumpApp(tester);

      final theme = Theme.of(tester.element(find.byType(LibraryScreen)));
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
      expect(theme.extension<AppColors>(), AppColors.light);
    });

    testWidgets('dark system setting builds the dark theme on every tab', (
      tester,
    ) async {
      await pumpApp(tester, brightness: Brightness.dark);

      final theme = Theme.of(tester.element(find.byType(LibraryScreen)));
      expect(theme.brightness, Brightness.dark);
      expect(theme.extension<AppColors>(), AppColors.dark);

      for (final route in [AppRoutes.newGame, AppRoutes.settings]) {
        routerOf(tester).go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
