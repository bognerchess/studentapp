// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/auth/auth_providers.dart';
import 'package:bogner_chess/core/auth/auth_repository.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/auth/fake_auth_repository.dart';
import 'package:bogner_chess/features/auth/domain/sign_in_idp.dart';
import 'package:bogner_chess/features/auth/ui/sign_in_screen.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository(signedIn: false));
  tearDown(() => repository.dispose());

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    Brightness brightness = Brightness.light,
    double textScale = 1.0,
    Size screen = kIphone17Pro,
    List<SignInIdp>? idps,
  }) => pumpApp(
    tester,
    locale: locale,
    brightness: brightness,
    textScale: textScale,
    screen: screen,
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      if (idps != null) signInIdpsProvider.overrideWithValue(idps),
    ],
  );

  Finder byId(String identifier) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.identifier == identifier,
    description: 'identifier $identifier',
  );

  Future<void> tap(WidgetTester tester, String identifier) async {
    await tester.ensureVisible(byId(identifier));
    await tester.tap(byId(identifier));
    await tester.pumpAndSettle();
  }

  testWidgets('signed out, the app opens the sign-in screen', (tester) async {
    await pump(tester);

    expect(locationOf(tester), AppRoutes.signIn);
    expect(find.text('Bogner Chess'), findsOneWidget);
    expect(find.textContaining('coach comments'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.textContaining('bognerchess.com'), findsOneWidget);
    expect(find.text('E-mail not confirmed yet?'), findsOneWidget);
    // No tab bar on the public screen.
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('Apple comes first, above Google and the e-mail buttons', (
    tester,
  ) async {
    await pump(tester);
    double top(String id) => tester.getTopLeft(byId(id)).dy;
    expect(top(SignInIds.apple), lessThan(top(SignInIds.google)));
    expect(top(SignInIds.google), lessThan(top(SignInIds.primary)));
    expect(top(SignInIds.primary), lessThan(top(SignInIds.register)));
  });

  group('every button calls the right thing', () {
    const cases = {
      SignInIds.primary: (register: false, idpHint: null),
      SignInIds.register: (register: true, idpHint: null),
      SignInIds.apple: (register: false, idpHint: 'apple'),
      SignInIds.google: (register: false, idpHint: 'google'),
    };
    for (final MapEntry(key: id, value: call) in cases.entries) {
      testWidgets(id, (tester) async {
        await pump(tester);
        await tap(tester, id);
        expect(repository.signInCalls, [call]);
        // Signed in: the router has left the screen.
        expect(locationOf(tester), AppRoutes.games);
      });
    }
  });

  testWidgets('after signing in the router continues to "from"', (
    tester,
  ) async {
    await pump(tester);
    routerOf(tester).go(AppRoutes.settingsAbout);
    await tester.pumpAndSettle();
    expect(locationOf(tester), AppRoutes.signIn);

    await tap(tester, SignInIds.primary);

    expect(locationOf(tester), AppRoutes.settingsAbout);
  });

  testWidgets('the provider buttons are configurable', (tester) async {
    await pump(tester, idps: const [SignInIdp.google]);
    expect(byId(SignInIds.apple), findsNothing);
    expect(byId(SignInIds.google), findsOneWidget);
    expect(find.text('or'), findsOneWidget);
  });

  testWidgets('without provider buttons there is no divider either', (
    tester,
  ) async {
    await pump(tester, idps: const []);
    expect(byId(SignInIds.apple), findsNothing);
    expect(byId(SignInIds.google), findsNothing);
    expect(find.text('or'), findsNothing);
    expect(byId(SignInIds.primary), findsOneWidget);
  });

  test('AUTH_IDPS parsing: Apple first, unknown names ignored', () {
    expect(SignInIdp.parseList('apple,google'), [
      SignInIdp.apple,
      SignInIdp.google,
    ]);
    expect(SignInIdp.parseList(' google , apple, google'), [
      SignInIdp.apple,
      SignInIdp.google,
    ]);
    expect(SignInIdp.parseList('google,facebook'), [SignInIdp.google]);
    expect(SignInIdp.parseList(''), isEmpty);
  });

  testWidgets('while the sheet is open the buttons are disabled', (
    tester,
  ) async {
    repository.signInDelay = const Duration(seconds: 2);
    await pump(tester);

    await tester.tap(byId(SignInIds.primary));
    await tester.pump();

    expect(find.text('Waiting for the sign-in page …'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    for (final id in [
      SignInIds.primary,
      SignInIds.register,
      SignInIds.apple,
      SignInIds.google,
    ]) {
      final button = tester.widget<ButtonStyleButton>(
        find.descendant(
          of: byId(id),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      );
      expect(button.enabled, isFalse, reason: id);
    }
    // A tap now starts nothing.
    await tester.tap(byId(SignInIds.google), warnIfMissed: false);
    expect(repository.signInCalls, hasLength(1));

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(locationOf(tester), AppRoutes.games);
  });

  testWidgets('closing the sheet shows no error and no snackbar', (
    tester,
  ) async {
    // What AppAuthRepository does on a cancel: complete, state unchanged.
    final cancelling = _CancellingRepository();
    await pumpApp(
      tester,
      overrides: [authRepositoryProvider.overrideWithValue(cancelling)],
    );

    await tap(tester, SignInIds.primary);

    expect(cancelling.calls, 1);
    expect(locationOf(tester), AppRoutes.signIn);
    expect(byId(SignInIds.error), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Confirm your e-mail address'), findsNothing);
    // And the buttons work again.
    await tap(tester, SignInIds.primary);
    expect(cancelling.calls, 2);
  });

  testWidgets('offline: a message, and the next attempt clears it', (
    tester,
  ) async {
    repository.signInError = const AuthException(AuthErrorKind.network);
    await pump(tester);

    await tap(tester, SignInIds.apple);

    expect(locationOf(tester), AppRoutes.signIn);
    expect(find.text('No connection'), findsOneWidget);
    expect(find.textContaining('internet connection'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    repository.signInError = null;
    await tap(tester, SignInIds.apple);
    expect(locationOf(tester), AppRoutes.games);
  });

  testWidgets('a failed "Create account" does not talk about a mail', (
    tester,
  ) async {
    repository.signInError = const AuthException(AuthErrorKind.network);
    await pump(tester);
    await tap(tester, SignInIds.register);
    expect(find.text('No connection'), findsOneWidget);
    expect(find.text('Confirm your e-mail address'), findsNothing);
  });

  testWidgets('server error: the generic message', (tester) async {
    repository.signInError = const AuthException(AuthErrorKind.server);
    await pump(tester);
    await tap(tester, SignInIds.primary);
    expect(find.text('Sign-in did not work'), findsOneWidget);
    expect(find.text('No connection'), findsNothing);
  });

  group('e-mail not confirmed yet', () {
    testWidgets('the help opens on request and signs in normally', (
      tester,
    ) async {
      await pump(tester);
      expect(byId(SignInIds.verified), findsNothing);

      await tap(tester, SignInIds.verifyToggle);

      expect(find.text('Confirm your e-mail address'), findsOneWidget);
      expect(find.textContaining('confirmation link'), findsOneWidget);
      expect(byId(SignInIds.verifyToggle), findsNothing);

      await tap(tester, SignInIds.verified);
      expect(repository.signInCalls, [(register: false, idpHint: null)]);
      expect(locationOf(tester), AppRoutes.games);
    });

    testWidgets('coming back from "Create account" without a session opens '
        'the help by itself', (tester) async {
      final cancelling = _CancellingRepository();
      await pumpApp(
        tester,
        overrides: [authRepositoryProvider.overrideWithValue(cancelling)],
      );

      await tap(tester, SignInIds.register);

      expect(find.text('Confirm your e-mail address'), findsOneWidget);
      expect(byId(SignInIds.verified), findsOneWidget);
    });
  });

  group('accessibility', () {
    testWidgets('buttons have labels, identifiers and are tappable', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      final labels = {
        SignInIds.apple: 'Continue with Apple',
        SignInIds.google: 'Continue with Google',
        SignInIds.primary: 'Sign in',
        SignInIds.register: 'Create account',
        SignInIds.verifyToggle: 'E-mail not confirmed yet?',
      };
      for (final MapEntry(key: id, value: label) in labels.entries) {
        // One node, as the platform sees it, carries all of it.
        final data = tester
            .getSemantics(
              find.descendant(of: byId(id), matching: find.text(label)),
            )
            .getSemanticsData();
        expect(data.identifier, id);
        expect(data.label, label);
        expect(data.hasAction(SemanticsAction.tap), isTrue, reason: id);
        expect(data.flagsCollection.isButton, isTrue, reason: id);
      }
      expect(
        tester.getSemantics(find.text('Bogner Chess')).flagsCollection.isHeader,
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('meets the tap target and contrast guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      for (final brightness in Brightness.values) {
        await pump(tester, brightness: brightness);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
      handle.dispose();
    });
  });

  group('German, text scale 1.3, 375 x 667, light and dark', () {
    for (final locale in const [Locale('en'), Locale('de')]) {
      for (final brightness in Brightness.values) {
        testWidgets('$locale ${brightness.name}: every state fits', (
          tester,
        ) async {
          repository.signInError = const AuthException(AuthErrorKind.network);
          await pump(
            tester,
            locale: locale,
            brightness: brightness,
            textScale: 1.3,
            screen: kIphoneSe,
          );
          expect(tester.takeException(), isNull);
          expect(
            Theme.of(tester.element(find.byType(SignInScreen))).brightness,
            brightness,
          );

          // Error banner plus the help card: the tallest the screen gets.
          await tap(tester, SignInIds.verifyToggle);
          await tap(tester, SignInIds.register);
          expect(byId(SignInIds.error), findsOneWidget);
          expect(byId(SignInIds.verified), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Everything can be scrolled into view.
          await tester.ensureVisible(byId(SignInIds.verified));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('German strings', (tester) async {
      repository.signInError = const AuthException(AuthErrorKind.network);
      await pump(tester, locale: const Locale('de', 'CH'));

      expect(find.text('Mit Apple fortfahren'), findsOneWidget);
      expect(find.text('Mit Google fortfahren'), findsOneWidget);
      expect(find.text('oder'), findsOneWidget);
      expect(find.text('Anmelden'), findsOneWidget);
      expect(find.text('Konto erstellen'), findsOneWidget);
      expect(find.textContaining('bognerchess.com'), findsOneWidget);

      await tap(tester, SignInIds.verifyToggle);
      await tap(tester, SignInIds.register);
      expect(find.text('Keine Verbindung'), findsOneWidget);
      expect(find.text('Bestätige deine E-Mail-Adresse'), findsOneWidget);
      expect(find.text('Ich habe bestätigt – anmelden'), findsOneWidget);
    });
  });
}

/// Behaves like the real repository when the user closes the browser sheet.
class _CancellingRepository implements AuthRepository {
  int calls = 0;

  @override
  AuthState get state => const SignedOut();

  @override
  Stream<AuthState> get states => const Stream.empty();

  @override
  Future<void> signIn({bool register = false, String? idpHint}) async =>
      calls++;

  @override
  Future<void> restore() async {}

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<String?> forceRefresh({String? rejectedToken}) async => null;

  @override
  Future<void> signOut() async {}
}
