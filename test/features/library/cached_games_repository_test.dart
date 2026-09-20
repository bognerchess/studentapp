// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:io';

import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/features/library/data/cached_games_repository.dart';
import 'package:bogner_chess/features/library/domain/library_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/api/api_test_support.dart';
import '../../core/storage/test_database.dart';
import '../../helpers/fixture_link.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late FixtureLink link;
  late CachedGamesRepository games;

  setUp(() {
    clock = FakeClock();
    db = openTestDatabase(clock);
    link = FixtureLink();
    games = CachedGamesRepository(api: GamesApi(linkExecutor(link)), db: db);
  });
  tearDown(() => db.close());

  Future<List<String>> ids([
    LibraryFilter filter = const LibraryFilter(),
  ]) async => [
    for (final g in await games.watchGames(alice, filter).first) g.id,
  ];

  test(
    'a fetched page is cached and watched, newest first, undated last',
    () async {
      expect(await ids(), isEmpty);
      final page = await games.fetchPage(alice, fetchedAt: games.now());
      expect(page.games, hasLength(3));
      expect(await ids(), ['game-1', 'game-2', 'game-3']);
      expect(await ids(), isNot(contains('x')));
      // Nothing of it is visible to another account.
      expect(await games.watchGames(bob, const LibraryFilter()).first, isEmpty);
    },
  );

  test('the filter goes to the server and is applied to the cache', () async {
    await games.fetchPage(alice, fetchedAt: games.now());
    final filter = LibraryFilter(
      text: ' keller ',
      from: GameDate(2026, 9, 1),
      to: GameDate(2026, 9, 30),
    );
    await games.fetchPage(alice, fetchedAt: games.now(), filter: filter);
    expect(link.requestsOf('MyMobileGames').last.variables, {
      'search': 'keller',
      'playedFrom': '2026-09-01',
      'playedTo': '2026-09-30',
      'first': 20,
    });

    expect(await ids(const LibraryFilter(text: 'KELLER')), ['game-1']);
    // The event counts as well, and so does the user's own name.
    expect(await ids(const LibraryFilter(text: 'rapid open')), ['game-2']);
    expect(await ids(const LibraryFilter(text: 'østerg')), ['game-2']);
    expect(await ids(const LibraryFilter(text: 'nobody')), isEmpty);
    // A date range leaves the undated game out.
    expect(await ids(LibraryFilter(from: GameDate(2026, 9, 6))), ['game-1']);
    expect(await ids(LibraryFilter(to: GameDate(2026, 9, 6))), ['game-2']);
  });

  test('paging: the cursor is passed on', () async {
    link.use('MyMobileGames', 'first_page');
    final first = await games.fetchPage(alice, fetchedAt: games.now());
    expect(first.hasNextPage, isTrue);
    link.use('MyMobileGames', 'last_page');
    await games.fetchPage(
      alice,
      fetchedAt: games.now(),
      after: first.endCursor,
    );
    expect(
      link.requestsOf('MyMobileGames').last.variables['after'],
      first.endCursor,
    );
  });

  test('removeStale drops what a complete refresh did not see', () async {
    await games.fetchPage(alice, fetchedAt: games.now());
    await db.analysisCacheDao.put(
      alice,
      'game-1',
      schemaVersion: 1,
      schemaMinor: 0,
      payload: '{}',
    );
    clock.advance(const Duration(minutes: 1));
    link.use('MyMobileGames', 'empty');
    final startedAt = games.now();
    await games.fetchPage(alice, fetchedAt: startedAt);
    expect(await games.removeStale(alice, startedAt), 3);
    expect(await ids(), isEmpty);
    expect(await db.analysisCacheDao.get(alice, 'game-1'), isNull);
  });

  test('a failing fetch throws and leaves the cache alone', () async {
    await games.fetchPage(alice, fetchedAt: games.now());
    link.fail('MyMobileGames', const SocketException('offline'));
    await expectLater(
      games.fetchPage(alice, fetchedAt: games.now()),
      throwsA(isA<ApiNetworkError>()),
    );
    expect(await ids(), hasLength(3));
  });

  test('fetchDetail updates the cache; a vanished game leaves it', () async {
    final detail = await games.fetchDetail(alice, 'game-1');
    expect(detail!.pgn, contains('1. e4'));
    expect(
      (await games.cached(alice, 'game-1'))!.eventName,
      'Club Championship',
    );

    link.use('GameById', 'not_found');
    expect(await games.fetchDetail(alice, 'game-1'), isNull);
    expect(await games.cached(alice, 'game-1'), isNull);
  });

  test('put keeps the refresh stamp of a known row', () async {
    final startedAt = games.now();
    await games.fetchPage(alice, fetchedAt: startedAt);
    clock.advance(const Duration(minutes: 1));
    final game = (await games.cached(alice, 'game-3'))!;
    await games.put(alice, game);
    // Still stale for a refresh that started after the first one.
    expect(await games.removeStale(alice, games.now()), 3);
  });

  test('delete: server first, then cache, analysis and jobs', () async {
    await games.fetchPage(alice, fetchedAt: games.now());
    await db.analysisCacheDao.put(
      alice,
      'game-1',
      schemaVersion: 1,
      schemaMinor: 0,
      payload: '{}',
    );
    await db.pendingJobsDao.upsert(
      alice,
      jobId: 'j',
      gameId: 'game-1',
      state: JobState.running,
    );

    expect(await games.delete(alice, 'game-1'), isA<GameDeleted>());
    expect(
      link.requestsOf('DeleteChessGame').single.variables.toString(),
      contains('game-1'),
    );
    expect(await ids(), ['game-2', 'game-3']);
    expect(await db.analysisCacheDao.get(alice, 'game-1'), isNull);
    expect(await db.pendingJobsDao.getActive(alice), isEmpty);
  });

  test('a refused delete keeps the cached game', () async {
    await games.fetchPage(alice, fetchedAt: games.now());
    link.use('DeleteChessGame', 'technical_error');
    expect(await games.delete(alice, 'game-1'), isA<DeleteGameFailed>());
    expect(await ids(), hasLength(3));
  });

  test('applyJob changes the badge of a cached game only', () async {
    await games.fetchPage(alice, fetchedAt: games.now());
    final job = JobInfo(
      id: 'j9',
      gameId: 'game-3',
      status: JobStatus.done,
      requestedAt: DateTime.utc(2026, 9, 19, 10),
      finishedAt: DateTime.utc(2026, 9, 19, 10, 3),
    );
    await games.applyJob(alice, job, hasAnalysis: true);
    final game = (await games.cached(alice, 'game-3'))!;
    expect(game.hasAnalysis, isTrue);
    expect(game.latestJob, job);
    expect(game.blackName, 'Anonymous');

    await games.applyJob(
      alice,
      JobInfo(
        id: 'j',
        gameId: 'unknown-game',
        status: JobStatus.queued,
        requestedAt: DateTime.utc(2026),
      ),
    );
    expect(await games.cached(alice, 'unknown-game'), isNull);
  });
}
