// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:io';

import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/chess/board_thumbnail.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:bogner_chess/core/ui/widgets/error_retry.dart';
import 'package:bogner_chess/features/analysis_status/domain/job_tracker_providers.dart';
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

/// Answers `RequestGameAnalysis` with an accepted job for the game that was
/// asked about (the fixture always names `game-10`).
void acceptRequests(FixtureLink api) {
  api.respond('RequestGameAnalysis', (variables) {
    final body = api.store.response('RequestGameAnalysis', 'default');
    final payload =
        (body['data'] as Map)['requestGameAnalysis'] as Map<String, dynamic>;
    (payload['analysisJob'] as Map)['chessGameId'] =
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
    acceptRequests(api);
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

  Future<void> tapAnalyse(WidgetTester tester) async {
    await tester.tap(find.bySemanticsIdentifier(GameDetailIds.analyse));
    await pumpFrames(tester);
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

  group('states', () {
    testWidgets('not analysed: the button and the usage line', (tester) async {
      await openGame(tester);
      expect(find.bySemanticsIdentifier(GameDetailIds.analyse), findsOneWidget);
      expect(find.textContaining('2 of 3 analyses left today'), findsOneWidget);
    });

    testWidgets('an account without limits sees no counts', (tester) async {
      api.use('MyAnalysisUsage', 'unlimited');
      await openGame(tester);
      expect(find.textContaining('analyses left'), findsNothing);
      expect(find.bySemanticsIdentifier(GameDetailIds.analyse), findsOneWidget);
    });

    testWidgets('analysed: open analysis leads to the review', (tester) async {
      await openGame(tester, gameId: analysedGame);
      expect(
        find.bySemanticsIdentifier(GameDetailIds.openAnalysis),
        findsOneWidget,
      );
      expect(find.text('Your analysis is ready.'), findsOneWidget);

      await tester.tap(find.bySemanticsIdentifier(GameDetailIds.openAnalysis));
      await pumpFrames(tester);
      expect(navigatedTo(tester), AppRoutes.gameReview(analysedGame));
    });

    testWidgets('queued: position and the "you can leave" line', (
      tester,
    ) async {
      api.respond(
        'GameById',
        (variables) => gameById(
          api,
          variables['id'],
          patch: (game) {
            game['hasAnalysis'] = false;
            (game['latestAnalysisJob'] as Map)
              ..['status'] = 'QUEUED'
              ..['queuePosition'] = 2
              ..['finishedAt'] = null;
          },
        ),
      );
      await openGame(tester, gameId: analysedGame);

      expect(find.text('Waiting in the queue'), findsOneWidget);
      expect(find.text('2 games are ahead of yours.'), findsOneWidget);
      expect(
        find.text(
          "You can leave the app. We'll notify you when the analysis is ready.",
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier(GameDetailIds.analyse), findsNothing);
    });

    testWidgets('running: the stage, in words', (tester) async {
      api.respond(
        'GameById',
        (variables) => gameById(
          api,
          variables['id'],
          patch: (game) {
            game['hasAnalysis'] = false;
            (game['latestAnalysisJob'] as Map)
              ..['status'] = 'RUNNING'
              ..['stage'] = 'coach'
              ..['finishedAt'] = null;
          },
        ),
      );
      await openGame(tester, gameId: analysedGame);
      expect(find.text('Analysing your game'), findsOneWidget);
      expect(find.text('The coach is writing the comments.'), findsOneWidget);
    });

    testWidgets('failed: the refund is explained and a retry offered', (
      tester,
    ) async {
      api.respond(
        'GameById',
        (variables) => gameById(
          api,
          variables['id'],
          patch: (game) {
            game['hasAnalysis'] = false;
            (game['latestAnalysisJob'] as Map)
              ..['status'] = 'FAILED'
              ..['failureCode'] = 'engine_timeout';
          },
        ),
      );
      await openGame(tester, gameId: analysedGame);

      expect(find.text('The analysis failed'), findsOneWidget);
      expect(
        find.textContaining('does not count towards your limit'),
        findsOneWidget,
      );
      await tester.tap(find.bySemanticsIdentifier(GameDetailIds.retryAnalysis));
      await pumpFrames(tester);
      expect(api.requestsOf('RequestGameAnalysis'), hasLength(1));
    });
  });

  group('requesting an analysis', () {
    testWidgets('accepted: the job is tracked and the card shows progress', (
      tester,
    ) async {
      await openGame(tester);
      await tapAnalyse(tester);

      final request = api.requestsOf('RequestGameAnalysis').single;
      final input = request.variables['input'] as Map;
      expect(input['chessGameId'], freshGame);
      expect(input['language'], 'en');
      expect(input['deviceId'], isNotEmpty);

      expect(find.bySemanticsIdentifier(GameDetailIds.jobCard), findsOneWidget);
      expect(find.text('Waiting in the queue'), findsOneWidget);
      // The tracker knows it, and the usage was asked again.
      final tracked = containerOf(tester).read(trackedJobsProvider);
      expect(tracked[freshGame]!.status, JobStatus.queued);
      expect(api.requestsOf('MyAnalysisUsage').length, greaterThan(1));
    });

    testWidgets('the coach language follows the device language', (
      tester,
    ) async {
      await openGame(tester, locale: const Locale('de'));
      await tester.tap(find.bySemanticsIdentifier(GameDetailIds.analyse));
      await pumpFrames(tester);
      final input =
          api.requestsOf('RequestGameAnalysis').single.variables['input']
              as Map;
      expect(input['language'], 'de');
    });

    testWidgets('limit reached: a sheet says what, when and what stays free', (
      tester,
    ) async {
      api.use('RequestGameAnalysis', 'limit_reached');
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
      expect(
        find.text('Your game is saved. You can have it analysed later.'),
        findsOneWidget,
      );
      expect(
        find.text('Entering, importing and reviewing games is never limited.'),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsIdentifier(GameDetailIds.sheetClose));
      await pumpFrames(tester);
      expect(find.text('Daily limit reached'), findsNothing);
      expect(find.bySemanticsIdentifier(GameDetailIds.analyse), findsOneWidget);
    });

    testWidgets('at the limit the request still goes out', (tester) async {
      // The server counts limit pressure when it refuses, so the app must
      // not decide on its own that a request is pointless.
      api.use('MyAnalysisUsage', 'limit_reached');
      api.use('RequestGameAnalysis', 'limit_reached');
      await openGame(tester);
      expect(find.textContaining('No analyses left today'), findsOneWidget);

      await tapAnalyse(tester);
      expect(api.requestsOf('RequestGameAnalysis'), hasLength(1));
      expect(
        find.bySemanticsIdentifier(GameDetailIds.limitSheet),
        findsOneWidget,
      );
    });

    testWidgets('a monthly limit names the month', (tester) async {
      api.use('RequestGameAnalysis', 'limit_reached_month');
      await openGame(tester);
      await tapAnalyse(tester);
      expect(find.text('Monthly limit reached'), findsOneWidget);
    });

    testWidgets('queue full: how many at a time', (tester) async {
      api.use('RequestGameAnalysis', 'queue_full');
      await openGame(tester);
      await tapAnalyse(tester);
      expect(find.text('Too many analyses at once'), findsOneWidget);
      expect(
        find.textContaining('Only 2 of your games can be analysed at a time'),
        findsOneWidget,
      );
    });

    testWidgets('rate limited: a line with the wait', (tester) async {
      api.use('RequestGameAnalysis', 'rate_limited');
      await openGame(tester);
      await tapAnalyse(tester);
      expect(
        find.text('Too many requests. Try again in 42 seconds.'),
        findsOneWidget,
      );
    });

    testWidgets('e-mail not verified: explain, re-check, then it goes', (
      tester,
    ) async {
      api.use('RequestGameAnalysis', 'email_not_verified');
      await openGame(tester);
      await tapAnalyse(tester);

      expect(find.text('Confirm your e-mail address'), findsOneWidget);

      // Still not verified: the sheet stays and says so.
      await tester.tap(find.bySemanticsIdentifier(GameDetailIds.emailRecheck));
      await pumpFrames(tester);
      expect(find.text('Your address is not confirmed yet.'), findsOneWidget);
      expect(api.requestsOf('RequestGameAnalysis'), hasLength(2));

      // The user opened the link: the next request is accepted.
      acceptRequests(api);
      await tester.tap(find.bySemanticsIdentifier(GameDetailIds.emailRecheck));
      await pumpFrames(tester);
      expect(find.text('Confirm your e-mail address'), findsNothing);
      expect(find.bySemanticsIdentifier(GameDetailIds.jobCard), findsOneWidget);
    });

    testWidgets('AI consent: the screen opens and the request is repeated', (
      tester,
    ) async {
      api.use('RequestGameAnalysis', 'ai_consent_required');
      await openGame(tester);
      await tapAnalyse(tester);

      expect(navigatedTo(tester), AppRoutes.consentAi);
      expect(api.requestsOf('RequestGameAnalysis'), hasLength(1));

      // The consent screen pops with true (WP-30 records the consent).
      acceptRequests(api);
      popNavigatedTo(tester, true);
      await pumpFrames(tester);

      expect(api.requestsOf('RequestGameAnalysis'), hasLength(2));
      expect(find.bySemanticsIdentifier(GameDetailIds.jobCard), findsOneWidget);
    });

    testWidgets('AI consent declined: nothing is requested again', (
      tester,
    ) async {
      api.use('RequestGameAnalysis', 'ai_consent_required');
      await openGame(tester);
      await tapAnalyse(tester);

      popNavigatedTo(tester, false);
      await pumpFrames(tester);
      expect(api.requestsOf('RequestGameAnalysis'), hasLength(1));
      expect(
        find.text('The analysis needs your consent to AI processing.'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier(GameDetailIds.analyse), findsOneWidget);
    });

    testWidgets('offline: a line, and the button stays', (tester) async {
      api.fail('RequestGameAnalysis', const SocketException('offline'));
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
      api.use('RequestGameAnalysis', 'technical_error');
      await openGame(tester);
      await tapAnalyse(tester);
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
      await openGame(tester, locale: const Locale('de'));
      expect(find.text('Partie analysieren'), findsOneWidget);
      expect(
        find.textContaining('Heute noch 2 von 3 Analysen'),
        findsOneWidget,
      );
      expect(player('Weiss'), findsOneWidget);
      expect(find.text('0-1 · Du hast verloren'), findsOneWidget);
      expect(find.text('Schlussstellung'), findsOneWidget);

      api.use('RequestGameAnalysis', 'limit_reached');
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

    for (final locale in const [Locale('en'), Locale('de')]) {
      for (final brightness in Brightness.values) {
        testWidgets('$locale ${brightness.name}: text scale 1.3 on the SE', (
          tester,
        ) async {
          api.use('RequestGameAnalysis', 'limit_reached');
          await openGame(
            tester,
            gameId: analysedGame,
            locale: locale,
            brightness: brightness,
            textScale: 1.3,
            screen: kIphoneSe,
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

          // The tallest sheet, on the smallest screen.
          await tester.tap(
            find.bySemanticsIdentifier(GameDetailIds.openAnalysis),
          );
          await pumpFrames(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
