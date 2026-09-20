// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/app.dart';
import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/features/analysis_status/domain/job_tracker_providers.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:bogner_chess/features/consent/ui/first_run_consent_prompt.dart';
import 'package:bogner_chess/router.dart';
import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'fixture_link.dart';

/// An [Env] for tests. The default is the fake configuration.
Env testEnv({String envName = 'fake', AuthMode authMode = AuthMode.fake}) {
  return Env(
    envName: envName,
    apiUrl: Uri.parse('http://localhost:5299/graphql'),
    tenantSlug: 'test-tenant',
    oidcIssuer: Uri.parse('https://id.example.test/realms/test'),
    oidcClientId: 'test-client',
    oidcRedirect: 'com.bognerchess.mobile:/oauthredirect',
    sentryDsn: '',
    authMode: authMode,
  );
}

/// An auth state that tests can change, to exercise the router's redirects.
class TestAuthNotifier extends AuthStateNotifier {
  TestAuthNotifier(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;

  // ignore: use_setters_to_change_properties
  void set(AuthState value) => state = value;
}

/// A `jobTrackerUiMountedProvider` that never reports the tree as mounted.
///
/// `AnalysisNotices` lives in `app.dart`, so every `pumpApp` mounts it and the
/// job poller starts. Its next poll is a pending `Timer`, and Flutter fails any
/// test that ends with one. Tests about the tracker itself pass
/// `jobPolling: true`; for everything else an idle poller is what the screen
/// under test would see anyway.
class _NeverMounted extends JobTrackerUiMounted {
  @override
  bool build() => false;

  @override
  void set({required bool mounted}) {}
}

/// Logical screen sizes of the smallest and a current supported iPhone.
const Size kIphoneSe = Size(375, 667);
const Size kIphone17Pro = Size(402, 874);

/// An empty in-memory database for a widget test.
///
/// drift normally keeps a query stream alive for one more event-loop turn
/// after its last listener left, with a timer. Under the fake clock of
/// `testWidgets` that timer is still pending when the tree is gone, which
/// fails the test, and `close()` would wait for it for ever.
/// `closeStreamsSynchronously` switches that cache off.
AppDatabase openWidgetTestDatabase({Clock? clock}) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
    clock: clock,
  );
}

/// What every test that pumps the whole app needs, because the app reads
/// the API and the database from its first frame (the library is the start
/// screen): a [FixtureLink] with the default fixtures as the API, and an
/// empty in-memory database that is closed when the test ends. A provider
/// that [unless] already overrides is left out.
List<Override> backendOverrides({List<Override> unless = const []}) {
  bool overridden(Object provider) =>
      unless.any((o) => identical(o.origin, provider));
  AppDatabase? database;
  if (!overridden(appDatabaseProvider)) {
    database = openWidgetTestDatabase();
    addTearDown(database.close);
  }
  return [
    if (database != null) appDatabaseProvider.overrideWithValue(database),
    if (!overridden(apiLinkProvider))
      apiLinkProvider.overrideWithValue(FixtureLink()),
  ];
}

/// Pumps the whole app (router, themes, l10n) the way `main.dart` runs it.
///
/// [auth] defaults to what [env] implies: signed in with fake auth, signed
/// out with real auth. [overrides] come last, for example
/// `authRepositoryProvider.overrideWithValue(FakeAuthRepository(...))`.
/// [firstRunPrompts] lets the one-time analytics question open.
/// [jobPolling] lets the analysis job poller run (off by default).
/// API and database come from [backendOverrides] unless [overrides] bring
/// their own.
Future<void> pumpApp(
  WidgetTester tester, {
  Env? env,
  AuthState? auth,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Size screen = kIphone17Pro,
  bool firstRunPrompts = false,
  bool jobPolling = false,
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = screen * 3;
  tester.platformDispatcher.localesTestValue = [locale];
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...backendOverrides(unless: overrides),
        envProvider.overrideWithValue(env ?? testEnv()),
        appInfoProvider.overrideWith(
          (ref) async => const AppInfo(version: '1.2.3', buildNumber: '45'),
        ),
        if (auth != null)
          authStateProvider.overrideWith(() => TestAuthNotifier(auth)),
        // The one-time analytics question would sit on top of the first
        // screen of every test with working storage.
        if (!firstRunPrompts)
          firstRunConsentPromptEnabledProvider.overrideWithValue(false),
        // The job poller would leave a pending timer in every test.
        if (!jobPolling)
          jobTrackerUiMountedProvider.overrideWith(_NeverMounted.new),
        ...overrides,
      ],
      child: const BognerChessApp(),
    ),
  );
  // Without [settle] the test sees the first frame, e.g. what is on screen
  // while the server has not answered yet.
  if (settle) {
    await tester.pumpAndSettle();
  }
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(BognerChessApp)));

GoRouter routerOf(WidgetTester tester) =>
    containerOf(tester).read(routerProvider);

/// The path the router currently shows.
String locationOf(WidgetTester tester) =>
    routerOf(tester).routerDelegate.currentConfiguration.uri.path;
