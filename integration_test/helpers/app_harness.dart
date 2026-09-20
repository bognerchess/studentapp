// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

import 'package:bogner_chess/app.dart';
import 'package:bogner_chess/features/consent/ui/first_run_consent_prompt.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

// The smallest thing that starts the real app on a real device and hands a
// machine-readable result back. Everything specific to one test belongs in
// that test, not here.
//
// Run with:
//   flutter test integration_test -d "<simulator>" \
//       --dart-define-from-file=config/fake.json
//
// The configuration is what `config/fake.json` says, so the app runs with
// fake auth (signed in from the start) and against the mock server. The
// widget-test seams of `test/helpers/` are deliberately not used here: this
// is the app as it is built and installed, with its real providers.

/// Every test file in this directory starts with this line, before `main`
/// declares its tests.
IntegrationTestWidgetsFlutterBinding ensureIntegrationBinding() =>
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();

/// Starts the app and returns its provider container.
///
/// [overrides] replaces providers for this run; without any, every provider
/// is the one the shipped app uses. The one-time analytics question is off,
/// because it would sit over the first screen of every test.
///
/// `main.dart` does a little more than this (crash reporter, links, push,
/// analytics lifecycle). None of it belongs to a UI test, and starting the
/// push service would ask for a permission the simulator cannot answer.
Future<ProviderContainer> launchApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firstRunConsentPromptEnabledProvider.overrideWithValue(false),
        ...overrides,
      ],
      child: const BognerChessApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(BognerChessApp)));
}

/// The router of the running app.
GoRouter routerOf(ProviderContainer container) =>
    container.read(routerProvider);

/// Goes to [location] (an `AppRoutes` constant) and waits for the screen.
Future<void> goTo(
  WidgetTester tester,
  ProviderContainer container,
  String location,
) async {
  routerOf(container).go(location);
  await tester.pumpAndSettle();
}

/// The path the app currently shows.
String locationOf(ProviderContainer container) =>
    routerOf(container).routerDelegate.currentConfiguration.uri.path;

/// The token that marks a report line in the test output. CI greps for it;
/// see `.github/workflows/integration.yml`.
const String kReportMarker = 'INTEGRATION-REPORT';

/// Publishes a machine-readable [summary] under [key].
///
/// Two ways out, because the two ways of running these tests deliver
/// different things:
///
/// - `binding.reportData`, which `flutter drive` with `integrationDriver`
///   writes to `build/integration_response_data.json`;
/// - one line on stdout beginning with [kReportMarker], which is what
///   `flutter test integration_test` (the way CI runs them) leaves behind.
///
/// Keep a summary small. `debugPrint` throttles its output, so a report of
/// tens of kilobytes can still be in the queue when the process exits.
void publishReport(
  IntegrationTestWidgetsFlutterBinding binding,
  String key,
  Map<String, Object?> summary,
) {
  (binding.reportData ??= <String, dynamic>{})[key] = summary;
  debugPrint('$kReportMarker $key ${jsonEncode(summary)}');
}
