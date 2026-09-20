// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:io';

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/features/usage/usage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fixture_link.dart';
import '../../helpers/pump_app.dart';

/// Pumps [UsageSummary] alone, with the API answering from [scenario].
Future<FixtureLink> pumpUsage(
  WidgetTester tester, {
  String scenario = 'default',
  UsageSummaryStyle style = UsageSummaryStyle.line,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  void Function(FixtureLink link)? setUpLink,
}) async {
  final api = FixtureLink({'MyAnalysisUsage': scenario});
  setUpLink?.call(api);
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = kIphoneSe * 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  await tester.pumpWidget(
    ProviderScope(
      overrides: api.overrides,
      child: MaterialApp(
        locale: locale,
        theme: brightness == Brightness.dark
            ? AppTheme.dark()
            : AppTheme.light(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Scaffold(
          body: Center(child: UsageSummary(style: style)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  group('the line under the analyse button', () {
    testWidgets('what is left today and when it comes back', (tester) async {
      await pumpUsage(tester);
      expect(
        find.textContaining('2 of 3 analyses left today · resets at'),
        findsOneWidget,
      );
    });

    testWidgets('used up: says so, in the warning colour', (tester) async {
      await pumpUsage(tester, scenario: 'limit_reached');
      final text = tester.widget<Text>(
        find.textContaining('No analyses left today'),
      );
      expect(
        text.style!.color,
        AppColors.of(
          tester.element(find.textContaining('No analyses left today')),
        ).warning,
      );
    });

    testWidgets('the month wins when it is the one that ran out', (
      tester,
    ) async {
      await pumpUsage(
        tester,
        setUpLink: (link) => link.respond('MyAnalysisUsage', (_) {
          final body = link.store.response('MyAnalysisUsage', 'default');
          (body['data'] as Map)['myAnalysisUsage'] as Map
            ..['monthlyUsed'] = 30
            ..['dailyUsed'] = 0;
          return body;
        }),
      );
      expect(
        find.textContaining('No analyses left this month · resets on'),
        findsOneWidget,
      );
    });

    testWidgets('no limits: nothing at all', (tester) async {
      await pumpUsage(tester, scenario: 'unlimited');
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('while loading and when it fails: nothing at all', (
      tester,
    ) async {
      final api = await pumpUsage(
        tester,
        setUpLink: (link) =>
            link.fail('MyAnalysisUsage', const SocketException('offline')),
      );
      expect(find.byType(Text), findsNothing);
      expect(api.requestsOf('MyAnalysisUsage'), hasLength(1));
    });

    testWidgets('German', (tester) async {
      await pumpUsage(tester, locale: const Locale('de'));
      expect(
        find.textContaining('Heute noch 2 von 3 Analysen'),
        findsOneWidget,
      );
    });
  });

  group('the block for the settings screen', () {
    testWidgets('both windows, with a heading', (tester) async {
      await pumpUsage(tester, style: UsageSummaryStyle.block);
      expect(find.text('Analyses'), findsOneWidget);
      expect(find.textContaining('2 of 3 analyses left today'), findsOneWidget);
      expect(
        find.textContaining('18 of 30 analyses left this month'),
        findsOneWidget,
      );
    });

    testWidgets('no limits: "Unlimited analyses"', (tester) async {
      await pumpUsage(
        tester,
        scenario: 'unlimited',
        style: UsageSummaryStyle.block,
      );
      expect(find.text('Unlimited analyses'), findsOneWidget);
    });

    testWidgets('a failure says the numbers are not available', (tester) async {
      await pumpUsage(
        tester,
        style: UsageSummaryStyle.block,
        setUpLink: (link) =>
            link.fail('MyAnalysisUsage', const SocketException('offline')),
      );
      expect(
        find.text('The numbers are not available right now.'),
        findsOneWidget,
      );
    });

    testWidgets('German, dark, text scale 1.3', (tester) async {
      await pumpUsage(
        tester,
        style: UsageSummaryStyle.block,
        locale: const Locale('de'),
        brightness: Brightness.dark,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Analysen'), findsOneWidget);
      expect(
        find.textContaining('Diesen Monat noch 18 von 30 Analysen'),
        findsOneWidget,
      );
    });
  });
}
