// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/links/link_target.dart';
import 'package:bogner_chess/core/ui/widgets/not_found_screen.dart';
import 'package:bogner_chess/features/import/domain/pending_import.dart';
import 'package:bogner_chess/features/import/ui/import_screen.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

const _s = kAppLinkScheme;

/// The router's own net for a custom-scheme URI that reaches it without
/// passing IncomingLinkService, for example from the platform's route
/// channel should Flutter's deep linking ever be switched on again.
void main() {
  group('externalLinkRedirect', () {
    test('app links map to their location', () {
      expect(
        externalLinkRedirect(Uri.parse('$_s://games/abc/review')),
        '/games/abc/review',
      );
      expect(
        externalLinkRedirect(Uri.parse('$_s://new/import')),
        '/new/import',
      );
    });

    test('the OIDC redirect is no place: the start location', () {
      expect(
        externalLinkRedirect(Uri.parse('$_s:/oauthredirect?code=abc')),
        AppRoutes.initial,
      );
    });

    test('everything else is unknown', () {
      for (final link in [
        '$_s://nowhere',
        '$_s://sign-in',
        '$_s://shared-pgn',
        'https://evil.example/games/abc',
        'file:///etc/passwd',
      ]) {
        expect(externalLinkRedirect(Uri.parse(link)), isNull, reason: link);
      }
    });
  });

  group('through the router', () {
    testWidgets('go with a custom-scheme link', (tester) async {
      await pumpApp(tester);
      routerOf(tester).go('$_s://games/abc/review');
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/games/abc/review');

      // Back works: the stack below the review was built.
      routerOf(tester).pop();
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/games/abc');
    });

    testWidgets('a link pushed by the platform', (tester) async {
      await pumpApp(tester);
      await routerOf(tester).routeInformationProvider.didPushRouteInformation(
        RouteInformation(uri: Uri.parse('$_s://settings')),
      );
      await tester.pumpAndSettle();
      expect(locationOf(tester), AppRoutes.settings);
    });

    testWidgets('signed out it still goes through sign-in', (tester) async {
      await pumpApp(tester, auth: const SignedOut());
      routerOf(tester).go('$_s://games/abc/review');
      await tester.pumpAndSettle();
      expect(locationOf(tester), AppRoutes.signIn);

      (containerOf(tester).read(authStateProvider.notifier) as TestAuthNotifier)
          .set(const SignedIn(kFakeAuthSub));
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/games/abc/review');
    });

    testWidgets('an unknown link shows the not-found screen', (tester) async {
      await pumpApp(tester);
      routerOf(tester).go('$_s://nowhere/at/all');
      await tester.pumpAndSettle();
      expect(find.byType(NotFoundScreen), findsOneWidget);
    });

    testWidgets('the OIDC redirect does not show the not-found screen', (
      tester,
    ) async {
      await pumpApp(tester);
      routerOf(tester).go('$_s:/oauthredirect?code=abc&state=def');
      await tester.pumpAndSettle();
      expect(find.byType(NotFoundScreen), findsNothing);
      expect(locationOf(tester), AppRoutes.initial);
    });
  });

  group('a pending import and the import route', () {
    testWidgets('the text offered before navigating is filled in', (
      tester,
    ) async {
      await pumpApp(tester);
      containerOf(tester)
          .read(pendingImportProvider.notifier)
          .offer('1. e4 e5 2. Nf3 Nc6 1-0');
      routerOf(tester).go(AppRoutes.newGameImport);
      await tester.pumpAndSettle();

      expect(find.byType(ImportScreen), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('import-field')),
      );
      expect(field.controller!.text, '1. e4 e5 2. Nf3 Nc6 1-0');
      expect(find.byKey(const ValueKey('import-preview')), findsOneWidget);
      expect(containerOf(tester).read(pendingImportProvider), isNull);
    });
  });
}
