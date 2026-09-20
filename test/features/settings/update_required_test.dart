// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:io';

import 'package:bogner_chess/core/ui/widgets/tab_shell.dart';
import 'package:bogner_chess/features/settings/domain/update_required.dart';
import 'package:bogner_chess/features/settings/ui/update_required_gate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/account_harness.dart';
import '../../helpers/pump_app.dart';

void main() {
  group('compareVersions', () {
    const cases = <(String, String, int)>[
      ('1.2.3', '1.2.3', 0),
      ('1.2.3', '1.2.4', -1),
      ('1.10.0', '1.9.3', 1),
      ('1.2', '1.2.0', 0),
      ('2', '1.99.99', 1),
      ('1.2.3+45', '1.2.3', 0),
      ('1.2.3-beta', '1.2.3', 0),
      ('0.1.0', '9.0.0', -1),
      ('nonsense', '0.0.1', -1),
      ('', '', 0),
    ];
    for (final (a, b, expected) in cases) {
      test('"$a" against "$b"', () {
        expect(compareVersions(a, b).sign, expected);
        expect(compareVersions(b, a).sign, -expected);
      });
    }
  });

  group('UpdateRequiredGate', () {
    testWidgets('a supported version sees the app', (tester) async {
      final h = AccountHarness(); // minSupportedAppVersion 0.1.0, app 1.2.3
      await pumpApp(tester, overrides: h.overrides);
      expect(find.byType(TabShell), findsOneWidget);
      expect(find.text('Please update the app'), findsNothing);
      expect(h.api.requestsOf('MobileConfig'), hasLength(1));
    });

    testWidgets('an unsupported version sees nothing but "please update"', (
      tester,
    ) async {
      final h = AccountHarness(scenarios: {'MobileConfig': 'update_required'});
      await pumpApp(tester, overrides: h.overrides);

      expect(find.text('Please update the app'), findsOneWidget);
      expect(find.byType(TabShell), findsNothing);

      await tester.tap(find.byKey(UpdateRequiredGate.updateKey));
      await tester.pump();
      expect(h.launched.single, Uri.parse(kAppStoreUrl));
    });

    testWidgets('German, text scale 1.3, iPhone SE, dark', (tester) async {
      final h = AccountHarness(scenarios: {'MobileConfig': 'update_required'});
      await pumpApp(
        tester,
        locale: const Locale('de'),
        brightness: Brightness.dark,
        textScale: 1.3,
        screen: kIphoneSe,
        overrides: h.overrides,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Bitte aktualisiere die App'), findsOneWidget);
      expect(find.text('App Store öffnen'), findsOneWidget);
    });

    testWidgets('offline fails open, and coming back to the app checks again', (
      tester,
    ) async {
      final h = AccountHarness();
      h.api.fail('MobileConfig', const SocketException('offline'));
      await pumpApp(tester, overrides: h.overrides);
      expect(find.byType(TabShell), findsOneWidget);

      h.api.use('MobileConfig', 'update_required');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Please update the app'), findsOneWidget);
    });

    testWidgets('signed out: no request, no gate', (tester) async {
      final h = AccountHarness(
        scenarios: {'MobileConfig': 'update_required'},
        signedIn: false,
      );
      await pumpApp(tester, overrides: h.overrides);
      expect(h.api.requestsOf('MobileConfig'), isEmpty);
      expect(find.text('Please update the app'), findsNothing);
    });
  });
}
