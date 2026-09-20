// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:io';

import 'package:bogner_chess/core/consent/consent_state.dart';
import 'package:bogner_chess/features/consent/ui/analytics_consent_sheet.dart';
import 'package:bogner_chess/features/legal/ui/legal_document_screen.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/account_harness.dart';
import '../../helpers/pump_app.dart';

void main() {
  AccountHarness neverAsked() =>
      AccountHarness(scenarios: {'MyConsent': 'required'})
        ..serveLegalDocumentsByLanguage();

  AnalyticsConsent consentOf(WidgetTester tester) =>
      containerOf(tester).read(analyticsConsentProvider);

  testWidgets('the first start asks, with the backend text, default off', (
    tester,
  ) async {
    final h = neverAsked();
    await pumpApp(tester, firstRunPrompts: true, overrides: h.overrides);

    expect(find.byType(AnalyticsConsentSheet), findsOneWidget);
    expect(find.text('Help us improve the app'), findsOneWidget);
    expect(
      find.textContaining('switched off unless you allow'),
      findsOneWidget,
    );
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(consentOf(tester), AnalyticsConsent.unknown);
    expect(h.api.requestsOf('RecordConsent'), isEmpty);
  });

  testWidgets('"Allow" grants, records the version and does not ask again', (
    tester,
  ) async {
    final h = neverAsked();
    await pumpApp(tester, firstRunPrompts: true, overrides: h.overrides);

    await tester.tap(find.byKey(AnalyticsConsentSheet.allowKey));
    await tester.pumpAndSettle();

    expect(find.byType(AnalyticsConsentSheet), findsNothing);
    expect(consentOf(tester), AnalyticsConsent.granted);
    expect(h.api.requestsOf('RecordConsent').single.variables['input'], {
      'key': 'ANALYTICS_CONSENT',
      'version': 1,
      'accepted': true,
    });
    expect(h.analytics.names, ['consent_analytics_changed']);

    // The next start of the app on the same device.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, firstRunPrompts: true, overrides: h.overrides);
    expect(find.byType(AnalyticsConsentSheet), findsNothing);
    expect(consentOf(tester), AnalyticsConsent.granted);
  });

  testWidgets('"No thanks" is recorded as a refusal', (tester) async {
    final h = neverAsked();
    await pumpApp(tester, firstRunPrompts: true, overrides: h.overrides);

    await tester.tap(find.byKey(AnalyticsConsentSheet.declineKey));
    await tester.pumpAndSettle();

    expect(consentOf(tester), AnalyticsConsent.denied);
    expect(
      (h.api.requestsOf('RecordConsent').single.variables['input']
          as Map<String, dynamic>)['accepted'],
      isFalse,
    );
  });

  testWidgets('swiping it away leaves it off and is not asked again', (
    tester,
  ) async {
    final h = neverAsked();
    await pumpApp(tester, firstRunPrompts: true, overrides: h.overrides);

    await tester.tapAt(const Offset(200, 60)); // the scrim
    await tester.pumpAndSettle();
    expect(find.byType(AnalyticsConsentSheet), findsNothing);
    expect(consentOf(tester), AnalyticsConsent.unknown);
    expect(h.api.requestsOf('RecordConsent'), isEmpty);

    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, firstRunPrompts: true, overrides: h.overrides);
    expect(find.byType(AnalyticsConsentSheet), findsNothing);
  });

  testWidgets('offline: the app\'s own wording, the record follows later', (
    tester,
  ) async {
    final h = AccountHarness();
    for (final operation in ['MyConsent', 'LegalDocument', 'RecordConsent']) {
      h.api.fail(operation, const SocketException('offline'));
    }
    await pumpApp(tester, firstRunPrompts: true, overrides: h.overrides);

    expect(find.text('Help improve the app?'), findsOneWidget);
    await tester.tap(find.byKey(AnalyticsConsentSheet.allowKey));
    await tester.pumpAndSettle();
    expect(consentOf(tester), AnalyticsConsent.granted);

    // Back online at the next start.
    h.api
      ..use('MyConsent', 'required')
      ..use('RecordConsent', 'default');
    h.api.requests.clear();
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, firstRunPrompts: true, overrides: h.overrides);
    expect(h.api.requestsOf('RecordConsent').single.variables['input'], {
      'key': 'ANALYTICS_CONSENT',
      'version': 1,
      'accepted': true,
    });
  });

  testWidgets('somebody who answered on another device is not asked', (
    tester,
  ) async {
    final h = AccountHarness(); // MyConsent/default: accepted
    await pumpApp(tester, firstRunPrompts: true, overrides: h.overrides);
    expect(find.byType(AnalyticsConsentSheet), findsNothing);
    expect(consentOf(tester), AnalyticsConsent.granted);
  });

  testWidgets('the privacy policy opens above the question', (tester) async {
    final h = neverAsked();
    await pumpApp(tester, firstRunPrompts: true, overrides: h.overrides);

    await tester.tap(find.byKey(AnalyticsConsentSheet.privacyKey));
    await tester.pumpAndSettle();
    expect(find.byType(LegalDocumentScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AnalyticsConsentSheet), findsOneWidget);
  });

  testWidgets('never over the sign-in screen: it waits for the sign-in', (
    tester,
  ) async {
    final h = AccountHarness(
      scenarios: {'MyConsent': 'required'},
      signedIn: false,
    )..serveLegalDocumentsByLanguage();
    await pumpApp(tester, firstRunPrompts: true, overrides: h.overrides);
    expect(locationOf(tester), AppRoutes.signIn);
    expect(find.byType(AnalyticsConsentSheet), findsNothing);

    await h.auth.signIn();
    await tester.pumpAndSettle();
    expect(locationOf(tester), AppRoutes.games);
    expect(find.byType(AnalyticsConsentSheet), findsOneWidget);
  });

  testWidgets('German, text scale 1.3, iPhone SE', (tester) async {
    final h = neverAsked();
    await pumpApp(
      tester,
      firstRunPrompts: true,
      locale: const Locale('de'),
      textScale: 1.3,
      screen: kIphoneSe,
      overrides: h.overrides,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Hilf uns, die App zu verbessern'), findsOneWidget);
    expect(find.text('Erlauben'), findsOneWidget);
    expect(find.text('Nein danke'), findsOneWidget);
    expect(find.text('Datenschutzerklärung'), findsOneWidget);
  });
}
