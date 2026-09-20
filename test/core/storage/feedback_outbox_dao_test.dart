// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late FeedbackOutboxDao dao;

  setUp(() {
    clock = FakeClock();
    db = openTestDatabase(clock);
    dao = db.feedbackOutboxDao;
  });

  tearDown(() => db.close());

  test('put stores a rating', () async {
    await dao.put(alice, 'c1', FeedbackRating.up);
    final entry = (await dao.takeBatch(alice, 10)).single;

    expect(entry.ownerSub, alice);
    expect(entry.commentId, 'c1');
    expect(entry.rating, FeedbackRating.up);
    expect(entry.attempts, 0);
    expect(entry.createdAt.isAtSameMomentAs(clock()), isTrue);
  });

  test('latest wins per comment and attempts start again', () async {
    await dao.put(alice, 'c1', FeedbackRating.up);
    final first = (await dao.takeBatch(alice, 10)).single;
    await dao.bumpAttempts([first.id]);
    clock.advance(const Duration(seconds: 10));

    await dao.put(alice, 'c1', FeedbackRating.down);
    await dao.put(alice, 'c1', FeedbackRating.cleared);

    final entry = (await dao.takeBatch(alice, 10)).single;
    expect(entry.id, first.id);
    expect(entry.rating, FeedbackRating.cleared);
    expect(entry.attempts, 0);
    expect(entry.createdAt.isAtSameMomentAs(clock()), isTrue);
  });

  test('takeBatch returns the ratings that waited longest', () async {
    await dao.put(alice, 'c1', FeedbackRating.up);
    clock.advance(const Duration(seconds: 1));
    await dao.put(alice, 'c2', FeedbackRating.down);
    clock.advance(const Duration(seconds: 1));
    await dao.put(alice, 'c3', FeedbackRating.up);
    clock.advance(const Duration(seconds: 1));
    // Re-rating c1 sends it to the back.
    await dao.put(alice, 'c1', FeedbackRating.down);

    expect((await dao.takeBatch(alice, 2)).map((e) => e.commentId), [
      'c2',
      'c3',
    ]);
  });

  test('removeSent keeps a rating that changed during the request', () async {
    await dao.put(alice, 'c1', FeedbackRating.up);
    await dao.put(alice, 'c2', FeedbackRating.up);
    final inFlight = await dao.takeBatch(alice, 10);
    await dao.put(alice, 'c2', FeedbackRating.down);

    expect(await dao.removeSent(inFlight), 1);

    final left = (await dao.takeBatch(alice, 10)).single;
    expect(left.commentId, 'c2');
    expect(left.rating, FeedbackRating.down);
  });

  test('bumpAttempts and removeExhausted', () async {
    await dao.put(alice, 'c1', FeedbackRating.up);
    await dao.put(alice, 'c2', FeedbackRating.up);
    final ids = (await dao.takeBatch(alice, 10)).map((e) => e.id).toList();
    await dao.bumpAttempts(ids);
    await dao.bumpAttempts([ids.first]);

    expect(await dao.removeExhausted(alice, 2), 1);
    expect((await dao.takeBatch(alice, 10)).single.commentId, 'c2');
  });

  test('watchPending shows the waiting rating of a comment', () async {
    final seen = <FeedbackRating?>[];
    final sub = dao
        .watchPending(alice, 'c1')
        .listen((entry) => seen.add(entry?.rating));
    await pumpEventQueue();
    await dao.put(alice, 'c1', FeedbackRating.up);
    await pumpEventQueue();
    await dao.removeSent(await dao.takeBatch(alice, 1));
    await pumpEventQueue();
    await sub.cancel();

    expect(seen, [null, FeedbackRating.up, null]);
  });

  test('owner scoping: the same comment id is a row per owner', () async {
    await dao.put(alice, 'c1', FeedbackRating.up);
    await dao.put(bob, 'c1', FeedbackRating.down);

    expect((await dao.takeBatch(alice, 10)).single.rating, FeedbackRating.up);
    expect((await dao.takeBatch(bob, 10)).single.rating, FeedbackRating.down);
    expect(await dao.watchPending(alice, 'c2').first, isNull);

    final bobs = await dao.takeBatch(bob, 10);
    await dao.bumpAttempts(bobs.map((e) => e.id));
    expect(await dao.removeExhausted(alice, 1), 0);
    expect(await dao.takeBatch(bob, 10), hasLength(1));
  });
}
