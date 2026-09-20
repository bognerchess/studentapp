// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'pump_app.dart';

/// Stands in for every screen other than the one under test.
///
/// A screen test mounts one screen. When that screen navigates somewhere
/// else, the test wants to know *that* it did and *where* to — not to build
/// the screen that lives there, with its own providers and requests. So the
/// host router answers every other location with this, showing the location
/// as text.
class Elsewhere extends StatelessWidget {
  const Elsewhere(this.location, {super.key});

  final String location;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(location)));
}

/// The root of a screen test: themes, localisation and a two-entry router.
class ScreenHost extends StatelessWidget {
  const ScreenHost({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    routerConfig: router,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: ThemeMode.system,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
  );
}

/// Where the screen under test was pushed from, so that a screen which pops
/// has somewhere to pop to.
const String kCallerRoute = '/';

/// The location `pumpScreen` puts the screen under test at.
const String kScreenRoute = '/screen-under-test';

/// What the screen under test popped with.
///
/// The screen is pushed the way the app pushes it, so a screen that answers
/// its caller — "agree", "delete this game" — can be tested for the answer:
///
///     final screen = await pumpScreen(tester, const AiConsentScreen());
///     await tester.tap(find.byKey(AiConsentScreen.agreeKey));
///     await tester.pumpAndSettle();
///     expect(screen.popped, isTrue);
///     expect(screen.value, isTrue);
class PumpedScreen {
  /// Whether the screen has popped yet.
  bool popped = false;

  /// The value it popped with, null until then.
  Object? value;
}

/// Mounts a single [screen] with themes, localisation and a router — and
/// nothing else.
///
/// This is what a test about one screen should use. [pumpApp] boots the whole
/// app: the real router with its shell, every wrapper in `app.dart` (update
/// gate, consent prompt, analysis notices) and whatever the start screen
/// requests before the test has even begun. A screen test needs none of that,
/// pays for all of it, and fails when something unrelated changes.
///
/// The host router knows two locations: [kCallerRoute], an [Elsewhere] the
/// screen can pop back to, and [kScreenRoute], the screen itself. Anything the
/// screen navigates to is another [Elsewhere] — assert with [navigatedTo],
/// and answer it with [popNavigatedTo].
///
/// API and database come from [backendOverrides] unless [overrides] bring
/// their own; pass `AccountHarness().overrides` for the usual set of fakes.
Future<PumpedScreen> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Env? env,
  AuthState? auth,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Size screenSize = kIphone17Pro,
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = screenSize * 3;
  tester.platformDispatcher.localesTestValue = [locale];
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  final router = GoRouter(
    initialLocation: kCallerRoute,
    routes: [
      GoRoute(
        path: kCallerRoute,
        builder: (context, state) => const Elsewhere(kCallerRoute),
        routes: [
          GoRoute(
            path: kScreenRoute.substring(1),
            builder: (context, state) => screen,
          ),
        ],
      ),
    ],
    // Every other location: the screen went somewhere, and that is all a
    // screen test needs to see.
    errorBuilder: (context, state) => Elsewhere(state.uri.path),
  );
  addTearDown(router.dispose);

  // A provider the test brings its own override for is left alone.
  bool overridden(Object provider) =>
      overrides.any((o) => identical(o.origin, provider));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...backendOverrides(unless: overrides),
        if (!overridden(envProvider))
          envProvider.overrideWithValue(env ?? testEnv()),
        if (!overridden(appInfoProvider))
          appInfoProvider.overrideWith(
            (ref) async => const AppInfo(version: '1.2.3', buildNumber: '45'),
          ),
        if (auth != null && !overridden(authStateProvider))
          authStateProvider.overrideWith(() => TestAuthNotifier(auth)),
        ...overrides,
      ],
      child: ScreenHost(router: router),
    ),
  );

  // Pushed, not shown from the start: a screen that pops has to have
  // somewhere to pop to, and its answer is worth asserting on.
  final pumped = PumpedScreen();
  unawaited(
    router.push<Object?>(kScreenRoute).then((value) {
      pumped
        ..popped = true
        ..value = value;
    }),
  );

  // Without [settle] the test sees the first frame, e.g. what is on screen
  // while the server has not answered yet.
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return pumped;
}

/// Where the screen under test navigated to, or null while it is the screen
/// on display. [kCallerRoute] means it popped.
String? navigatedTo(WidgetTester tester) {
  final elsewhere = find.byType(Elsewhere);
  if (elsewhere.evaluate().isEmpty) return null;
  return tester.widget<Elsewhere>(elsewhere.last).location;
}

/// Answers the screen under test the way the screen it pushed would: pops
/// the [Elsewhere] on top with [result].
void popNavigatedTo(WidgetTester tester, [Object? result]) =>
    GoRouter.of(tester.element(find.byType(Elsewhere))).pop(result);
