// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;

  setUp(() {
    clock = FakeClock();
    db = openTestDatabase(clock);
  });

  tearDown(() => db.close());

  /// One row in every table for [owner].
  Future<void> fill(String owner) async {
    await db.draftsDao.create(owner, pgn: '1. e4');
    await db.gamesCacheDao.upsertPage(owner, [
      CachedGameInput(
        gameId: 'game-$owner',
        summaryJson: '{}',
        updatedAt: clock(),
      ),
    ]);
    await db.analysisCacheDao.put(
      owner,
      'game-$owner',
      schemaVersion: 1,
      schemaMinor: 0,
      payload: '{}',
    );
    await db.pendingJobsDao.upsert(
      owner,
      jobId: 'job-$owner',
      gameId: 'game-$owner',
      state: JobState.queued,
    );
    await db.eventOutboxDao.enqueue(
      deviceId: 'd',
      sessionId: 's',
      name: 'signed_in',
      ownerSub: owner,
    );
    await db.feedbackOutboxDao.put(owner, 'c1', FeedbackRating.up);
    await db.kvDao.set('ai_consent_seen', '1', ownerSub: owner);
  }

  Future<Map<String, int>> rowCounts() async {
    final counts = <String, int>{};
    for (final table in db.allTables) {
      final rows = await db.select(table).get();
      counts[table.actualTableName] = rows.length;
    }
    return counts;
  }

  test('has the seven tables', () {
    expect(db.allTables.map((t) => t.actualTableName), {
      'drafts',
      'cached_games',
      'cached_analyses',
      'pending_jobs',
      'event_outbox',
      'feedback_outbox',
      'kv',
    });
  });

  test('client_game_id is unique', () async {
    final draft = await db.draftsDao.create(alice);
    final copy = draft
        .toCompanion(false)
        .copyWith(id: const Value('another-id'));
    await expectLater(db.into(db.drafts).insert(copy), throwsA(anything));
  });

  test('timestamps are kept to the second', () async {
    final precise = FakeClock(DateTime.utc(2026, 9, 19, 12, 0, 0, 750));
    final other = openTestDatabase(precise);
    addTearDown(other.close);

    final draft = await other.draftsDao.create(alice);
    expect(draft.createdAt.toUtc(), DateTime.utc(2026, 9, 19, 12));
  });

  test('wipeOwner removes everything of that owner and nothing else', () async {
    await fill(alice);
    await fill(bob);
    await db.eventOutboxDao.enqueue(
      deviceId: 'd',
      sessionId: 's',
      name: 'app_opened',
    );
    await db.kvDao.set('install_marker', '1');

    await db.wipeOwner(alice);

    expect(await db.draftsDao.watchAll(alice).first, isEmpty);
    expect(await db.gamesCacheDao.watchGames(alice).first, isEmpty);
    expect(await db.analysisCacheDao.get(alice, 'game-$alice'), isNull);
    expect(await db.pendingJobsDao.getActive(alice), isEmpty);
    expect(await db.feedbackOutboxDao.takeBatch(alice, 10), isEmpty);
    expect(await db.kvDao.get('ai_consent_seen', ownerSub: alice), isNull);
    expect((await db.eventOutboxDao.takeBatch(10)).map((e) => e.ownerSub), [
      bob,
      null,
    ]);

    expect(await db.draftsDao.watchAll(bob).first, hasLength(1));
    expect(await db.gamesCacheDao.watchGames(bob).first, hasLength(1));
    expect(await db.analysisCacheDao.get(bob, 'game-$bob'), isNotNull);
    expect(await db.pendingJobsDao.getActive(bob), hasLength(1));
    expect(await db.feedbackOutboxDao.takeBatch(bob, 10), hasLength(1));
    expect(await db.kvDao.get('ai_consent_seen', ownerSub: bob), '1');
    expect(await db.kvDao.get('install_marker'), '1');
  });

  test('wipeOwner can keep the drafts', () async {
    await fill(alice);

    await db.wipeOwner(alice, keepDrafts: true);

    expect(await db.draftsDao.watchAll(alice).first, hasLength(1));
    final counts = await rowCounts();
    expect(counts.remove('drafts'), 1);
    expect(counts.values, everyElement(0));
  });

  test('wipeAll empties every table', () async {
    await fill(alice);
    await fill(bob);
    await db.kvDao.set('install_marker', '1');
    expect((await rowCounts()).values, everyElement(greaterThan(0)));

    await db.wipeAll();

    expect((await rowCounts()).values, everyElement(0));
  });
}
