// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late GamesCacheDao dao;

  setUp(() {
    clock = FakeClock();
    db = openTestDatabase(clock);
    dao = db.gamesCacheDao;
  });

  tearDown(() => db.close());

  CachedGameInput game(
    String id, {
    String? opponent,
    DateTime? played,
    DateTime? updatedAt,
    String summary = '{}',
  }) => CachedGameInput(
    gameId: id,
    summaryJson: summary,
    opponentName: opponent,
    playedDate: played,
    updatedAt: updatedAt ?? DateTime.utc(2026, 9),
  );

  Future<List<String>> ids(Stream<List<CachedGame>> stream) async =>
      (await stream.first).map((g) => g.gameId).toList();

  test('upsertPage inserts, then replaces by game id', () async {
    await dao.upsertPage(alice, [
      game('g1', opponent: 'Anna', summary: '{"v":1}'),
      game('g2', opponent: 'Bert'),
    ]);
    clock.advance(const Duration(minutes: 1));
    await dao.upsertPage(alice, [
      game('g1', opponent: 'Anna B.', summary: '{"v":2}'),
    ]);

    expect(await ids(dao.watchGames(alice)), hasLength(2));
    final g1 = (await dao.get(alice, 'g1'))!;
    expect(g1.summaryJson, '{"v":2}');
    expect(g1.opponentName, 'Anna B.');
    expect(g1.fetchedAt.isAtSameMomentAs(clock()), isTrue);
  });

  test('sorts by date played, undated last, then by server time', () async {
    await dao.upsertPage(alice, [
      game('undated', updatedAt: DateTime.utc(2026, 9, 10)),
      game('old', played: DateTime.utc(2026, 1, 5)),
      game('new-a', played: DateTime.utc(2026, 8, 1)),
      game(
        'new-b',
        played: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 9, 2),
      ),
    ]);

    expect(await ids(dao.watchGames(alice)), [
      'new-b',
      'new-a',
      'old',
      'undated',
    ]);
    expect(await ids(dao.watchGames(alice, limit: 2)), ['new-b', 'new-a']);
  });

  test('the date played survives as a calendar date', () async {
    // Late in the evening, local time, far from UTC: still the 31st.
    await dao.upsertPage(alice, [
      game('g', played: DateTime(2026, 12, 31, 23, 30)),
    ]);
    expect((await dao.get(alice, 'g'))!.playedDate, DateTime.utc(2026, 12, 31));
  });

  test('searches the opponent by substring, ignoring case', () async {
    await dao.upsertPage(alice, [
      game('g1', opponent: 'Magnus Müller'),
      game('g2', opponent: 'ÖZGÜR Demir'),
      game('g3', opponent: '100%_sure'),
      game('g4'),
    ]);

    expect(await ids(dao.watchGames(alice, opponentQuery: 'müll')), ['g1']);
    expect(await ids(dao.watchGames(alice, opponentQuery: 'MÜLL')), ['g1']);
    expect(await ids(dao.watchGames(alice, opponentQuery: 'özgür')), ['g2']);
    expect(await ids(dao.watchGames(alice, opponentQuery: ' carl ')), isEmpty);
    expect(await ids(dao.watchGames(alice, opponentQuery: ' müller ')), ['g1']);
    expect(
      await ids(dao.watchGames(alice, opponentQuery: 'M')),
      unorderedEquals(['g1', 'g2']),
    );
    expect(
      await ids(dao.watchGames(alice, opponentQuery: '   ')),
      hasLength(4),
    );
    // LIKE wildcards in the query are plain characters.
    expect(await ids(dao.watchGames(alice, opponentQuery: '%')), ['g3']);
    expect(await ids(dao.watchGames(alice, opponentQuery: '_')), ['g3']);
  });

  test('filters by an inclusive date range and drops undated games', () async {
    await dao.upsertPage(alice, [
      game('jan', played: DateTime.utc(2026, 1, 31)),
      game('feb', played: DateTime.utc(2026, 2, 1)),
      game('mar', played: DateTime.utc(2026, 3, 1)),
      game('undated'),
    ]);

    expect(
      await ids(
        dao.watchGames(
          alice,
          playedFrom: DateTime.utc(2026, 2, 1),
          playedTo: DateTime.utc(2026, 3, 1),
        ),
      ),
      ['mar', 'feb'],
    );
    expect(
      await ids(dao.watchGames(alice, playedTo: DateTime.utc(2026, 1, 31))),
      ['jan'],
    );
    expect(
      await ids(
        dao.watchGames(
          alice,
          opponentQuery: 'x',
          playedFrom: DateTime.utc(2026),
        ),
      ),
      isEmpty,
    );
  });

  test('watchGames emits again after an upsert', () async {
    final seen = <int>[];
    final sub = dao.watchGames(alice).listen((list) => seen.add(list.length));
    await pumpEventQueue();
    await dao.upsertPage(alice, [game('g1')]);
    await pumpEventQueue();
    await sub.cancel();

    expect(seen, [0, 1]);
  });

  test('remove takes the analysis and the jobs of the game along', () async {
    await dao.upsertPage(alice, [game('g1'), game('g2')]);
    for (final id in ['g1', 'g2']) {
      await db.analysisCacheDao.put(
        alice,
        id,
        schemaVersion: 1,
        schemaMinor: 0,
        payload: '{}',
      );
      await db.pendingJobsDao.upsert(
        alice,
        jobId: 'job-$id',
        gameId: id,
        state: JobState.queued,
      );
    }

    expect(await dao.remove(alice, 'g1'), isTrue);
    expect(await dao.remove(alice, 'g1'), isFalse);

    expect(await ids(dao.watchGames(alice)), ['g2']);
    expect(await db.analysisCacheDao.get(alice, 'g1'), isNull);
    expect(await db.analysisCacheDao.get(alice, 'g2'), isNotNull);
    expect((await db.pendingJobsDao.getActive(alice)).map((j) => j.jobId), [
      'job-g2',
    ]);
  });

  test('removeStale drops what a full refresh did not see', () async {
    await dao.upsertPage(alice, [game('kept'), game('gone')]);
    await dao.upsertPage(bob, [game('bobs')]);
    await db.analysisCacheDao.put(
      alice,
      'gone',
      schemaVersion: 1,
      schemaMinor: 0,
      payload: '{}',
    );

    clock.advance(const Duration(minutes: 5));
    final refresh = clock();
    await dao.upsertPage(alice, [game('kept')], fetchedAt: refresh);
    clock.advance(const Duration(seconds: 2));
    await dao.upsertPage(alice, [game('page2')], fetchedAt: refresh);

    expect(await dao.removeStale(alice, refresh), 1);
    expect(
      await ids(dao.watchGames(alice)),
      unorderedEquals(['kept', 'page2']),
    );
    expect(await db.analysisCacheDao.get(alice, 'gone'), isNull);
    expect(await ids(dao.watchGames(bob)), ['bobs']);
  });

  test(
    'owner scoping: reads, removes and upserts stay with the owner',
    () async {
      await dao.upsertPage(alice, [game('a1', opponent: 'Carl')]);
      await dao.upsertPage(bob, [game('b1', opponent: 'Carl')]);

      expect(await ids(dao.watchGames(alice)), ['a1']);
      expect(await ids(dao.watchGames(alice, opponentQuery: 'carl')), ['a1']);
      expect(await dao.get(alice, 'b1'), isNull);
      expect(await dao.remove(alice, 'b1'), isFalse);

      // The same game id from another account must not take the row over.
      await dao.upsertPage(alice, [game('b1', summary: '{"stolen":true}')]);
      expect(await dao.get(alice, 'b1'), isNull);
      expect((await dao.get(bob, 'b1'))!.summaryJson, '{}');
    },
  );
}
