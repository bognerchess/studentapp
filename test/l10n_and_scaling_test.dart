// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers/pump_app.dart';

/// Every location of the shell, to be walked through in each configuration.
final List<String> allLocations = [
  AppRoutes.games,
  AppRoutes.game('abc'),
  AppRoutes.gameReview('abc'),
  AppRoutes.newGame,
  AppRoutes.newGameEntry,
  AppRoutes.newGameImport,
  AppRoutes.newGameMetadata,
  AppRoutes.settings,
  AppRoutes.settingsAbout,
  AppRoutes.settingsAccount,
  AppRoutes.settingsLegal,
  AppRoutes.consentAi,
  AppRoutes.legalDocument('privacy'),
  AppRoutes.legalDocument('terms'),
  '/does/not/exist',
];

void main() {
  group('languages', () {
    testWidgets('English system language renders English', (tester) async {
      await pumpApp(tester);

      expect(find.text('No games yet'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('German system language renders German on every tab', (
      tester,
    ) async {
      await pumpApp(tester, locale: const Locale('de', 'CH'));

      expect(find.text('Noch keine Partien'), findsOneWidget);
      expect(find.text('No games yet'), findsNothing);

      await tester.tap(find.text('Neue Partie').last);
      await tester.pumpAndSettle();
      expect(find.text('Züge eingeben'), findsOneWidget);
      expect(find.text('PGN importieren'), findsOneWidget);

      await tester.tap(find.text('Einstellungen'));
      await tester.pumpAndSettle();
      expect(find.text('Konto'), findsOneWidget);
      expect(find.text('Datenschutz und Bedingungen'), findsOneWidget);
      expect(find.text('Über die App und Lizenzen'), findsOneWidget);
    });

    testWidgets('German also reaches the framework strings', (tester) async {
      await pumpApp(tester, locale: const Locale('de'));
      routerOf(tester).go(AppRoutes.settingsAbout);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Zurück'), findsOneWidget);
    });

    testWidgets('any other system language falls back to English', (
      tester,
    ) async {
      await pumpApp(tester, locale: const Locale('fr', 'FR'));

      expect(find.text('No games yet'), findsOneWidget);
      expect(
        Localizations.localeOf(tester.element(find.text('No games yet'))),
        const Locale('en'),
      );
    });
  });

  group('text scale 1.3 on the smallest iPhone does not overflow', () {
    // A RenderFlex overflow is reported as a FlutterError, which fails the
    // test on its own; takeException makes the intent explicit.
    for (final locale in const [Locale('en'), Locale('de')]) {
      for (final brightness in Brightness.values) {
        testWidgets('$locale, ${brightness.name}', (tester) async {
          await pumpApp(
            tester,
            locale: locale,
            brightness: brightness,
            textScale: 1.3,
            screen: kIphoneSe,
          );

          for (final location in allLocations) {
            routerOf(tester).go(location);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: location);
          }
        });
      }
    }
  });
}
