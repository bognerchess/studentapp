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
import 'package:bogner_chess/features/usage/usage.dart';
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
    api = FixtureLink({'MyActiveAnalysisJobs': 'empty'});
    // GameById has one fixture; the screen is opened for several games, so
    // the answer is built from the list fixture of the requested id.
    api.respond('GameById', (variables) => gameById(api, variables['id']));
    acceptCoaching(api);
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

  Future<void> tapAskCoach(WidgetTester tester) =>
      tapId(tester, GameDetailIds.askCoach);

  /// The state text of one stage row, as the strip prints it.
  String stateOfRow(WidgetTester tester, AnalysisStage stage) {
    final row = find.bySemanticsIdentifier(GameDetailIds.stageRow(stage));
    return tester
        .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
        .last
        .data!;
  }

  /// Opens a game whose pipeline stands at [scenario].
  Future<void> openAt(
    WidgetTester tester,
    String scenario, {
    String gameId = freshGame,
    void Function(List<Map<String, dynamic>> stages)? patch,
    Locale locale = const Locale('en'),
  }) async {
    await openGame(
      tester,
      gameId: gameId,
      locale: locale,
      more: [
        tracking(gameId, workflowFixture(api.store, scenario, patch: patch)),
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

  group('the stage strip', () {
    testWidgets('nothing run: the hint and the free button', (tester) async {
      await openGame(tester);
      expect(find.bySemanticsIdentifier(GameDetailIds.analyse), findsOneWidget);
      expect(
        find.textContaining('marks the positions worth a closer look'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier(UsageSummary.semanticsId),
        findsNothing,
        reason: 'the engine stages are free, so no quota is shown',
      );
      expect(
        find.bySemanticsIdentifier(GameDetailIds.stageStrip),
        findsNothing,
      );
    });

    testWidgets('running: a row per stage, and a bar on the one that moves', (
      tester,
    ) async {
      await openAt(tester, 'running');

      expect(
        find.bySemanticsIdentifier(GameDetailIds.stageStrip),
        findsOneWidget,
      );
      expect(find.text('Analysing your game'), findsOneWidget);
      expect(find.text('Engine'), findsOneWidget);
      expect(find.text('Key positions'), findsOneWidget);
      expect(find.text('Deep analysis'), findsOneWidget);
      expect(find.text('Coach'), findsOneWidget);
      expect(stateOfRow(tester, AnalysisStage.baseEvaluation), 'Ready');
      expect(
        stateOfRow(tester, AnalysisStage.baseClassification),
        'Running\u2026',
      );
      expect(stateOfRow(tester, AnalysisStage.deepEvaluation), 'Not started');
      expect(stateOfRow(tester, AnalysisStage.coaching), 'Not started');
      // Nothing is known about how far it is, so the bar is indeterminate.
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );
      expect(
        find.textContaining('You can leave the app'),
        findsOneWidget,
        reason: 'the hint stays',
      );
      // Stage 1 is stored, so there is already something to read.
      expect(
        find.bySemanticsIdentifier(GameDetailIds.openAnalysis),
        findsOneWidget,
      );
    });

    testWidgets('a stage that reports progress counts it out', (tester) async {
      await openAt(
        tester,
        'running',
        patch: (stages) {
          (stages[1]['run'] as Map)
            ..['progressDone'] = 12
            ..['progressTotal'] = 40;
        },
      );

      expect(stateOfRow(tester, AnalysisStage.baseClassification), '12 of 40');
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(0.3, 0.001),
      );
    });

    testWidgets('a queued stage waits, without a bar', (tester) async {
      await openAt(
        tester,
        'running',
        patch: (stages) => stages[1]['state'] = 'QUEUED',
      );

      expect(stateOfRow(tester, AnalysisStage.baseClassification), 'Waiting');
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('engine ready: the coach, what it costs and the quota', (
      tester,
    ) async {
      await openAt(tester, 'engine_ready');

      expect(
        find.bySemanticsIdentifier(GameDetailIds.askCoach),
        findsOneWidget,
      );
      expect(
        find.text(
          'The coach writes about your key moments. This is the only step '
          'that counts against your quota.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('2 of 3 analyses left today'), findsOneWidget);
      expect(stateOfRow(tester, AnalysisStage.deepEvaluation), 'Ready');
      expect(stateOfRow(tester, AnalysisStage.coaching), 'Not started');
      expect(
        find.bySemanticsIdentifier(GameDetailIds.openAnalysis),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier(GameDetailIds.analyse), findsNothing);
    });

    testWidgets('coach ready: the ready message, and no coach button', (
      tester,
    ) async {
      await openAt(tester, 'all_ready');

      expect(find.text('Your analysis is ready.'), findsOneWidget);
      expect(find.bySemanticsIdentifier(GameDetailIds.askCoach), findsNothing);
      await tapId(tester, GameDetailIds.openAnalysis);
      expect(navigatedTo(tester), AppRoutes.gameReview(freshGame));
    });

    testWidgets('a failed stage: what happened, and a retry of that step', (
      tester,
    ) async {
      await openAt(tester, 'stage_failed');

      expect(find.text('This step failed'), findsOneWidget);
      expect(
        find.text('An earlier step has to run again.'),
        findsOneWidget,
        reason: 'the fixture fails with stage_input_missing',
      );
      expect(stateOfRow(tester, AnalysisStage.deepEvaluation), 'Failed');
      expect(
        find.bySemanticsIdentifier(GameDetailIds.retryStage),
        findsOneWidget,
      );
    });

    testWidgets('a failure code this build does not know: the generic text', (
      tester,
    ) async {
      await openAt(
        tester,
        'stage_failed',
        patch: (stages) =>
            (stages[2]['run'] as Map)['failureCode'] = 'gremlins',
      );
      expect(
        find.textContaining('does not count towards your limit'),
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

    testWidgets('a cold open reads the pipeline off the cached row', (
      tester,
    ) async {
      // Nothing is being tracked: the app was killed and started again. The
      // summary the tracker left next to the game is what the card shows.
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
              'states': {
                'BASE_EVALUATION': 'READY',
                'BASE_CLASSIFICATION': 'READY',
                'DEEP_EVALUATION': 'READY',
                'COACHING': 'NOT_RUN',
              },
              'isComplete': false,
            },
          }),
          updatedAt: DateTime.utc(2026, 8),
        ),
      ], fetchedAt: DateTime.utc(2026, 8));

      await openGame(tester);
      expect(
        find.bySemanticsIdentifier(GameDetailIds.askCoach),
        findsOneWidget,
      );
      expect(stateOfRow(tester, AnalysisStage.deepEvaluation), 'Ready');
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

  group('starting the free chain', () {
    /// The chain is started by the tracker, not by the button: the button
    /// writes the row and the poll that follows fires the stage the server
    /// says is next. So these tests need a tracker that polls.
    Future<void> open(
      WidgetTester tester, {
      String scenario = 'not_run',
      Locale locale = const Locale('en'),
    }) async {
      api.use('GameAnalysisWorkflow', scenario);
      await openGame(tester, locale: locale, more: pollingOverrides());
    }

    testWidgets('Analyse starts the base evaluation and records the game', (
      tester,
    ) async {
      await open(tester);
      await tapAnalyse(tester);

      final request = api.requestsOf('RunBaseEvaluation').single;
      expect((request.variables['input'] as Map)['chessGameId'], freshGame);
      // Written before the mutation went out, so an app kill resumes it.
      final row = await db.pendingWorkflowsDao.get(owner, freshGame);
      expect(row!.targetStage, 'DEEP_EVALUATION');
      expect(api.requestsOf('RunCoaching'), isEmpty);
    });

    testWidgets('a pipeline already past stage 1 starts where it stands', (
      tester,
    ) async {
      // "Analyse" on a game whose base evaluation is stored must not run
      // stage 1 again; the server's nextRunnableStage decides.
      await open(tester, scenario: 'stage_failed');
      await tapAnalyse(tester);

      expect(api.requestsOf('RunBaseEvaluation'), isEmpty);
      expect(api.requestsOf('RunDeepEvaluation'), hasLength(1));
    });

    testWidgets('retrying a failed step starts the chain again', (
      tester,
    ) async {
      api.use('GameAnalysisWorkflow', 'stage_failed');
      await openGame(
        tester,
        more: [
          tracking(freshGame, workflowFixture(api.store, 'stage_failed')),
          ...pollingOverrides(),
        ],
      );
      await tapId(tester, GameDetailIds.retryStage);

      expect(api.requestsOf('RunDeepEvaluation'), hasLength(1));
    });

    testWidgets('rate limited: a line with the wait', (tester) async {
      api.use('RunBaseEvaluation', 'rate_limited');
      await open(tester);
      await tapAnalyse(tester);

      expect(
        find.text('Too many requests. Try again in 42 seconds.'),
        findsOneWidget,
      );
    });

    testWidgets('a missing prerequisite points at the earlier step', (
      tester,
    ) async {
      api.use('RunBaseEvaluation', 'prerequisite_missing');
      await open(tester);
      await tapAnalyse(tester);

      expect(find.text('An earlier step has to run again.'), findsOneWidget);
    });

    testWidgets('offline: a line, and the button stays', (tester) async {
      api.fail('RunBaseEvaluation', const SocketException('offline'));
      await open(tester);
      await tapAnalyse(tester);

      expect(
        find.text("You're offline. Connect to the internet and try again."),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier(GameDetailIds.analyse), findsOneWidget);
    });

    testWidgets('a refused stage: a line, and the button stays', (
      tester,
    ) async {
      api.use('RunBaseEvaluation', 'technical_error');
      await open(tester);
      await tapAnalyse(tester);

      expect(
        find.text('The analysis could not be requested. Try again.'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier(GameDetailIds.analyse), findsOneWidget);
    });
  });

  group('asking the coach', () {
    /// A game whose three engine stages are stored: the one state in which
    /// the coach button is there.
    Future<void> open(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) => openAt(tester, 'engine_ready', locale: locale);

    testWidgets('accepted: the run is followed and the usage asked again', (
      tester,
    ) async {
      await open(tester);
      await tapAskCoach(tester);

      final input =
          api.requestsOf('RunCoaching').single.variables['input'] as Map;
      expect(input['chessGameId'], freshGame);
      expect(input['language'], 'en');
      // The tracker was told to follow the coaching stage.
      final row = await db.pendingWorkflowsDao.get(owner, freshGame);
      expect(row!.targetStage, 'COACHING');
      expect(api.requestsOf('MyAnalysisUsage').length, greaterThan(1));
    });

    testWidgets('the coach language follows the device language', (
      tester,
    ) async {
      await open(tester, locale: const Locale('de'));
      await tapAskCoach(tester);
      final input =
          api.requestsOf('RunCoaching').single.variables['input'] as Map;
      expect(input['language'], 'de');
    });

    testWidgets('limit reached: a sheet says what, when and what stays free', (
      tester,
    ) async {
      api.use('RunCoaching', 'limit_reached');
      await open(tester);
      await tapAskCoach(tester);

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
      expect(
        find.text('Your game is saved. You can have it analysed later.'),
        findsOneWidget,
      );
      expect(
        find.text('Entering, importing and reviewing games is never limited.'),
        findsOneWidget,
      );

      await tapId(tester, GameDetailIds.sheetClose);
      expect(find.text('Daily limit reached'), findsNothing);
      expect(
        find.bySemanticsIdentifier(GameDetailIds.askCoach),
        findsOneWidget,
      );
    });

    testWidgets('at the limit the request still goes out', (tester) async {
      // The server counts limit pressure when it refuses, so the app must
      // not decide on its own that a request is pointless.
      api
        ..use('MyAnalysisUsage', 'limit_reached')
        ..use('RunCoaching', 'limit_reached');
      await open(tester);
      expect(find.textContaining('No analyses left today'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.bySemanticsIdentifier(GameDetailIds.askCoach),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNotNull, reason: 'never a gate');

      await tapAskCoach(tester);
      expect(api.requestsOf('RunCoaching'), hasLength(1));
      expect(
        find.bySemanticsIdentifier(GameDetailIds.limitSheet),
        findsOneWidget,
      );
    });

    testWidgets('a monthly limit names the month', (tester) async {
      api.use('RunCoaching', 'limit_reached_month');
      await open(tester);
      await tapAskCoach(tester);
      expect(find.text('Monthly limit reached'), findsOneWidget);
    });

    testWidgets('queue full: how many at a time', (tester) async {
      api.use('RunCoaching', 'queue_full');
      await open(tester);
      await tapAskCoach(tester);
      expect(find.text('Too many analyses at once'), findsOneWidget);
      expect(
        find.textContaining('Only 2 of your games can be analysed at a time'),
        findsOneWidget,
      );
    });

    testWidgets('rate limited: a line with the wait', (tester) async {
      api.use('RunCoaching', 'rate_limited');
      await open(tester);
      await tapAskCoach(tester);
      expect(
        find.text('Too many requests. Try again in 42 seconds.'),
        findsOneWidget,
      );
    });

    testWidgets('e-mail not verified: explain, re-check, then it goes', (
      tester,
    ) async {
      api.use('RunCoaching', 'email_not_verified');
      await open(tester);
      await tapAskCoach(tester);

      expect(find.text('Confirm your e-mail address'), findsOneWidget);

      // Still not verified: the sheet stays and says so.
      await tapId(tester, GameDetailIds.emailRecheck);
      expect(find.text('Your address is not confirmed yet.'), findsOneWidget);
      expect(api.requestsOf('RunCoaching'), hasLength(2));

      // The user opened the link: the next request is accepted.
      acceptCoaching(api);
      await tapId(tester, GameDetailIds.emailRecheck);
      expect(find.text('Confirm your e-mail address'), findsNothing);
      expect(api.requestsOf('RunCoaching'), hasLength(3));
    });

    testWidgets('AI consent: the screen opens and the request is repeated', (
      tester,
    ) async {
      api.use('RunCoaching', 'ai_consent_required');
      await open(tester);
      await tapAskCoach(tester);

      expect(navigatedTo(tester), AppRoutes.consentAi);
      expect(api.requestsOf('RunCoaching'), hasLength(1));

      // The consent screen pops with true (WP-30 records the consent).
      acceptCoaching(api);
      popNavigatedTo(tester, true);
      await pumpFrames(tester);

      expect(api.requestsOf('RunCoaching'), hasLength(2));
    });

    testWidgets('AI consent declined: nothing is requested again', (
      tester,
    ) async {
      api.use('RunCoaching', 'ai_consent_required');
      await open(tester);
      await tapAskCoach(tester);

      popNavigatedTo(tester, false);
      await pumpFrames(tester);
      expect(api.requestsOf('RunCoaching'), hasLength(1));
      expect(
        find.text('The analysis needs your consent to AI processing.'),
        findsOneWidget,
      );
    });

    testWidgets('offline: a line, and the button stays', (tester) async {
      api.fail('RunCoaching', const SocketException('offline'));
      await open(tester);
      await tapAskCoach(tester);
      expect(
        find.text("You're offline. Connect to the internet and try again."),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier(GameDetailIds.askCoach),
        findsOneWidget,
      );
    });

    testWidgets('a refused request: a line', (tester) async {
      api.use('RunCoaching', 'technical_error');
      await open(tester);
      await tapAskCoach(tester);
      expect(
        find.text('The analysis could not be requested. Try again.'),
        findsOneWidget,
      );
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
      await openAt(tester, 'engine_ready', locale: const Locale('de'));
      expect(find.text('Coach fragen'), findsOneWidget);
      expect(find.text('Tiefenanalyse'), findsOneWidget);
      expect(find.text('Schlüsselstellungen'), findsOneWidget);
      expect(
        find.textContaining('Heute noch 2 von 3 Analysen'),
        findsOneWidget,
      );
      expect(player('Weiss'), findsOneWidget);
      expect(find.text('0-1 · Du hast verloren'), findsOneWidget);
      expect(find.text('Schlussstellung'), findsOneWidget);

      api.use('RunCoaching', 'limit_reached');
      await tapAskCoach(tester);
      expect(find.text('Tageslimit erreicht'), findsOneWidget);
      expect(
        find.text(
          'Partien eingeben, importieren und ansehen kannst du immer '
          'unbegrenzt.',
        ),
        findsOneWidget,
      );
    });

    for (final locale in const [Locale('en'), Locale('de')]) {
      for (final brightness in Brightness.values) {
        testWidgets('$locale ${brightness.name}: text scale 1.3 on the SE', (
          tester,
        ) async {
          api.use('RunCoaching', 'limit_reached');
          await openGame(
            tester,
            gameId: analysedGame,
            locale: locale,
            brightness: brightness,
            textScale: 1.3,
            screen: kIphoneSe,
            // The tallest card: four stage rows, the coach hint and the quota.
            more: [
              tracking(
                analysedGame,
                workflowFixture(api.store, 'engine_ready'),
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

          // The tallest sheet, on the smallest screen. The card with four
          // stage rows, the coach hint and the quota pushes the buttons off
          // an SE, so scroll to them the way a finger would.
          await tester.scrollUntilVisible(
            find.bySemanticsIdentifier(GameDetailIds.askCoach),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await pumpFrames(tester);
          await tapAskCoach(tester);
          expect(
            find.bySemanticsIdentifier(GameDetailIds.limitSheet),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
