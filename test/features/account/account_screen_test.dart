// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:io';

import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/consent/consent_state.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/features/account/domain/account_deletion.dart';
import 'package:bogner_chess/features/account/ui/account_deleted_notice.dart';
import 'package:bogner_chess/features/account/ui/account_screen.dart';
import 'package:bogner_chess/features/account/ui/delete_account_screen.dart';
import 'package:bogner_chess/features/auth/ui/sign_in_screen.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/account_harness.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_screen.dart';

Future<PumpedScreen> _pumpAccount(
  WidgetTester tester, {
  required List<Override> overrides,
  AuthState? auth,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Size screenSize = kIphone17Pro,
}) => pumpScreen(
  tester,
  const AccountScreen(),
  auth: auth,
  locale: locale,
  brightness: brightness,
  textScale: textScale,
  screenSize: screenSize,
  overrides: overrides,
);

/// The delete screen, under the app's "your account has been deleted" notice
/// — the one piece of `app.dart` this screen needs, and nothing else.
Future<PumpedScreen> _pumpDelete(
  WidgetTester tester, {
  required List<Override> overrides,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Size screenSize = kIphone17Pro,
}) => pumpScreen(
  tester,
  const AccountDeletedNotice(child: DeleteAccountScreen()),
  locale: locale,
  brightness: brightness,
  textScale: textScale,
  screenSize: screenSize,
  overrides: overrides,
);

Future<void> _typeAndConfirm(WidgetTester tester, String word) async {
  await tester.enterText(find.byKey(DeleteAccountScreen.fieldKey), word);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(DeleteAccountScreen.confirmKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(DeleteAccountScreen.confirmKey));
  await tester.pumpAndSettle();
}

/// Not `watchAll(...).first`: a drift stream needs the real event loop, which
/// a widget test does not run.
Future<List<Draft>> _draftsOf(AccountHarness h, String sub) async {
  final all = await h.database.select(h.database.drafts).get();
  return [
    for (final draft in all)
      if (draft.ownerSub == sub) draft,
  ];
}

Map<String, dynamic> _blocked(String reason) => {
  'data': {
    'deleteMyAccount': {
      'accountDeletion': null,
      'errors': [
        {
          '__typename': 'AccountDeletionBlockedError',
          'message': 'web_api_errors.account_deletion_blocked',
          'reason': reason,
        },
      ],
    },
  },
};

void main() {
  group('account screen', () {
    testWidgets('shows who is signed in and that it is the website account', (
      tester,
    ) async {
      final h = AccountHarness();
      await _pumpAccount(tester, overrides: h.overrides);

      expect(find.text('Fake User'), findsOneWidget);
      expect(find.text('fake.user@example.test'), findsOneWidget);
      expect(find.textContaining('bognerchess.com account'), findsWidgets);
      expect(find.textContaining('not confirmed'), findsNothing);
    });

    testWidgets('says when the e-mail address is not verified', (tester) async {
      final h = AccountHarness();
      await _pumpAccount(
        tester,
        auth: const SignedIn(
          's',
          email: 'new@example.test',
          emailVerified: false,
        ),
        overrides: h.overrides,
      );
      expect(find.text('new@example.test'), findsOneWidget);
      expect(find.textContaining('not confirmed yet'), findsOneWidget);
    });

    testWidgets('sign-out asks first; cancelling changes nothing', (
      tester,
    ) async {
      final h = AccountHarness();
      await _pumpAccount(tester, overrides: h.overrides);

      await tester.tap(find.byKey(AccountScreen.signOutKey));
      await tester.pumpAndSettle();
      expect(find.text('Sign out?'), findsOneWidget);
      expect(find.textContaining('Drafts you have not sent'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(h.auth.state, isA<SignedIn>());
      expect(find.byType(AccountScreen), findsOneWidget);
    });

    testWidgets('sign-out wipes the account but keeps drafts', (tester) async {
      final h = AccountHarness();
      await h.database.draftsDao.create(kFakeAuthSub, pgn: '1. e4');
      await h.database.kvDao.set('k', 'v', ownerSub: kFakeAuthSub);
      await _pumpAccount(tester, overrides: h.overrides);

      await tester.tap(find.byKey(AccountScreen.signOutKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AccountScreen.signOutConfirmKey));
      await tester.pumpAndSettle();

      expect(h.auth.state, const SignedOut());
      expect(await h.database.kvDao.get('k', ownerSub: kFakeAuthSub), isNull);
      expect(await _draftsOf(h, kFakeAuthSub), hasLength(1));
      expect(h.api.requestsOf('DeleteMyAccount'), isEmpty);
    });

    testWidgets('sign-out leads to the sign-in screen', (tester) async {
      // The whole app: the redirect is the router's, not the screen's.
      final h = AccountHarness();
      await pumpApp(tester, overrides: h.overrides);
      routerOf(tester).go(AppRoutes.settingsAccount);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AccountScreen.signOutKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AccountScreen.signOutConfirmKey));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(locationOf(tester), AppRoutes.signIn);
    });

    testWidgets('the delete button opens the delete screen', (tester) async {
      final h = AccountHarness();
      await _pumpAccount(tester, overrides: h.overrides);

      await tester.ensureVisible(find.byKey(AccountScreen.deleteKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AccountScreen.deleteKey));
      await tester.pumpAndSettle();
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
    });
  });

  group('account deletion', () {
    testWidgets('says that it is the bognerchess.com account, and what goes', (
      tester,
    ) async {
      final h = AccountHarness();
      await _pumpDelete(tester, overrides: h.overrides);

      expect(
        find.text('This deletes your bognerchess.com account'),
        findsOneWidget,
      );
      expect(find.textContaining('lose access to the website'), findsOneWidget);
      expect(find.text('What is deleted'), findsOneWidget);
      expect(find.text('What we have to keep'), findsOneWidget);
      expect(find.textContaining('Paid invoices'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);
    });

    testWidgets('the button works only once DELETE is typed', (tester) async {
      final h = AccountHarness();
      await _pumpDelete(tester, overrides: h.overrides);

      FilledButton button() =>
          tester.widget(find.byKey(DeleteAccountScreen.confirmKey));
      expect(button().onPressed, isNull);

      for (final wrong in ['delete my account', 'DELET', 'LÖSCHEN']) {
        await tester.enterText(find.byKey(DeleteAccountScreen.fieldKey), wrong);
        await tester.pump();
        expect(button().onPressed, isNull, reason: wrong);
      }
      for (final right in ['DELETE', 'delete', ' Delete ']) {
        await tester.enterText(find.byKey(DeleteAccountScreen.fieldKey), right);
        await tester.pump();
        expect(button().onPressed, isNotNull, reason: right);
      }
      expect(h.api.requestsOf('DeleteMyAccount'), isEmpty);
    });

    testWidgets('accepted: local data gone, signed out, confirmation', (
      tester,
    ) async {
      final h = AccountHarness();
      await h.database.draftsDao.create(kFakeAuthSub, pgn: '1. e4');
      await h.database.draftsDao.create('somebody-else', pgn: '1. d4');
      await h.database.kvDao.set(
        AnalyticsConsentNotifier.answerKey,
        'granted',
        ownerSub: kFakeAuthSub,
      );
      await _pumpDelete(tester, overrides: h.overrides);

      await _typeAndConfirm(tester, 'DELETE');

      // The token the backend expects, whatever the language of the UI.
      expect(h.api.requestsOf('DeleteMyAccount').single.variables['input'], {
        'confirmation': 'DELETE',
      });
      expect(h.analytics.names, ['account_deleted']);
      expect(h.auth.state, const SignedOut());
      expect(await _draftsOf(h, kFakeAuthSub), isEmpty);
      expect(await _draftsOf(h, 'somebody-else'), isEmpty);
      expect(
        await h.database.kvDao.get(
          AnalyticsConsentNotifier.answerKey,
          ownerSub: kFakeAuthSub,
        ),
        isNull,
      );

      expect(find.text('Your account has been deleted'), findsOneWidget);
      await tester.tap(find.byKey(AccountDeletedNotice.doneKey));
      await tester.pumpAndSettle();
      expect(find.text('Your account has been deleted'), findsNothing);
    });

    testWidgets('and the app is at the sign-in screen afterwards', (
      tester,
    ) async {
      // The whole app: what "Done" reveals is the router's redirect.
      final h = AccountHarness();
      await pumpApp(tester, overrides: h.overrides);
      routerOf(tester).go(AppRoutes.settingsAccount);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(AccountScreen.deleteKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AccountScreen.deleteKey));
      await tester.pumpAndSettle();
      await _typeAndConfirm(tester, 'DELETE');

      // The confirmation covers the redirect that happened underneath.
      expect(find.text('Your account has been deleted'), findsOneWidget);
      expect(find.byType(SignInScreen).hitTestable(), findsNothing);

      await tester.tap(find.byKey(AccountDeletedNotice.doneKey));
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(locationOf(tester), AppRoutes.signIn);
    });

    testWidgets('a deletion that is already completed is the same to the app', (
      tester,
    ) async {
      final h = AccountHarness(scenarios: {'DeleteMyAccount': 'completed'});
      await _pumpDelete(tester, overrides: h.overrides);
      await _typeAndConfirm(tester, 'DELETE');
      expect(find.text('Your account has been deleted'), findsOneWidget);
      expect(h.auth.state, const SignedOut());
    });

    const reasons = {
      'kid_account': 'This is a child account.',
      'has_dependents': 'Child accounts are linked to your account',
      'active_membership': 'You have an active membership.',
      'open_invoices': 'There are open invoices on your account.',
      'owns_club': 'Something on your account has to be sorted out',
    };
    for (final MapEntry(key: reason, value: text) in reasons.entries) {
      testWidgets('blocked ($reason): the reason, support, nothing deleted', (
        tester,
      ) async {
        final h = AccountHarness();
        h.api.respond('DeleteMyAccount', (_) => _blocked(reason));
        await h.database.draftsDao.create(kFakeAuthSub, pgn: '1. e4');
        await _pumpDelete(tester, overrides: h.overrides);
        await _typeAndConfirm(tester, 'DELETE');

        expect(
          find.text('This account cannot be deleted here'),
          findsOneWidget,
        );
        expect(find.textContaining(text), findsOneWidget);
        expect(find.text('Nothing was deleted.'), findsOneWidget);
        expect(find.text(kSupportEmail), findsOneWidget);
        expect(h.auth.state, isA<SignedIn>());
        expect(await _draftsOf(h, kFakeAuthSub), hasLength(1));
        expect(h.analytics.events, isEmpty);

        await tester.tap(find.byKey(DeleteAccountScreen.supportKey));
        await tester.pump();
        final mail = h.launched.single;
        expect(mail.scheme, 'mailto');
        expect(mail.path, kSupportEmail);
        expect(
          mail.toString(),
          'mailto:$kSupportEmail?subject=Delete%20my%20Bogner%20Chess%20account',
        );

        await tester.tap(find.byKey(DeleteAccountScreen.backKey));
        await tester.pumpAndSettle();
        expect(find.byType(DeleteAccountScreen), findsNothing);
      });
    }

    testWidgets('the fixture of the mock server (unknown reason) is handled', (
      tester,
    ) async {
      final h = AccountHarness(scenarios: {'DeleteMyAccount': 'blocked'});
      await _pumpDelete(tester, overrides: h.overrides);
      await _typeAndConfirm(tester, 'DELETE');
      expect(find.text('This account cannot be deleted here'), findsOneWidget);
    });

    testWidgets('offline: nothing changed, and trying again works', (
      tester,
    ) async {
      final h = AccountHarness();
      h.api.fail('DeleteMyAccount', const SocketException('offline'));
      await _pumpDelete(tester, overrides: h.overrides);
      await _typeAndConfirm(tester, 'DELETE');

      expect(find.textContaining('You are offline.'), findsOneWidget);
      expect(h.auth.state, isA<SignedIn>());
      expect(find.text('Try again'), findsOneWidget);

      h.api.use('DeleteMyAccount', 'default');
      await tester.ensureVisible(find.byKey(DeleteAccountScreen.confirmKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(DeleteAccountScreen.confirmKey));
      await tester.pumpAndSettle();
      expect(find.text('Your account has been deleted'), findsOneWidget);
    });

    for (final scenario in [
      'technical_error',
      'business_error',
      'unknown_error',
    ]) {
      testWidgets('server failure ($scenario): a message and a retry', (
        tester,
      ) async {
        final h = AccountHarness(scenarios: {'DeleteMyAccount': scenario});
        await _pumpDelete(tester, overrides: h.overrides);
        await _typeAndConfirm(tester, 'DELETE');

        expect(
          find.textContaining('The account could not be deleted.'),
          findsOneWidget,
        );
        expect(h.auth.state, isA<SignedIn>());
        expect(find.text('Your account has been deleted'), findsNothing);
      });
    }

    testWidgets('a failing local wipe does not stop the sign-out', (
      tester,
    ) async {
      final h = AccountHarness();
      await h.database.close(); // every query throws from here on
      await _pumpDelete(tester, overrides: h.overrides);
      await _typeAndConfirm(tester, 'DELETE');
      expect(h.auth.state, const SignedOut());
      expect(find.text('Your account has been deleted'), findsOneWidget);
    });

    for (final brightness in Brightness.values) {
      testWidgets('German, text scale 1.3, iPhone SE, ${brightness.name}', (
        tester,
      ) async {
        final h = AccountHarness();
        h.api.respond('DeleteMyAccount', (_) => _blocked('active_membership'));
        await _pumpAccount(
          tester,
          locale: const Locale('de', 'CH'),
          brightness: brightness,
          textScale: 1.3,
          screenSize: kIphoneSe,
          overrides: h.overrides,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Abmelden'), findsOneWidget);

        await tester.ensureVisible(find.byKey(AccountScreen.deleteKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(AccountScreen.deleteKey));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text('Damit löschst du dein Konto von bognerchess.com'),
          findsOneWidget,
        );
        // The instruction is German, the word is not.
        expect(
          find.text('Tippe zur Bestätigung DELETE in das Feld.'),
          findsOneWidget,
        );

        await _typeAndConfirm(tester, 'DELETE');
        expect(tester.takeException(), isNull);
        expect(
          find.text('Dieses Konto kann hier nicht gelöscht werden'),
          findsOneWidget,
        );
        expect(find.textContaining('aktive Mitgliedschaft'), findsOneWidget);
      });
    }
  });

  test(
    'block reasons are read case-insensitively; unknown ones are "other"',
    () {
      expect(
        DeletionBlockReason.of('KID_ACCOUNT'),
        DeletionBlockReason.kidAccount,
      );
      expect(
        DeletionBlockReason.of('open_invoices'),
        DeletionBlockReason.openInvoices,
      );
      expect(DeletionBlockReason.of('owns_club'), DeletionBlockReason.other);
      expect(DeletionBlockReason.of(''), DeletionBlockReason.other);
    },
  );
}
