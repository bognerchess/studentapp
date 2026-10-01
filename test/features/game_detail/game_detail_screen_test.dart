// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/chess/board_thumbnail.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:bogner_chess/core/ui/widgets/error_retry.dart';
import 'package:bogner_chess/features/game_detail/ui/game_detail_ids.dart';
import 'package:bogner_chess/features/game_detail/ui/game_detail_screen.dart';
import 'package:bogner_chess/features/library/ui/library_row_tile.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fixture_link.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_screen.dart';
import '../../helpers/workflow_fixtures.dart';

const owner = kFakeAuthSub;

/// `game-1` of the fixtures: analysed, with a finished job.
const analysedGame = 'game-1';

/// `game-3`: no analysis, no job.
const freshGame = 'game-3';

/// A player line of the game screen: one `Text.rich` (name and rating in one
/// paragraph), and not the library row of the same game behind it.
Finder player(String text) => find.descendant(
  of: find.byType(GameDetailScreen),
  matching: find.textContaining(text, findRichText: true),
);

/// Pumps a few frames instead of settling.
///
/// The progress card of a running job carries an indeterminate progress
/// indicator, which animates for ever: `pumpAndSettle` would never return
/// once a job is under way.
Future<void> pumpFrames(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Answers `RunCoaching` with an accepted run for the game that was asked
/// about (the fixture always names `game-1`).
void acceptCoaching(FixtureLink api) {
  api.respond('RunCoaching', (variables) {
    final body = api.store.response('RunCoaching', 'default');
    final payload =
        (body['data'] as Map)['runCoaching'] as Map<String, dynamic>;
    (payload['engineStageRun'] as Map)['chessGameId'] =
        (variables['input'] as Map)['chessGameId'];
    return body;
  });
}

/// Answers `AnalyseGame` with the accepted workflow of the game that was asked
/// about, optionally with the reason the chain stops short of the coach.
void acceptAnalyse(FixtureLink api, {String? targetReason}) {
  api.respond('AnalyseGame', (variables) {
    final body = api.store.response(
      'AnalyseGame',
      targetReason == null ? 'default' : 'no_coach',
    );
    final payload =
        (body['data'] as Map)['analyseGame'] as Map<String, dynamic>;
    final workflow = payload['gameAnalysisWorkflow'] as Map<String, dynamic>;
    workflow['chessGameId'] = (variables['input'] as Map)['chessGameId'];
    if (targetReason != null) {
      workflow['targetReason'] = targetReason;
    }
    return body;
  });
}

/// The `GameById` answer for [gameId]: its row of the list fixture plus the
/// moves of the detail fixture. [patch] changes the game before it goes out.
Map<String, dynamic> gameById(
  FixtureLink api,
  Object? gameId, {
  void Function(Map<String, dynamic> game)? patch,
}) {
  final detail =
      api.store.data('GameById', 'default')['myChessGameById']
          as Map<String, dynamic>;
  final nodes =
      (api.store.data('MyMobileGames', 'default')['myMobileGames']
              as Map<String, dynamic>)['nodes']
          as List;
  final row = nodes.cast<Map<String, dynamic>>().firstWhere(
    (node) => node['id'] == gameId,
    orElse: () => detail,
  );
  final game = <String, dynamic>{...detail, ...row};
  patch?.call(game);
  return {
    'data': {'myChessGameById': game},
  };
}

void main() {
  late AppDatabase db;
  late FixtureLink api;

  setUp(() {
    db = openWidgetTestDatabase();
    api = FixtureLink();
    // GameById has one fixture; the screen is opened for several games, so
    // the answer is built from the list fixture of the requested id.
    api.respond('GameById', (variables) => gameById(api, variables['id']));
    acceptCoaching(api);
    acceptAnalyse(api);
  });
  tearDown(() => db.close());

  List<Override> overrides([List<Override> more = const []]) => [
    appDatabaseProvider.overrideWithValue(db),
    ...api.overrides,
    ...more,
  ];

  /// Mounts the game screen of [gameId], as a tap on a library row opens it.
  Future<void> openGame(
    WidgetTester tester, {
    String gameId = freshGame,
    List<Override> more = const [],
    Locale locale = const Locale('en'),
    Brightness brightness = Brightness.light,
    double textScale = 1.0,
    Size screen = kIphone17Pro,
  }) async {
    await pumpScreen(
      tester,
      GameDetailScreen(gameId: gameId),
      overrides: overrides(more),
      locale: locale,
      brightness: brightness,
      textScale: textScale,
      screenSize: screen,
      settle: false,
    );
    await pumpFrames(tester);
  }

  Future<void> tapId(WidgetTester tester, String identifier) async {
    await tester.tap(find.bySemanticsIdentifier(identifier));
    await pumpFrames(tester);
  }

  Future<void> tapAnalyse(WidgetTester tester) =>
      tapId(tester, GameDetailIds.analyse);

  /// Whether the button with [identifier] is enabled. `byType` is exact, and
  /// the card uses both `FilledButton` and `TextButton`, so the predicate.
  bool isEnabled(WidgetTester tester, String identifier) =>
      tester
          .widgetList<ButtonStyleButton>(
            find.descendant(
              of: find.bySemanticsIdentifier(identifier),
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            ),
          )
          .first
          .onPressed !=
      null;

  /// The value of the card's progress bar; null means indeterminate.
  double? progressValue(WidgetTester tester) => tester
      .widget<LinearProgressIndicator>(
        find.descendant(
          of: find.bySemanticsIdentifier(GameDetailIds.progress),
          matching: find.byType(LinearProgressIndicator),
        ),
      )
      .value;

  /// Opens a game whose analysis stands at [scenario].
  Future<void> openAt(
    WidgetTester tester,
    String scenario, {
    String gameId = freshGame,
    void Function(List<Map<String, dynamic>> stages)? patch,
    void Function(Map<String, dynamic> workflow)? patchWorkflow,
    Locale locale = const Locale('en'),
    List<Override> more = const [],
  }) async {
    await openGame(
      tester,
      gameId: gameId,
      locale: locale,
      more: [
        tracking(
          gameId,
          workflowFixture(
            api.store,
            scenario,
            patch: patch,
            patchWorkflow: patchWorkflow,
          ),
        ),
        ...more,
      ],
    );
  }

  group('header', () {
    testWidgets('players, result, date, event, time control, final position', (
      tester,
    ) async {
      await openGame(tester, gameId: analysedGame);

      expect(player('Fake User'), findsOneWidget);
      expect(player('Jonas Keller'), findsOneWidget);
      expect(player('1650'), findsOneWidget);
      expect(player('1712'), findsOneWidget);
      expect(find.text('1-0 · You won'), findsOneWidget);
      expect(find.text('Sep 12, 2026'), findsOneWidget);
      expect(find.text('Club Championship'), findsOneWidget);
      expect(find.text('Classical · 90+30'), findsOneWidget);
      expect(find.text('8 moves'), findsOneWidget);
      expect(find.text('Final position'), findsOneWidget);
      expect(find.byType(BoardThumbnail), findsOneWidget);
    });

    testWidgets('missing names fall back, a draw reads as a draw', (
      tester,
    ) async {
      await openGame(tester, gameId: freshGame);
      expect(player('White'), findsOneWidget);
      expect(player('Anonymous'), findsOneWidget);
      expect(find.text('0-1 · You lost'), findsOneWidget);
      expect(find.text('No date'), findsNothing);
    });

    testWidgets('the cached game shows before the server answers', (
      tester,
    ) async {
      api.delay = const Duration(seconds: 2);
      await pumpApp(tester, overrides: overrides(), settle: false);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));
      await pumpFrames(tester);
      // The library has the games now; open one with the API slow again.
      api.delay = const Duration(seconds: 2);
      unawaited(routerOf(tester).push(AppRoutes.game(analysedGame)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(player('Jonas Keller'), findsOneWidget);
      expect(find.byType(BoardThumbnail), findsNothing, reason: 'no moves yet');
      api.delay = Duration.zero;
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(BoardThumbnail), findsOneWidget);
    });

    testWidgets('a game that is gone says so', (tester) async {
      api.respond(
        'GameById',
        (_) => api.store.response('GameById', 'not_found'),
      );
      await openGame(tester);
      expect(find.text('Game not found'), findsOneWidget);
    });

    testWidgets('offline without a cached copy: retry', (tester) async {
      api.fail('MyMobileGames', const SocketException('offline'));
      api.fail('GameById', const SocketException('offline'));
      await openGame(tester);
      expect(find.byType(ErrorRetry), findsOneWidget);

      api.respond('GameById', (variables) => gameById(api, variables['id']));
      await tester.tap(find.text('Try again'));
      await pumpFrames(tester);
      expect(player('Anonymous'), findsOneWidget);
    });
  });

  group('the analysis card', () {
    testWidgets('nothing yet: what it costs, the quota and one button', (
      tester,
    ) async {
      await openGame(tester);

      expect(find.bySemanticsIdentifier(GameDetailIds.analyse), findsOneWidget);
      expect(find.text('Analyse this game'), findsOneWidget);
      expect(
        find.textContaining('takes about a minute and is free'),
        findsOneWidget,
      );
      // The numbers are a warning, not a gate: they are there before the tap.
      expect(find.textContaining('2 of 3 analyses left today'), findsOneWidget);
      // Nothing of the pipeline is on screen.
      expect(find.text('Engine'), findsNothing);
      expect(find.text('Key positions'), findsNothing);
      expect(find.text('Deep analysis'), findsNothing);
      expect(find.bySemanticsIdentifier(GameDetailIds.progress), findsNothing);
      expect(
        find.bySemanticsIdentifier(GameDetailIds.openAnalysis),
        findsNothing,
      );
    });

    testWidgets('analysing: a real bar and a phase in the user\'s words', (
      tester,
    ) async {
      await openAt(tester, 'running');

      expect(find.text('Analysing your game'), findsOneWidget);
      // 40 % of the wall clock is behind it: the first part is stored.
      expect(progressValue(tester), closeTo(0.4, 0.001));
      expect(find.text('Reading your game…'), findsOneWidget);
      expect(
        find.textContaining('You can leave the app'),
        findsOneWidget,
        reason: 'the hint stays',
      );
      // Nothing about stages, steps or engines.
      expect(find.text('Engine'), findsNothing);
      expect(find.textContaining('step'), findsNothing);
      // Something is already stored, so the review can be opened.
      expect(
        find.bySemanticsIdentifier(GameDetailIds.openAnalysis),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier(GameDetailIds.analyse), findsNothing);
    });

    testWidgets('the deeper part has a phase of its own', (tester) async {
      await openAt(
        tester,
        'engine_ready',
        patch: (stages) => stages[2]['state'] = 'RUNNING',
        patchWorkflow: (workflow) => workflow['state'] = 'ANALYSING',
      );
      expect(find.text('Looking at the critical moments…'), findsOneWidget);
    });

    testWidgets('while the coach writes, the result can already be read', (
      tester,
    ) async {
      await openAt(tester, 'coach_writing');

      expect(find.text('Your coach is writing…'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier(GameDetailIds.openAnalysis),
        findsOneWidget,
        reason: 'the engine result is there to read while the coach writes',
      );
    });

    testWidgets('a server that reports no number gets the moving bar', (
      tester,
    ) async {
      await openAt(
        tester,
        'running',
        patchWorkflow: (workflow) => workflow['progress'] = null,
      );
      expect(progressValue(tester), isNull);
    });

    testWidgets('ready with the coach: the message and no further offer', (
      tester,
    ) async {
      await openAt(tester, 'all_ready');

      expect(find.text('Your analysis is ready.'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier(GameDetailIds.rerunCoach),
        findsNothing,
        reason: 'a run costs this account a quota',
      );
      expect(find.bySemanticsIdentifier(GameDetailIds.analyse), findsNothing);
      await tapId(tester, GameDetailIds.openAnalysis);
      expect(navigatedTo(tester), AppRoutes.gameReview(freshGame));
    });

    testWidgets('ready without the coach: one quiet line says why', (
      tester,
    ) async {
      await openAt(tester, 'no_coach_limit');

      expect(find.text('Your analysis is ready.'), findsOneWidget);
      expect(
        find.text(
          'The coach was not asked: your limit for coach comments is used up.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('2 of 3 analyses left today'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier(GameDetailIds.openAnalysis),
        findsOneWidget,
      );
    });

    testWidgets('a reason this build does not know is still a sentence', (
      tester,
    ) async {
      await openAt(
        tester,
        'unknown_reason',
        patchWorkflow: (workflow) =>
            workflow['targetReason'] = 'COACH_ON_HOLIDAY',
      );
      expect(
        find.text(
          'The coach was not asked: the coach is not available right now.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('failed: it was not counted, and one way on', (tester) async {
      await openAt(tester, 'stage_failed');

      expect(find.text('The analysis failed'), findsOneWidget);
      expect(
        find.textContaining('does not count towards your limit'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      // Nothing names the step that failed.
      expect(find.text('This step failed'), findsNothing);
      expect(find.text('Deep analysis'), findsNothing);
      expect(
        find.bySemanticsIdentifier(GameDetailIds.retryAnalysis),
        findsOneWidget,
      );
    });

    testWidgets('stale: the moves changed, and the way to start over', (
      tester,
    ) async {
      await openAt(tester, 'stale');

      expect(find.text('Your moves changed'), findsOneWidget);
      expect(
        find.text('The analysis was made for the earlier moves.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier(GameDetailIds.reanalyse),
        findsOneWidget,
      );
    });

    testWidgets('a cold open reads the state off the cached row', (
      tester,
    ) async {
      // Nothing is being tracked: the app was killed and started again. The
      // summary the tracker left next to the game is what the card shows.
      await db.gamesCacheDao.upsertPage(owner, [
        CachedGameInput(
          gameId: freshGame,
          summaryJson: jsonEncode({
            'v': 3,
            'id': freshGame,
            'playerColor': 'white',
            'result': '0-1',
            'hasAnalysis': false,
            'workflow': {
              'states': {
                'BASE_EVALUATION': 'READY',
                'BASE_CLASSIFICATION': 'READY',
                'DEEP_EVALUATION': 'READY',
                'COACHING': 'NOT_RUN',
              },
              'isComplete': false,
              'state': 'READY',
              'targetReason': 'LIMIT_REACHED',
            },
          }),
          updatedAt: DateTime.utc(2026, 8),
        ),
      ], fetchedAt: DateTime.utc(2026, 8));

      await openGame(tester);
      expect(find.text('Your analysis is ready.'), findsOneWidget);
      expect(find.textContaining('The coach was not asked'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier(GameDetailIds.openAnalysis),
        findsOneWidget,
      );
    });

    testWidgets('a row from before WP-61 reads its stage states', (
      tester,
    ) async {
      await db.gamesCacheDao.upsertPage(owner, [
        CachedGameInput(
          gameId: freshGame,
          summaryJson: jsonEncode({
            'v': 2,
            'id': freshGame,
            'playerColor': 'white',
            'result': '0-1',
            'hasAnalysis': false,
            'workflow': {
              'states': {'BASE_EVALUATION': 'RUNNING'},
              'isComplete': false,
            },
          }),
          updatedAt: DateTime.utc(2026, 8),
        ),
      ], fetchedAt: DateTime.utc(2026, 8));

      await openGame(tester);
      expect(find.text('Analysing your game'), findsOneWidget);
      expect(find.text('Reading your game…'), findsOneWidget);
    });

    testWidgets(
      'a game analysed elsewhere: the ready card without a workflow',
      (tester) async {
        await openGame(tester, gameId: analysedGame);
        expect(find.text('Your analysis is ready.'), findsOneWidget);
        expect(
          find.bySemanticsIdentifier(GameDetailIds.openAnalysis),
          findsOneWidget,
        );
      },
    );
  });

  group('analysing', () {
    testWidgets('Analyse sends one request and records the game', (
      tester,
    ) async {
      await openGame(tester, more: pollingOverrides());
      await tapAnalyse(tester);

      final input =
          api.requestsOf('AnalyseGame').single.variables['input'] as Map;
      expect(input['chessGameId'], freshGame);
      expect(input['language'], 'en');
      // Not one of the four stage commands: the server chains them.
      expect(api.requestsOf('RunBaseEvaluation'), isEmpty);
      expect(api.requestsOf('RunBaseClassification'), isEmpty);
      expect(api.requestsOf('RunDeepEvaluation'), isEmpty);
      expect(api.requestsOf('RunCoaching'), isEmpty);
      // The row the tracker watches.
      final row = await db.pendingWorkflowsDao.get(owner, freshGame);
      expect(row!.targetStage, 'COACHING');
      // The numbers under the button may have changed.
      expect(api.requestsOf('MyAnalysisUsage').length, greaterThan(1));
    });

    testWidgets('the coach language follows the app language', (tester) async {
      await openGame(tester, locale: const Locale('de'));
      await tapAnalyse(tester);
      final input =
          api.requestsOf('AnalyseGame').single.variables['input'] as Map;
      expect(input['language'], 'de');
    });

    testWidgets('the button is dark the moment it is pressed', (tester) async {
      await openGame(tester);
      expect(isEnabled(tester, GameDetailIds.analyse), isTrue);

      // A slow answer: the state has to be in the frame after the tap, not in
      // the one after the answer.
      api.delay = const Duration(seconds: 2);
      await tester.tap(find.bySemanticsIdentifier(GameDetailIds.analyse));
      await tester.pump();
      expect(isEnabled(tester, GameDetailIds.analyse), isFalse);

      api.delay = Duration.zero;
      await pumpFrames(tester, 40);
      expect(api.requestsOf('AnalyseGame'), hasLength(1));
    });

    testWidgets('at the limit the request still goes out', (tester) async {
      // The server counts limit pressure when it decides not to ask the coach,
      // so the app must not decide on its own that a request is pointless.
      api.use('MyAnalysisUsage', 'limit_reached');
      acceptAnalyse(api, targetReason: 'LIMIT_REACHED');
      await openGame(tester);
      expect(find.textContaining('No analyses left today'), findsOneWidget);
      expect(isEnabled(tester, GameDetailIds.analyse), isTrue);

      await tapAnalyse(tester);
      expect(api.requestsOf('AnalyseGame'), hasLength(1));
      expect(
        find.bySemanticsIdentifier(GameDetailIds.limitSheet),
        findsOneWidget,
      );
    });

    testWidgets('Try again sends the same request, which resumes', (
      tester,
    ) async {
      await openAt(tester, 'stage_failed', more: pollingOverrides());
      await tapId(tester, GameDetailIds.retryAnalysis);

      expect(api.requestsOf('AnalyseGame'), hasLength(1));
      expect(api.requestsOf('RunDeepEvaluation'), isEmpty);
    });

    testWidgets('Analyse again after the moves changed is the same request', (
      tester,
    ) async {
      await openAt(tester, 'stale');
      await tapId(tester, GameDetailIds.reanalyse);
      expect(api.requestsOf('AnalyseGame'), hasLength(1));
    });

    testWidgets('rate limited: a line with the wait', (tester) async {
      api.use('AnalyseGame', 'rate_limited');
      await openGame(tester);
      await tapAnalyse(tester);

      expect(
        find.text('Too many requests. Try again in 42 seconds.'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier(GameDetailIds.analyse), findsOneWidget);
    });

    testWidgets('offline: a line, and the button stays', (tester) async {
      api.fail('AnalyseGame', const SocketException('offline'));
      await openGame(tester);
      await tapAnalyse(tester);

      expect(
        find.text("You're offline. Connect to the internet and try again."),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier(GameDetailIds.analyse), findsOneWidget);
    });

    testWidgets('a refused request: a line, and the button stays', (
      tester,
    ) async {
      api.use('AnalyseGame', 'technical_error');
      await openGame(tester);
      await tapAnalyse(tester);

      expect(
        find.text('The analysis could not be requested. Try again.'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier(GameDetailIds.analyse), findsOneWidget);
    });
  });

  group('why there is no coach text', () {
    testWidgets('limit reached: a sheet with the numbers and the reassurance', (
      tester,
    ) async {
      acceptAnalyse(api, targetReason: 'LIMIT_REACHED');
      await openGame(tester);
      await tapAnalyse(tester);

      expect(
        find.bySemanticsIdentifier(GameDetailIds.limitSheet),
        findsOneWidget,
      );
      expect(find.text('Daily limit reached'), findsOneWidget);
      expect(
        find.text(
          'You can have 3 games analysed per day, and you\'ve used them all '
          'today.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('You can request analyses again from'),
        findsOneWidget,
      );
      // The point of the whole sheet: the analysis is running regardless.
      expect(
        find.text(
          'Your analysis is running. Only the coach\'s comments are missing.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Entering, importing and reviewing games is never limited.'),
        findsOneWidget,
      );

      await tapId(tester, GameDetailIds.sheetClose);
      expect(find.text('Daily limit reached'), findsNothing);
    });

    testWidgets('a monthly limit names the month', (tester) async {
      api.use('MyAnalysisUsage', 'limit_reached');
      api.respond('MyAnalysisUsage', (_) {
        final body = api.store.response('MyAnalysisUsage', 'limit_reached');
        ((body['data'] as Map)['myAnalysisUsage'] as Map)['monthlyUsed'] = 30;
        return body;
      });
      acceptAnalyse(api, targetReason: 'LIMIT_REACHED');
      await openGame(tester);
      await tapAnalyse(tester);

      expect(find.text('Monthly limit reached'), findsOneWidget);
    });

    testWidgets('queue full: a line, not a sheet', (tester) async {
      acceptAnalyse(api, targetReason: 'QUEUE_FULL');
      await openGame(tester);
      await tapAnalyse(tester);

      expect(
        find.textContaining(
          'too many of your games are being analysed at once',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Your analysis is running'), findsOneWidget);
    });

    testWidgets('e-mail not verified: explain, re-check, then it goes', (
      tester,
    ) async {
      acceptAnalyse(api, targetReason: 'EMAIL_NOT_VERIFIED');
      await openGame(tester);
      await tapAnalyse(tester);

      expect(find.text('Confirm your e-mail address'), findsOneWidget);

      // Still not confirmed: the sheet stays and says so.
      await tapId(tester, GameDetailIds.emailRecheck);
      expect(find.text('Your address is not confirmed yet.'), findsOneWidget);
      expect(api.requestsOf('AnalyseGame'), hasLength(2));

      // The user opened the link: the next request reaches the coach.
      acceptAnalyse(api);
      await tapId(tester, GameDetailIds.emailRecheck);
      expect(find.text('Confirm your e-mail address'), findsNothing);
      expect(api.requestsOf('AnalyseGame'), hasLength(3));
    });

    testWidgets('AI consent: the screen opens and the request is repeated', (
      tester,
    ) async {
      acceptAnalyse(api, targetReason: 'AI_CONSENT_REQUIRED');
      await openGame(tester);
      await tapAnalyse(tester);

      expect(navigatedTo(tester), AppRoutes.consentAi);
      expect(api.requestsOf('AnalyseGame'), hasLength(1));

      // The consent screen pops with true (WP-30 records the consent).
      acceptAnalyse(api);
      popNavigatedTo(tester, true);
      await pumpFrames(tester);

      expect(api.requestsOf('AnalyseGame'), hasLength(2));
    });

    testWidgets('AI consent declined: nothing is requested again', (
      tester,
    ) async {
      acceptAnalyse(api, targetReason: 'AI_CONSENT_REQUIRED');
      await openGame(tester);
      await tapAnalyse(tester);

      popNavigatedTo(tester, false);
      await pumpFrames(tester);
      expect(api.requestsOf('AnalyseGame'), hasLength(1));
      expect(
        find.text('The analysis needs your consent to AI processing.'),
        findsOneWidget,
      );
    });
  });

  group('running the coach again', () {
    testWidgets('only an account without a limit is offered it', (
      tester,
    ) async {
      api.use('MyAnalysisUsage', 'unlimited');
      await openAt(tester, 'all_ready');

      expect(find.text('Your analysis is ready.'), findsOneWidget);
      expect(find.text('Run the coach again'), findsOneWidget);

      await tapId(tester, GameDetailIds.rerunCoach);
      final input =
          api.requestsOf('RunCoaching').single.variables['input'] as Map;
      expect(input['chessGameId'], freshGame);
      expect(
        api.requestsOf('AnalyseGame'),
        isEmpty,
        reason: 'the one stage the app still starts on its own',
      );
    });

    testWidgets('it is not offered before the coach has written', (
      tester,
    ) async {
      api.use('MyAnalysisUsage', 'unlimited');
      await openAt(tester, 'no_coach_limit');
      expect(
        find.bySemanticsIdentifier(GameDetailIds.rerunCoach),
        findsNothing,
      );
    });

    testWidgets('a refusal is explained the way it always was', (tester) async {
      api
        ..use('MyAnalysisUsage', 'unlimited')
        ..use('RunCoaching', 'queue_full');
      await openAt(tester, 'all_ready');
      await tapId(tester, GameDetailIds.rerunCoach);

      expect(find.text('Too many analyses at once'), findsOneWidget);
    });
  });

  group('delete', () {
    testWidgets('confirm: gone on the server, and the screen closes', (
      tester,
    ) async {
      await openGame(tester, gameId: analysedGame);
      await tester.tap(find.bySemanticsIdentifier(GameDetailIds.delete));
      await pumpFrames(tester);
      expect(find.text('Delete this game?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await pumpFrames(tester);

      expect(
        api.requestsOf('DeleteChessGame').single.variables.toString(),
        contains(analysedGame),
      );
      // Closed: back to whatever opened it, which is the library.
      expect(navigatedTo(tester), kCallerRoute);
      expect(find.text('Game deleted'), findsOneWidget);
    });

    testWidgets('and the library no longer has it', (tester) async {
      // The whole app: what the library shows after the screen is gone.
      await pumpApp(tester, overrides: overrides(), settle: false);
      await pumpFrames(tester);
      unawaited(routerOf(tester).push(AppRoutes.game(analysedGame)));
      await pumpFrames(tester);

      await tester.tap(find.bySemanticsIdentifier(GameDetailIds.delete));
      await pumpFrames(tester);
      await tester.tap(find.text('Delete'));
      await pumpFrames(tester);

      expect(find.text('Fake User – Jonas Keller'), findsNothing);
      expect(find.byType(LibraryRowTile), findsNWidgets(2));
    });

    testWidgets('cancel changes nothing', (tester) async {
      await openGame(tester, gameId: analysedGame);
      await tester.tap(find.bySemanticsIdentifier(GameDetailIds.delete));
      await pumpFrames(tester);
      await tester.tap(find.text('Cancel'));
      await pumpFrames(tester);
      expect(api.requestsOf('DeleteChessGame'), isEmpty);
      expect(navigatedTo(tester), isNull);
    });
  });

  group('languages and sizes', () {
    testWidgets('German', (tester) async {
      await openGame(tester, locale: const Locale('de'));

      expect(find.text('Partie analysieren'), findsOneWidget);
      expect(
        find.textContaining('dauert etwa eine Minute und ist kostenlos'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Heute noch 2 von 3 Analysen'),
        findsOneWidget,
      );
      expect(player('Weiss'), findsOneWidget);
      expect(find.text('0-1 · Du hast verloren'), findsOneWidget);
      expect(find.text('Schlussstellung'), findsOneWidget);

      acceptAnalyse(api, targetReason: 'LIMIT_REACHED');
      await tapAnalyse(tester);
      expect(find.text('Tageslimit erreicht'), findsOneWidget);
      expect(
        find.text(
          'Partien eingeben, importieren und ansehen kannst du immer '
          'unbegrenzt.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('German: the phase while the coach writes', (tester) async {
      await openAt(tester, 'coach_writing', locale: const Locale('de'));
      expect(find.text('Dein Coach schreibt…'), findsOneWidget);
    });

    testWidgets('German: the quiet line about the coach', (tester) async {
      await openAt(tester, 'no_coach_limit', locale: const Locale('de'));
      expect(
        find.text(
          'Der Coach wurde nicht gefragt: dein Limit für Coach-Kommentare '
          'ist aufgebraucht.',
        ),
        findsOneWidget,
      );
    });

    for (final locale in const [Locale('en'), Locale('de')]) {
      for (final brightness in Brightness.values) {
        testWidgets('$locale ${brightness.name}: text scale 1.3 on the SE', (
          tester,
        ) async {
          acceptAnalyse(api, targetReason: 'LIMIT_REACHED');
          await openGame(
            tester,
            gameId: analysedGame,
            locale: locale,
            brightness: brightness,
            textScale: 1.3,
            screen: kIphoneSe,
            // The tallest card: the hint, the quota line and both buttons.
            more: [
              tracking(
                analysedGame,
                workflowFixture(api.store, 'no_coach_limit'),
              ),
            ],
          );
          expect(tester.takeException(), isNull);
          expect(
            MediaQuery.textScalerOf(tester.element(player('Jonas Keller')))
                .scale(10),
            13,
          );
          expect(
            Theme.of(tester.element(player('Jonas Keller'))).brightness,
            brightness,
          );

          await tester.scrollUntilVisible(
            find.bySemanticsIdentifier(GameDetailIds.openAnalysis),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await pumpFrames(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
