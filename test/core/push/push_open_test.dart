// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/app.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/push/push_message.dart';
import 'package:bogner_chess/core/push/push_platform.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../storage/test_database.dart';
import 'push_test_support.dart';

/// A tapped notification in the running app: one container, the push service
/// started before the first frame, as in `main.dart`.
void main() {
  setUp(() => Log.sink = (_) {});
  tearDown(Log.resetSink);

  const ready = AnalysisReadyMessage(gameId: 'game-1', jobId: 'job-1');

  Future<void> pump(WidgetTester tester, PushHarness h) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = kIphone17Pro * 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: const BognerChessApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  String pathOf(PushHarness h) => h.container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .path;

  testWidgets('a tap opens the review, refreshes the job tracker and is '
      'recorded', (tester) async {
    final h = PushHarness()..service.start();
    await pump(tester, h);
    expect(pathOf(h), AppRoutes.games);

    h.platform.controller.add(const PushOpenedEvent(ready, coldStart: false));
    await tester.pumpAndSettle();

    expect(pathOf(h), AppRoutes.gameReview('game-1'));
    expect(h.listener.calls, ['game-1/job-1']);
    final (name, props) = h.analytics.events.single;
    expect(name, 'analysis_ready_opened');
    expect(props, {'source': 'push', 'cold_start': false});
  });

  testWidgets('a tap that started the app: the event waits on the native '
      'side and is handled before the first frame', (tester) async {
    final h = PushHarness();
    // Buffered by PushHandler before Dart listened.
    h.platform.controller.add(const PushOpenedEvent(ready, coldStart: true));
    h.service.start();
    await pump(tester, h);

    expect(pathOf(h), AppRoutes.gameReview('game-1'));
    expect(h.listener.calls, ['game-1/job-1']);
    expect(h.analytics.events.single.$2['cold_start'], isTrue);
  });

  testWidgets('signed out, the review opens after the sign-in', (tester) async {
    final h = PushHarness(auth: const SignedOut())..service.start();
    await pump(tester, h);

    h.platform.controller.add(const PushOpenedEvent(ready, coldStart: false));
    await tester.pumpAndSettle();
    expect(pathOf(h), AppRoutes.signIn);

    h.auth.set(const SignedIn(alice));
    await tester.pumpAndSettle();
    expect(pathOf(h), AppRoutes.gameReview('game-1'));
  });

  testWidgets('a tap on an unknown kind of notification changes nothing', (
    tester,
  ) async {
    final h = PushHarness()..service.start();
    await pump(tester, h);

    h.platform.controller.add(
      const PushOpenedEvent(
        UnknownPushMessage('weekly_summary'),
        coldStart: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(pathOf(h), AppRoutes.games);
    expect(h.analytics.events, isEmpty);
  });

  testWidgets('the native side knows which review is on screen, so that it '
      'can leave out the banner for it', (tester) async {
    final h = PushHarness()..service.start();
    await pump(tester, h);
    expect(h.platform.visibleGame, isNull);

    h.container.read(routerProvider).go(AppRoutes.gameReview('game 1/ä'));
    await tester.pumpAndSettle();
    expect(h.platform.visibleGame, 'game 1/ä');

    h.container.read(routerProvider).go(AppRoutes.game('game-1'));
    await tester.pumpAndSettle();
    expect(h.platform.visibleGame, isNull);

    h.container.read(routerProvider).go(AppRoutes.gameReview('game-2'));
    await tester.pumpAndSettle();
    expect(h.platform.visibleGame, 'game-2');
    expect(
      h.platform.calls.where((call) => call.startsWith('setVisibleGame')),
      [
        'setVisibleGame(game 1/ä)',
        'setVisibleGame(null)',
        'setVisibleGame(game-2)',
      ],
    );
  });
}
