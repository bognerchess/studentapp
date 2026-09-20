// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:io';

import 'package:bogner_chess/core/chess/board_theme_preference.dart';
import 'package:bogner_chess/core/chess/board_view.dart';
import 'package:bogner_chess/core/consent/consent_state.dart';
import 'package:bogner_chess/core/push/push_platform.dart';
import 'package:bogner_chess/core/push/ui/push_denied_hint.dart';
import 'package:bogner_chess/features/consent/ui/ai_consent_screen.dart';
import 'package:bogner_chess/features/entry/domain/entry_settings.dart';
import 'package:bogner_chess/features/legal/domain/legal_documents.dart';
import 'package:bogner_chess/features/settings/ui/settings_board.dart';
import 'package:bogner_chess/features/settings/ui/settings_screen.dart';
import 'package:bogner_chess/features/settings/ui/settings_usage.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/push/push_test_support.dart';
import '../../helpers/account_harness.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_screen.dart';

Future<PumpedScreen> _pumpSettings(
  WidgetTester tester, {
  required List<Override> overrides,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Size screenSize = kIphone17Pro,
}) => pumpScreen(
  tester,
  const SettingsScreen(),
  locale: locale,
  brightness: brightness,
  textScale: textScale,
  screenSize: screenSize,
  overrides: overrides,
);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// A usage answer whose resets lie in the future of the test run.
Map<String, dynamic> _usage({
  int? dailyLimit = 3,
  int dailyUsed = 1,
  int? monthlyLimit = 30,
  int monthlyUsed = 12,
  int queuedJobs = 0,
  required DateTime dailyResetAt,
  required DateTime monthlyResetAt,
}) => {
  'data': {
    'myAnalysisUsage': {
      'policy': dailyLimit == null ? 'UNLIMITED' : 'DEFAULT',
      'dailyLimit': dailyLimit,
      'dailyUsed': dailyUsed,
      'dailyResetAt': dailyResetAt.toUtc().toIso8601String(),
      'monthlyLimit': monthlyLimit,
      'monthlyUsed': monthlyUsed,
      'monthlyResetAt': monthlyResetAt.toUtc().toIso8601String(),
      'queuedJobs': queuedJobs,
      'maxQueuedJobs': 2,
    },
  },
};

void main() {
  testWidgets('every section is there', (tester) async {
    final h = AccountHarness();
    await _pumpSettings(tester, overrides: h.overrides);

    for (final text in [
      'Account',
      'Fake User',
      'fake.user@example.test',
      'Analyses',
      'Board',
      'Entering moves',
      'Always promote to queen',
      'Your data',
      'Usage statistics and crash reports',
      'AI analysis consent',
      'Privacy and terms',
      'Privacy policy',
      'Terms of use',
      'About and licences',
      'Version 1.2.3 (45)',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });

  group('analysis quota', () {
    testWidgets('used and allowed, with the reset times', (tester) async {
      final h = AccountHarness();
      final dailyReset = DateTime.now().add(const Duration(hours: 5));
      final monthlyReset = DateTime.now().add(const Duration(days: 9));
      h.api.respond(
        'MyAnalysisUsage',
        (_) => _usage(
          queuedJobs: 1,
          dailyResetAt: dailyReset,
          monthlyResetAt: monthlyReset,
        ),
      );
      await _pumpSettings(tester, overrides: h.overrides);

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('1 of 3'), findsOneWidget);
      expect(
        find.text('Resets at ${DateFormat.Hm('en').format(dailyReset)}.'),
        findsOneWidget,
      );
      expect(find.text('This month'), findsOneWidget);
      expect(find.text('12 of 30'), findsOneWidget);
      expect(
        find.text('Resets on ${DateFormat.MMMMd('en').format(monthlyReset)}.'),
        findsOneWidget,
      );
      expect(
        find.text('1 analysis in progress (at most 2 at a time)'),
        findsOneWidget,
      );
      expect(find.text('Unlimited'), findsNothing);
    });

    testWidgets('limit reached', (tester) async {
      final h = AccountHarness();
      h.api.respond(
        'MyAnalysisUsage',
        (_) => _usage(
          dailyUsed: 3,
          dailyResetAt: DateTime.now().add(const Duration(hours: 5)),
          monthlyResetAt: DateTime.now().add(const Duration(days: 9)),
        ),
      );
      await _pumpSettings(tester, overrides: h.overrides);

      expect(find.text('3 of 3'), findsOneWidget);
      expect(find.textContaining('Limit reached. Resets at'), findsOneWidget);
    });

    testWidgets('unlimited accounts get a badge and plain counts', (
      tester,
    ) async {
      final h = AccountHarness(scenarios: {'MyAnalysisUsage': 'unlimited'});
      await _pumpSettings(tester, overrides: h.overrides);

      expect(find.text('Unlimited'), findsOneWidget);
      expect(find.text('1 analysis'), findsOneWidget);
      expect(find.text('12 analyses'), findsOneWidget);
      expect(find.textContaining('Resets'), findsNothing);
    });

    testWidgets('offline: a line and a retry, the rest of the screen works', (
      tester,
    ) async {
      final h = AccountHarness();
      h.api.fail('MyAnalysisUsage', const SocketException('offline'));
      await _pumpSettings(tester, overrides: h.overrides);

      expect(find.text('The numbers could not be loaded.'), findsOneWidget);
      expect(find.text('Board'), findsOneWidget);

      h.api.use('MyAnalysisUsage', 'unlimited');
      await tester.tap(find.byKey(SettingsUsage.retryKey));
      await tester.pumpAndSettle();
      expect(find.text('Unlimited'), findsOneWidget);
    });

    testWidgets('coming back to the tab asks for the numbers again', (
      tester,
    ) async {
      // The whole app: this is about the shell keeping the tab alive while
      // the screen is away, which only the real router does.
      final h = AccountHarness();
      await pumpApp(tester, overrides: h.overrides);
      routerOf(tester).go(AppRoutes.settings);
      await tester.pumpAndSettle();
      expect(h.api.requestsOf('MyAnalysisUsage'), hasLength(1));

      routerOf(tester).go(AppRoutes.games);
      await tester.pumpAndSettle();
      routerOf(tester).go(AppRoutes.settings);
      await tester.pumpAndSettle();
      expect(h.api.requestsOf('MyAnalysisUsage'), hasLength(2));
    });
  });

  group('board', () {
    testWidgets('a choice shows in the preview at once and is kept', (
      tester,
    ) async {
      final h = AccountHarness();
      await _pumpSettings(tester, overrides: h.overrides);

      BoardTheme preview() =>
          tester.widget<BoardView>(find.byKey(SettingsBoard.previewKey)).theme;
      expect(preview(), const BoardTheme());

      await _tapVisible(
        tester,
        find.byKey(SettingsBoard.pieceSetKey(BoardPieceSet.merida)),
      );
      await _tapVisible(
        tester,
        find.byKey(SettingsBoard.colorsKey(BoardColors.blue)),
      );

      const chosen = BoardTheme(
        pieceSet: BoardPieceSet.merida,
        colors: BoardColors.blue,
      );
      expect(preview(), chosen);
      expect(containerOf(tester).read(boardThemeProvider), chosen);
      final preferences = SharedPreferencesAsync();
      expect(await preferences.getString(kBoardPieceSetKey), 'merida');
      expect(await preferences.getString(kBoardColorsKey), 'blue');
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(SettingsBoard.pieceSetKey(BoardPieceSet.merida)),
            )
            .selected,
        isTrue,
      );
      expect(
        tester.getSemantics(
          find.byKey(SettingsBoard.colorsKey(BoardColors.blue)),
        ),
        isSemantics(label: 'Blue', isButton: true, isSelected: true),
      );
    });

    testWidgets('the entry board uses the chosen theme', (tester) async {
      // The whole app: the point is that a choice made here reaches another
      // screen.
      final h = AccountHarness();
      await pumpApp(tester, overrides: h.overrides);
      await containerOf(tester)
          .read(boardThemeProvider.notifier)
          .select(pieceSet: BoardPieceSet.rhosgfx, colors: BoardColors.green);

      routerOf(tester).go(AppRoutes.newGameEntry);
      await tester.pumpAndSettle();

      expect(
        tester.widget<BoardView>(find.byType(BoardView)).theme,
        const BoardTheme(
          pieceSet: BoardPieceSet.rhosgfx,
          colors: BoardColors.green,
        ),
      );
    });
  });

  testWidgets('"always promote to queen" is the entry screen\'s setting', (
    tester,
  ) async {
    final h = AccountHarness();
    await _pumpSettings(tester, overrides: h.overrides);

    await _tapVisible(tester, find.byKey(SettingsScreen.autoQueenKey));
    expect(containerOf(tester).read(entryAutoQueenProvider), isTrue);
    expect(await SharedPreferencesAsync().getBool(kEntryAutoQueenKey), isTrue);
  });

  group('privacy', () {
    testWidgets('the analytics switch is off by default and records a change', (
      tester,
    ) async {
      final h = AccountHarness(scenarios: {'MyConsent': 'required'});
      await _pumpSettings(tester, overrides: h.overrides);

      SwitchListTile tile() =>
          tester.widget(find.byKey(SettingsScreen.analyticsKey));
      expect(tile().value, isFalse);

      await _tapVisible(tester, find.byKey(SettingsScreen.analyticsKey));
      expect(tile().value, isTrue);
      expect(
        containerOf(tester).read(analyticsConsentProvider),
        AnalyticsConsent.granted,
      );
      expect(h.api.requestsOf('RecordConsent').single.variables['input'], {
        'key': 'ANALYTICS_CONSENT',
        'version': 1,
        'accepted': true,
      });

      await _tapVisible(tester, find.byKey(SettingsScreen.analyticsKey));
      expect(tile().value, isFalse);
      expect(
        (h.api.requestsOf('RecordConsent').last.variables['input']
            as Map<String, dynamic>)['accepted'],
        isFalse,
      );
      expect(h.analytics.names, [
        'consent_analytics_changed',
        'consent_analytics_changed',
      ]);
    });

    testWidgets('AI consent: not agreed yet leads to the consent screen', (
      tester,
    ) async {
      final h = AccountHarness(scenarios: {'MyAiConsent': 'required'});
      await _pumpSettings(tester, overrides: h.overrides);
      expect(find.textContaining('Not agreed yet'), findsOneWidget);

      await _tapVisible(tester, find.text('Review'));
      expect(navigatedTo(tester), AppRoutes.consentAi);
    });

    testWidgets('AI consent: agreeing on the consent screen shows here', (
      tester,
    ) async {
      // The whole app: the round trip between two screens is the point.
      final h = AccountHarness(scenarios: {'MyAiConsent': 'required'});
      await pumpApp(tester, overrides: h.overrides);
      routerOf(tester).go(AppRoutes.settings);
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.text('Review'));
      expect(find.byType(AiConsentScreen), findsOneWidget);
      await tester.tap(find.byKey(AiConsentScreen.agreeKey));
      await tester.pumpAndSettle();
      expect(find.byType(AiConsentScreen), findsNothing);
      expect(find.text('Agreed (version 1)'), findsOneWidget);
    });

    testWidgets('AI consent: a version bump says so', (tester) async {
      final h = AccountHarness(scenarios: {'MyAiConsent': 'new_version'});
      await _pumpSettings(tester, overrides: h.overrides);
      expect(find.textContaining('The text has changed'), findsOneWidget);
    });

    testWidgets('AI consent: offline', (tester) async {
      final h = AccountHarness();
      h.api.fail('MyAiConsent', const SocketException('offline'));
      await _pumpSettings(tester, overrides: h.overrides);
      expect(find.text('The status could not be loaded.'), findsOneWidget);
    });
  });

  group('notifications', () {
    Future<FakePushPlatform> openWith(
      WidgetTester tester,
      PushPermissionStatus status,
    ) async {
      final h = AccountHarness();
      final platform = FakePushPlatform(status: status);
      // Not awaited: without a listener the future of close() never ends.
      addTearDown(() => unawaited(platform.controller.close()));
      await _pumpSettings(
        tester,
        overrides: [
          ...h.overrides,
          pushPlatformProvider.overrideWithValue(platform),
        ],
      );
      return platform;
    }

    testWidgets('denied: the way into the Settings app is in "Analyses"', (
      tester,
    ) async {
      final platform = await openWith(tester, PushPermissionStatus.denied);
      final button = find.byKey(PushDeniedHint.openSettingsKey);
      expect(button, findsOneWidget);
      // Between the quota and the next section, not at the end of the screen.
      expect(
        tester.getCenter(button).dy,
        greaterThan(tester.getCenter(find.byType(SettingsUsage)).dy),
      );
      expect(
        tester.getCenter(button).dy,
        lessThan(tester.getCenter(find.text('Board')).dy),
      );

      await _tapVisible(tester, button);
      expect(platform.calls, contains('openSettings'));
    });

    testWidgets('allowed or not asked yet: nothing about notifications', (
      tester,
    ) async {
      for (final status in [
        PushPermissionStatus.authorized,
        PushPermissionStatus.notDetermined,
      ]) {
        await openWith(tester, status);
        expect(
          find.byKey(PushDeniedHint.openSettingsKey),
          findsNothing,
          reason: status.name,
        );
      }
    });
  });

  testWidgets('the rows lead to account, legal texts and about', (
    tester,
  ) async {
    final h = AccountHarness();
    await _pumpSettings(tester, overrides: h.overrides);

    await _tapVisible(tester, find.byKey(SettingsScreen.accountKey));
    expect(navigatedTo(tester), AppRoutes.settingsAccount);

    await _pumpSettings(tester, overrides: h.overrides);
    await _tapVisible(tester, find.byKey(SettingsScreen.termsKey));
    expect(navigatedTo(tester), AppRoutes.legalDocument(LegalPage.terms.slug));

    await _pumpSettings(tester, overrides: h.overrides);
    await _tapVisible(tester, find.byKey(SettingsScreen.privacyPolicyKey));
    expect(
      navigatedTo(tester),
      AppRoutes.legalDocument(LegalPage.privacy.slug),
    );

    await _pumpSettings(tester, overrides: h.overrides);
    await _tapVisible(tester, find.byKey(SettingsScreen.aboutKey));
    expect(navigatedTo(tester), AppRoutes.settingsAbout);
  });

  for (final brightness in Brightness.values) {
    testWidgets('German, text scale 1.3, iPhone SE, ${brightness.name}', (
      tester,
    ) async {
      final h = AccountHarness();
      await _pumpSettings(
        tester,
        locale: const Locale('de', 'CH'),
        brightness: brightness,
        textScale: 1.3,
        screenSize: kIphoneSe,
        overrides: h.overrides,
      );
      expect(tester.takeException(), isNull);

      for (final text in [
        'Konto',
        'Analysen',
        'Heute',
        '1 von 3',
        'Brett',
        'Figuren',
        'Brettfarben',
        'Deine Daten',
        'Nutzungsstatistiken und Absturzberichte',
        'Zustimmung zur KI-Analyse',
        'Datenschutzerklärung',
        'Nutzungsbedingungen',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }

      await tester.drag(
        find.byKey(SettingsScreen.scrollKey),
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
