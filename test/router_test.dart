// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/ui/widgets/not_found_screen.dart';
import 'package:bogner_chess/features/account/ui/account_screen.dart';
import 'package:bogner_chess/features/auth/ui/sign_in_screen.dart';
import 'package:bogner_chess/features/consent/ui/ai_consent_screen.dart';
import 'package:bogner_chess/features/legal/ui/legal_screen.dart';
import 'package:bogner_chess/features/library/ui/game_screen.dart';
import 'package:bogner_chess/features/library/ui/library_screen.dart';
import 'package:bogner_chess/features/review/ui/review_screen.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  group('authRedirect', () {
    String? redirect(AuthState auth, String location) =>
        authRedirect(auth: auth, uri: Uri.parse(location));

    test('signed out: everything but sign-in goes to sign-in', () {
      expect(redirect(const SignedOut(), '/sign-in'), isNull);
      expect(redirect(const SignedOut(), '/games'), '/sign-in?from=%2Fgames');
      expect(
        redirect(const SignedOut(), '/games/abc/review'),
        '/sign-in?from=%2Fgames%2Fabc%2Freview',
      );
      expect(
        redirect(const SignedOut(), '/consent/ai'),
        startsWith('/sign-in'),
      );
    });

    test('signed in: sign-in leads back to the remembered location', () {
      const auth = SignedIn('sub-1');
      expect(redirect(auth, '/games'), isNull);
      expect(redirect(auth, '/sign-in'), '/games');
      expect(
        redirect(auth, '/sign-in?from=%2Fgames%2Fabc%2Freview'),
        '/games/abc/review',
      );
    });

    test('signed in: a remembered location outside the app is ignored', () {
      const auth = SignedIn('sub-1');
      expect(redirect(auth, '/sign-in?from=https%3A%2F%2Fevil.test'), '/games');
      expect(redirect(auth, '/sign-in?from=%2F%2Fevil.test'), '/games');
    });
  });

  group('auth state seam', () {
    testWidgets('fake auth starts signed in', (tester) async {
      await pumpApp(tester);

      // Since WP-25 the fake user also has an e-mail address and a name.
      expect(
        containerOf(tester).read(authStateProvider),
        isA<SignedIn>().having((s) => s.sub, 'sub', kFakeAuthSub),
      );
      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets('real auth starts signed out, on the sign-in screen', (
      tester,
    ) async {
      await pumpApp(
        tester,
        env: testEnv(envName: 'dev', authMode: AuthMode.real),
      );

      expect(containerOf(tester).read(authStateProvider), const SignedOut());
      expect(locationOf(tester), AppRoutes.signIn);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(LibraryScreen), findsNothing);
    });
  });

  group('redirects', () {
    testWidgets('a signed-out deep link arrives after signing in', (
      tester,
    ) async {
      await pumpApp(tester, auth: const SignedOut());
      routerOf(tester).go(AppRoutes.gameReview('abc'));
      await tester.pumpAndSettle();
      expect(locationOf(tester), AppRoutes.signIn);

      final auth = containerOf(
        tester,
      ).read(authStateProvider.notifier) as TestAuthNotifier;
      auth.set(const SignedIn('sub-1'));
      await tester.pumpAndSettle();

      expect(locationOf(tester), '/games/abc/review');
      expect(find.byType(ReviewScreen), findsOneWidget);
    });

    testWidgets('signing out leaves wherever the user was', (tester) async {
      await pumpApp(tester, auth: const SignedIn('sub-1'));
      routerOf(tester).go(AppRoutes.settingsAccount);
      await tester.pumpAndSettle();
      expect(find.byType(AccountScreen), findsOneWidget);

      final auth = containerOf(
        tester,
      ).read(authStateProvider.notifier) as TestAuthNotifier;
      auth.set(const SignedOut());
      await tester.pumpAndSettle();

      expect(locationOf(tester), AppRoutes.signIn);
      expect(find.byType(SignInScreen), findsOneWidget);
    });
  });

  group('deep links', () {
    testWidgets('/games/:id/review stacks review on game on library', (
      tester,
    ) async {
      await pumpApp(tester);
      routerOf(tester).go(AppRoutes.gameReview('game-42'));
      await tester.pumpAndSettle();

      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(
        tester.widget<ReviewScreen>(find.byType(ReviewScreen)).gameId,
        'game-42',
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/games/game-42');
      expect(find.byType(GameScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(locationOf(tester), AppRoutes.games);
      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets('game ids are percent-encoded into the path', (tester) async {
      await pumpApp(tester);
      routerOf(tester).go(AppRoutes.game('a/b c'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<GameScreen>(find.byType(GameScreen)).gameId,
        'a/b c',
      );
    });

    testWidgets('every placeholder route resolves', (tester) async {
      await pumpApp(tester);
      final expected = <String, Type>{
        AppRoutes.consentAi: AiConsentScreen,
        AppRoutes.settingsAccount: AccountScreen,
        AppRoutes.settingsLegal: LegalScreen,
      };
      for (final MapEntry(key: location, value: screen) in expected.entries) {
        routerOf(tester).go(location);
        await tester.pumpAndSettle();
        expect(find.byType(screen), findsOneWidget, reason: location);
      }
    });

    testWidgets('named routes resolve to the same paths', (tester) async {
      await pumpApp(tester);
      final router = routerOf(tester);

      expect(
        router.namedLocation(
          AppRouteNames.gameReview,
          pathParameters: {AppRoutes.gameIdParam: 'abc'},
        ),
        AppRoutes.gameReview('abc'),
      );
      expect(
        router.namedLocation(AppRouteNames.newGameImport),
        AppRoutes.newGameImport,
      );
      expect(
        router.namedLocation(AppRouteNames.settingsLegal),
        AppRoutes.settingsLegal,
      );
    });

    testWidgets('/ opens the games tab', (tester) async {
      await pumpApp(tester);
      routerOf(tester).go('/');
      await tester.pumpAndSettle();

      expect(locationOf(tester), AppRoutes.games);
    });

    testWidgets('an unknown location shows the not-found screen', (
      tester,
    ) async {
      await pumpApp(tester);
      routerOf(tester).go('/does/not/exist');
      await tester.pumpAndSettle();
      expect(find.byType(NotFoundScreen), findsOneWidget);

      await tester.tap(find.text('Go to my games'));
      await tester.pumpAndSettle();
      expect(locationOf(tester), AppRoutes.games);
    });
  });
}
