// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/push/push_platform.dart';
import 'package:bogner_chess/core/push/ui/push_denied_hint.dart';
import 'package:bogner_chess/core/push/ui/push_explainer_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/pump_screen.dart';
import 'push_test_support.dart';

/// Whatever screen the sheet is shown over.
const _hostKey = Key('sheet-host');
const _host = Scaffold(key: _hostKey, body: SizedBox.expand());

void main() {
  Future<Future<bool>> open(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    Brightness brightness = Brightness.light,
    double textScale = 1.0,
    Size screen = kIphone17Pro,
  }) async {
    await pumpScreen(
      tester,
      _host,
      locale: locale,
      brightness: brightness,
      textScale: textScale,
      screenSize: screen,
    );
    final result = showPushExplainerSheet(tester.element(find.byKey(_hostKey)));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('English: says what for, and what not', (tester) async {
    await open(tester);
    expect(find.text('Know when your analysis is ready'), findsOneWidget);
    expect(
      find.textContaining("We'll let you know when your analysis is ready"),
      findsOneWidget,
    );
    expect(find.textContaining('No advertising'), findsOneWidget);
    expect(find.text('Notify me'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('German, informal and without sharp s', (tester) async {
    await open(tester, locale: const Locale('de'));
    expect(find.text('Erfahre, wann deine Analyse fertig ist'), findsOneWidget);
    expect(find.textContaining('Wir sagen dir Bescheid'), findsOneWidget);
    expect(find.text('Benachrichtige mich'), findsOneWidget);
    expect(find.text('Nicht jetzt'), findsOneWidget);
    for (final text in tester.widgetList<Text>(
      find.descendant(
        of: find.byKey(PushExplainerKeys.sheet),
        matching: find.byType(Text),
      ),
    )) {
      expect(text.data, isNot(contains('ß')));
    }
  });

  testWidgets('"Notify me" answers true', (tester) async {
    final result = await open(tester);
    await tester.tap(find.byKey(PushExplainerKeys.allow));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
    expect(find.byKey(PushExplainerKeys.sheet), findsNothing);
  });

  testWidgets('"Not now" answers false', (tester) async {
    final result = await open(tester);
    await tester.tap(find.byKey(PushExplainerKeys.notNow));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('dismissing the sheet answers false', (tester) async {
    final result = await open(tester);
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  for (final locale in const [Locale('en'), Locale('de')]) {
    testWidgets('$locale, dark, text scale 1.3, small phone: everything fits '
        'and both buttons can be reached', (tester) async {
      await open(
        tester,
        locale: locale,
        brightness: Brightness.dark,
        textScale: 1.3,
        screen: kIphoneSe,
      );
      // An overflow would have failed the test by now.
      expect(tester.takeException(), isNull);
      final sheet = find.byKey(PushExplainerKeys.sheet);
      expect(Theme.of(tester.element(sheet)).brightness, Brightness.dark);

      for (final key in [PushExplainerKeys.allow, PushExplainerKeys.notNow]) {
        await tester.ensureVisible(find.byKey(key));
        await tester.pumpAndSettle();
        final size = tester.getSize(find.byKey(key));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(find.byKey(key).hitTestable(), findsOneWidget);
      }
    });
  }

  testWidgets('meets the tap-target and contrast guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  group('PushDeniedHint', () {
    Future<FakePushPlatform> pumpHint(
      WidgetTester tester,
      PushPermissionStatus status, {
      Locale locale = const Locale('en'),
    }) async {
      final platform = FakePushPlatform(status: status);
      // Not awaited: without a listener the future of close() never ends.
      addTearDown(() => unawaited(platform.controller.close()));
      await pumpScreen(
        tester,
        const Scaffold(body: PushDeniedHint()),
        locale: locale,
        overrides: [pushPlatformProvider.overrideWithValue(platform)],
      );
      return platform;
    }

    testWidgets('denied: says where to change it and opens the Settings app', (
      tester,
    ) async {
      final platform = await pumpHint(tester, PushPermissionStatus.denied);
      expect(find.textContaining('turned off'), findsOneWidget);
      await tester.tap(find.byKey(PushDeniedHint.openSettingsKey));
      await tester.pumpAndSettle();
      expect(platform.calls, contains('openSettings'));
    });

    testWidgets('German', (tester) async {
      await pumpHint(
        tester,
        PushPermissionStatus.denied,
        locale: const Locale('de'),
      );
      expect(find.text('Einstellungen öffnen'), findsOneWidget);
    });

    testWidgets('takes no space otherwise', (tester) async {
      for (final status in [
        PushPermissionStatus.authorized,
        PushPermissionStatus.notDetermined,
      ]) {
        await pumpHint(tester, status);
        expect(find.byKey(PushDeniedHint.openSettingsKey), findsNothing);
      }
    });
  });
}
