// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/app.dart';
import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

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

/// Logical screen sizes of the smallest and a current supported iPhone.
const Size kIphoneSe = Size(375, 667);
const Size kIphone17Pro = Size(402, 874);

/// Pumps the whole app (router, themes, l10n) the way `main.dart` runs it.
///
/// [auth] defaults to what [env] implies: signed in with fake auth, signed
/// out with real auth. [overrides] come last, for example
/// `authRepositoryProvider.overrideWithValue(FakeAuthRepository(...))`.
Future<void> pumpApp(
  WidgetTester tester, {
  Env? env,
  AuthState? auth,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Size screen = kIphone17Pro,
  List<Override> overrides = const [],
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
        envProvider.overrideWithValue(env ?? testEnv()),
        appInfoProvider.overrideWith(
          (ref) async => const AppInfo(version: '1.2.3', buildNumber: '45'),
        ),
        if (auth != null)
          authStateProvider.overrideWith(() => TestAuthNotifier(auth)),
        ...overrides,
      ],
      child: const BognerChessApp(),
    ),
  );
  await tester.pumpAndSettle();
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(BognerChessApp)));

GoRouter routerOf(WidgetTester tester) =>
    containerOf(tester).read(routerProvider);

/// The path the router currently shows.
String locationOf(WidgetTester tester) =>
    routerOf(tester).routerDelegate.currentConfiguration.uri.path;
