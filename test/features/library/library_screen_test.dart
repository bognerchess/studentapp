// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';
import 'dart:io';

import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/game/library_refresh.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:bogner_chess/core/ui/widgets/error_retry.dart';
import 'package:bogner_chess/features/game_detail/ui/game_detail_screen.dart';
import 'package:bogner_chess/features/library/domain/draft_actions.dart';
import 'package:bogner_chess/features/library/domain/game_summary_codec.dart';
import 'package:bogner_chess/features/library/domain/library_controller.dart';
import 'package:bogner_chess/features/library/ui/library_ids.dart';
import 'package:bogner_chess/features/library/ui/library_row_tile.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fixture_link.dart';
import '../../helpers/pump_app.dart';

const owner = kFakeAuthSub;

/// The order of the rows on screen, by their first line.
List<String> titles(WidgetTester tester) => [
  for (final tile in tester.widgetList<LibraryRowTile>(
    find.byType(LibraryRowTile),
  ))
    '${tile.row.whiteName ?? 'White'} – ${tile.row.blackName ?? 'Black'}',
];

Future<void> seedCachedGame(
  AppDatabase db, {
  required String id,
  required String black,
  DateTime? fetchedAt,
}) {
  final game = GameSummary(
    id: id,
    whiteName: 'Fake User',
    blackName: black,
    opponentName: black,
    playerColor: PlayerColor.white,
    result: GameResult.whiteWins,
    playedDate: GameDate(2026, 8, 1),
    hasAnalysis: false,
  );
  return db.gamesCacheDao.upsertPage(owner, [
    CachedGameInput(
      gameId: id,
      summaryJson: GameSummaryCodec.encode(game),
      updatedAt: DateTime.utc(2026, 8),
      playedDate: DateTime(2026, 8),
      opponentName: black,
    ),
  ], fetchedAt: fetchedAt ?? DateTime.utc(2026, 8, 2));
}

Future<Draft> seedDraft(
  AppDatabase db, {
  required String opponent,
  DraftState state = DraftState.editing,
}) async {
  final draft = await db.draftsDao.create(
    owner,
    pgn: '1. e4 e5',
    metaJson: jsonEncode(
      GameMetadata.forPlayer(
        playerColor: PlayerColor.white,
        playerName: 'Fake User',
        opponentName: opponent,
        playedDate: GameDate(2026, 9, 18),
      ).toJson(),
    ),
  );
  if (state != DraftState.editing) {
    await db.draftsDao.markReady(owner, draft.id);
  }
  if (state == DraftState.failed) {
    await db.draftsDao.markSubmitting(owner, draft.id);
    await db.draftsDao.markSubmitFailed(
      owner,
      draft.id,
      error: 'x',
      nextAttemptAt: null,
    );
  }
  return draft;
}

void main() {
  late AppDatabase db;
  late FixtureLink api;

  setUp(() {
    db = openWidgetTestDatabase();
    // No active jobs unless a test says so: the default fixture of that
    // query would put game-3 into the queue.
    api = FixtureLink({'MyActiveAnalysisJobs': 'empty'});
  });
  tearDown(() => db.close());

  List<Override> overrides([List<Override> more = const []]) => [
    appDatabaseProvider.overrideWithValue(db),
    ...api.overrides,
    ...more,
  ];

  group('list', () {
    testWidgets('rows: players, date and event, result, status badge', (
      tester,
    ) async {
      await pumpApp(tester, overrides: overrides());

      expect(titles(tester), [
        'Fake User – Jonas Keller',
        'Mira Østergård – Fake User',
        'White – Anonymous',
      ]);
      expect(find.text('Sep 12, 2026 · Club Championship'), findsOneWidget);
      expect(find.text('No date'), findsOneWidget);
      expect(find.text('1–0'), findsOneWidget);
      expect(find.text('½–½'), findsOneWidget);
      expect(find.text('0–1'), findsOneWidget);
      expect(find.text('Analysis ready'), findsOneWidget);
      expect(find.text('Analysing…'), findsOneWidget);
      expect(find.text('Not analysed'), findsOneWidget);
    });

    testWidgets('a failed job shows as failed', (tester) async {
      api.respond('MyMobileGames', (_) {
        final body = api.store.response('MyMobileGames', 'default');
        final nodes =
            ((body['data'] as Map)['myMobileGames'] as Map)['nodes'] as List;
        ((nodes[1] as Map)['latestAnalysisJob'] as Map)
          ..['status'] = 'FAILED'
          ..['failureCode'] = 'engine_timeout'
          ..['finishedAt'] = '2026-09-19T10:05:00.000Z';
        return body;
      });
      await pumpApp(tester, overrides: overrides());
      expect(find.text('Analysis failed'), findsOneWidget);
    });

    testWidgets('cache first: shown before the server answers, then brought '
        'up to date', (tester) async {
      await seedCachedGame(db, id: 'old-1', black: 'Cached Opponent');
      api.delay = const Duration(seconds: 2);
      await pumpApp(tester, overrides: overrides(), settle: false);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(titles(tester), ['Fake User – Cached Opponent']);
      expect(api.requestsOf('MyMobileGames'), hasLength(1));

      api.delay = Duration.zero;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      // The refresh was complete, so the game the server no longer has went.
      expect(titles(tester), [
        'Fake User – Jonas Keller',
        'Mira Østergård – Fake User',
        'White – Anonymous',
      ]);
    });

    testWidgets('a tap opens the game', (tester) async {
      await pumpApp(tester, overrides: overrides());
      await tester.tap(find.text('Fake User – Jonas Keller'));
      await tester.pumpAndSettle();
      expect(find.byType(GameDetailScreen), findsOneWidget);
      expect(
        tester.widget<GameDetailScreen>(find.byType(GameDetailScreen)).gameId,
        'game-1',
      );
    });

    testWidgets('the next page is loaded when the end comes into view', (
      tester,
    ) async {
      api.respond('MyMobileGames', (variables) {
        return api.store.response(
          'MyMobileGames',
          variables['after'] == null ? 'first_page' : 'last_page',
        );
      });
      await pumpApp(tester, overrides: overrides());

      final requests = api.requestsOf('MyMobileGames');
      expect(requests, hasLength(2));
      expect(requests.last.variables['after'], 'c2');
      expect(titles(tester), hasLength(3));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('pull to refresh asks the server again', (tester) async {
      await pumpApp(tester, overrides: overrides());
      final before = api.requestsOf('MyMobileGames').length;
      await tester.drag(
        find.text('Fake User – Jonas Keller'),
        const Offset(0, 400),
      );
      await tester.pumpAndSettle();
      expect(api.requestsOf('MyMobileGames').length, before + 1);
    });
  });

  group('the submit queue seam', () {
    testWidgets('libraryRefreshProvider makes the list fetch again', (
      tester,
    ) async {
      await pumpApp(tester, overrides: overrides());
      final before = api.requestsOf('MyMobileGames').length;

      // What SubmitQueue calls after an upload (WP-27).
      containerOf(tester).read(libraryRefreshProvider.notifier).request();
      await tester.pumpAndSettle();

      expect(api.requestsOf('MyMobileGames').length, before + 1);
    });
  });

  group('search and date filter', () {
    testWidgets('typing filters the cache at once and asks the server after '
        'a pause', (tester) async {
      await pumpApp(tester, overrides: overrides());
      final before = api.requestsOf('MyMobileGames').length;

      await tester.enterText(find.byType(TextField), 'kell');
      await tester.pump();
      await tester.pump();
      expect(titles(tester), ['Fake User – Jonas Keller']);
      expect(api.requestsOf('MyMobileGames').length, before);

      await tester.pump(LibraryController.searchDebounce);
      await tester.pumpAndSettle();
      final request = api.requestsOf('MyMobileGames').last;
      expect(api.requestsOf('MyMobileGames').length, before + 1);
      expect(request.variables['search'], 'kell');
    });

    testWidgets('the event is searched as well; clearing brings all back', (
      tester,
    ) async {
      await pumpApp(tester, overrides: overrides());
      await tester.enterText(find.byType(TextField), 'rapid');
      await tester.pumpAndSettle(LibraryController.searchDebounce);
      expect(titles(tester), ['Mira Østergård – Fake User']);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle(LibraryController.searchDebounce);
      expect(titles(tester), hasLength(3));
    });

    testWidgets('no match: says so, and one tap clears the filters', (
      tester,
    ) async {
      await pumpApp(tester, overrides: overrides());
      await tester.enterText(find.byType(TextField), 'nobody');
      await tester.pumpAndSettle(LibraryController.searchDebounce);
      expect(find.text('No games found'), findsOneWidget);
      // The search field is still there to correct the typo.
      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(titles(tester), hasLength(3));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('a date range goes to the server, filters the cache and '
        'shows on the chip', (tester) async {
      await pumpApp(tester, overrides: overrides());
      containerOf(tester)
          .read(libraryControllerProvider.notifier)
          .setDateRange(GameDate(2026, 9, 10), GameDate(2026, 9, 30));
      await tester.pumpAndSettle();

      expect(titles(tester), ['Fake User – Jonas Keller']);
      expect(find.text('9/10/2026 – 9/30/2026'), findsOneWidget);
      final variables = api.requestsOf('MyMobileGames').last.variables;
      expect(variables['playedFrom'], '2026-09-10');
      expect(variables['playedTo'], '2026-09-30');

      // The chip's delete button removes the range.
      await tester.tap(find.byTooltip('Clear date filter'));
      await tester.pumpAndSettle();
      expect(titles(tester), hasLength(3));
      expect(find.text('Date'), findsOneWidget);
    });

    testWidgets('the chip opens the date-range picker', (tester) async {
      // A wide screen: in the test font the picker's own "Start Date – End
      // Date" headline does not fit a phone.
      await pumpApp(
        tester,
        overrides: overrides(),
        screen: const Size(800, 1000),
      );
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      expect(find.text('Games played between'), findsOneWidget);
    });
  });

  group('drafts', () {
    testWidgets('sit on top, with their state', (tester) async {
      await seedDraft(db, opponent: 'Draft One');
      await seedDraft(db, opponent: 'Draft Two', state: DraftState.ready);
      await seedDraft(db, opponent: 'Draft Three', state: DraftState.failed);
      await pumpApp(tester, overrides: overrides());

      final shown = titles(tester);
      expect(shown.take(3).toSet(), {
        'Fake User – Draft One',
        'Fake User – Draft Two',
        'Fake User – Draft Three',
      });
      expect(shown.skip(3).first, 'Fake User – Jonas Keller');
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Waiting to upload'), findsOneWidget);
      expect(find.text('Upload failed'), findsOneWidget);
    });

    testWidgets('a draft in progress resumes in the entry screen', (
      tester,
    ) async {
      final draft = await seedDraft(db, opponent: 'Draft One');
      await pumpApp(tester, overrides: overrides());
      await tester.tap(find.text('Fake User – Draft One'));
      await tester.pumpAndSettle();
      final uri = routerOf(tester)
          .routerDelegate
          .currentConfiguration
          .last
          .matchedLocation;
      expect(uri, AppRoutes.newGameEntry);
      expect(
        routerOf(tester).routerDelegate.currentConfiguration.last.route.name,
        AppRouteNames.newGameEntry,
      );
      expect(draft.id, isNotEmpty);
    });

    testWidgets('other states: the seam is asked first, else a line explains', (
      tester,
    ) async {
      await seedDraft(db, opponent: 'Draft Two', state: DraftState.ready);
      final taps = <String>[];
      var handle = false;
      await pumpApp(
        tester,
        overrides: overrides([
          libraryDraftTapHandlerProvider.overrideWithValue((context, draft) {
            taps.add(draft.state.name);
            return handle;
          }),
        ]),
      );

      await tester.tap(find.text('Fake User – Draft Two'));
      await tester.pump();
      expect(taps, ['ready']);
      expect(
        find.text("This game is sent as soon as you're online."),
        findsOneWidget,
      );

      handle = true;
      ScaffoldMessenger.of(tester.element(find.byType(LibraryRowTile).first))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fake User – Draft Two'));
      await tester.pump();
      expect(taps, ['ready', 'ready']);
      expect(
        find.text("This game is sent as soon as you're online."),
        findsNothing,
      );
    });

    testWidgets('the filter applies to drafts too', (tester) async {
      await seedDraft(db, opponent: 'Draft One');
      await pumpApp(tester, overrides: overrides());
      await tester.enterText(find.byType(TextField), 'kell');
      await tester.pumpAndSettle(LibraryController.searchDebounce);
      expect(titles(tester), ['Fake User – Jonas Keller']);
    });

    testWidgets('a draft can be deleted', (tester) async {
      await seedDraft(db, opponent: 'Draft One');
      await pumpApp(tester, overrides: overrides());
      await tester.drag(
        find.text('Fake User – Draft One'),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete this draft?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Fake User – Draft One'), findsNothing);
      // Real database I/O has to leave the fake clock of testWidgets.
      final left = await tester.runAsync(
        () => db.draftsDao.watchAll(owner).first,
      );
      expect(left, isEmpty);
    });
  });

  group('delete', () {
    testWidgets('swipe, confirm: gone on the server and in the list', (
      tester,
    ) async {
      await pumpApp(tester, overrides: overrides());
      await tester.drag(
        find.text('Fake User – Jonas Keller'),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete this game?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(
        api.requestsOf('DeleteChessGame').single.variables.toString(),
        contains('game-1'),
      );
      expect(find.text('Fake User – Jonas Keller'), findsNothing);
      expect(find.text('Game deleted'), findsOneWidget);
      final row = await tester.runAsync(
        () => db.gamesCacheDao.get(owner, 'game-1'),
      );
      expect(row, isNull);
    });

    testWidgets('cancel keeps the game and asks nothing', (tester) async {
      await pumpApp(tester, overrides: overrides());
      await tester.drag(
        find.text('Fake User – Jonas Keller'),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.requestsOf('DeleteChessGame'), isEmpty);
      expect(find.text('Fake User – Jonas Keller'), findsOneWidget);
    });

    testWidgets('a failure keeps the game and says so', (tester) async {
      api.use('DeleteChessGame', 'technical_error');
      await pumpApp(tester, overrides: overrides());
      await tester.drag(
        find.text('Fake User – Jonas Keller'),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Fake User – Jonas Keller'), findsOneWidget);
      expect(
        find.text('That could not be deleted. Try again.'),
        findsOneWidget,
      );
    });
  });

  group('offline and errors', () {
    testWidgets('offline with cached games: banner, list, retry', (
      tester,
    ) async {
      await seedCachedGame(db, id: 'old-1', black: 'Cached Opponent');
      api.fail('MyMobileGames', const SocketException('offline'));
      await pumpApp(tester, overrides: overrides());

      expect(titles(tester), ['Fake User – Cached Opponent']);
      expect(
        find.text("You're offline. These are the games saved on this device."),
        findsOneWidget,
      );

      // Searching works on the cache meanwhile.
      await tester.enterText(find.byType(TextField), 'cached');
      await tester.pumpAndSettle(LibraryController.searchDebounce);
      expect(titles(tester), ['Fake User – Cached Opponent']);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle(LibraryController.searchDebounce);

      api.use('MyMobileGames', 'default');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsIdentifier(LibraryIds.banner), findsNothing);
      expect(titles(tester), hasLength(3));
    });

    testWidgets('offline with nothing cached: explains, retry works', (
      tester,
    ) async {
      api.fail('MyMobileGames', const SocketException('offline'));
      await pumpApp(tester, overrides: overrides());
      expect(find.byType(ErrorRetry), findsOneWidget);
      expect(
        find.text("You're offline, and no games are saved on this device yet."),
        findsOneWidget,
      );

      api.use('MyMobileGames', 'default');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(titles(tester), hasLength(3));
    });

    testWidgets('a server error is not called "offline"', (tester) async {
      await seedCachedGame(db, id: 'old-1', black: 'Cached Opponent');
      api.use('MyMobileGames', 'null_connection');
      api.fail('MyMobileGames', const ApiServerError(statusCode: 500));
      await pumpApp(tester, overrides: overrides());
      expect(find.text('The list could not be updated.'), findsOneWidget);
    });
  });

  group('languages and sizes', () {
    for (final locale in const [Locale('en'), Locale('de')]) {
      for (final brightness in Brightness.values) {
        testWidgets('$locale ${brightness.name}: text scale 1.3 on the SE', (
          tester,
        ) async {
          await seedDraft(db, opponent: 'Draft Opponent With A Long Name');
          await seedDraft(db, opponent: 'Two', state: DraftState.failed);
          await seedCachedGame(db, id: 'old-1', black: 'Cached Opponent');
          api.fail('MyMobileGames', const SocketException('offline'));
          await pumpApp(
            tester,
            locale: locale,
            brightness: brightness,
            textScale: 1.3,
            screen: kIphoneSe,
            overrides: overrides(),
          );
          expect(tester.takeException(), isNull);
          expect(
            MediaQuery.textScalerOf(
              tester.element(find.byType(LibraryRowTile).first),
            ).scale(10),
            13,
          );
          expect(
            Theme.of(tester.element(find.byType(LibraryRowTile).first))
                .brightness,
            brightness,
          );

          await tester.enterText(find.byType(TextField), 'zzz');
          await tester.pumpAndSettle(LibraryController.searchDebounce);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('German strings', (tester) async {
      await seedDraft(db, opponent: 'Eins');
      await pumpApp(tester, locale: const Locale('de'), overrides: overrides());
      expect(find.text('Spieler oder Turnier suchen'), findsOneWidget);
      expect(find.text('Entwurf'), findsOneWidget);
      expect(find.text('Analyse bereit'), findsOneWidget);
      expect(find.text('Wird analysiert…'), findsOneWidget);
      expect(find.text('Nicht analysiert'), findsOneWidget);
      expect(find.text('Weiss – Anonymous'), findsOneWidget);
      expect(find.text('Ohne Datum'), findsOneWidget);
      expect(find.textContaining('2026 · Club Championship'), findsOneWidget);
    });
  });
}
