// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late PendingJobsDao dao;

  setUp(() {
    clock = FakeClock();
    db = openTestDatabase(clock);
    dao = db.pendingJobsDao;
  });

  tearDown(() => db.close());

  Future<void> upsert(String owner, String jobId, JobState state) =>
      dao.upsert(owner, jobId: jobId, gameId: 'game-$jobId', state: state);

  test('JobState.isActive', () {
    expect(JobState.values.where((s) => s.isActive), [
      JobState.queued,
      JobState.running,
    ]);
  });

  test('watchActive lists queued and running jobs, oldest first', () async {
    await upsert(alice, 'j1', JobState.queued);
    clock.advance(const Duration(seconds: 1));
    await upsert(alice, 'j2', JobState.running);
    await upsert(alice, 'j3', JobState.done);
    await upsert(alice, 'j4', JobState.failed);

    final active = await dao.watchActive(alice).first;
    expect(active.map((j) => j.jobId), ['j1', 'j2']);
    expect(active.first.gameId, 'game-j1');
    expect(active.first.lastPolledAt, isNull);
    expect((await dao.getActive(alice)).map((j) => j.jobId), ['j1', 'j2']);
  });

  test('upsert changes the state and keeps created_at', () async {
    await upsert(alice, 'j1', JobState.queued);
    final created = clock();
    clock.advance(const Duration(minutes: 1));
    await dao.markPolled(alice, ['j1']);
    await upsert(alice, 'j1', JobState.running);

    final job = (await dao.getActive(alice)).single;
    expect(job.state, JobState.running);
    expect(job.createdAt.isAtSameMomentAs(created), isTrue);
    expect(job.lastPolledAt!.isAtSameMomentAs(clock()), isTrue);

    await upsert(alice, 'j1', JobState.done);
    expect(await dao.getActive(alice), isEmpty);
  });

  test('watchActive emits when a job finishes', () async {
    await upsert(alice, 'j1', JobState.queued);
    final seen = <int>[];
    final sub = dao.watchActive(alice).listen((jobs) => seen.add(jobs.length));
    await pumpEventQueue();
    await upsert(alice, 'j1', JobState.done);
    await pumpEventQueue();
    await sub.cancel();

    expect(seen, [1, 0]);
  });

  test('watchLatestForGame follows the newest job of a game', () async {
    await dao.upsert(alice, jobId: 'a', gameId: 'g', state: JobState.failed);
    clock.advance(const Duration(seconds: 1));
    await dao.upsert(alice, jobId: 'b', gameId: 'g', state: JobState.queued);

    expect((await dao.watchLatestForGame(alice, 'g').first)!.jobId, 'b');
    expect(await dao.watchLatestForGame(alice, 'other').first, isNull);
  });

  test('remove and removeFinished', () async {
    await upsert(alice, 'j1', JobState.queued);
    await upsert(alice, 'j2', JobState.done);
    await upsert(alice, 'j3', JobState.failed);

    expect(await dao.removeFinished(alice), 2);
    expect(await dao.remove(alice, 'j1'), isTrue);
    expect(await dao.remove(alice, 'j1'), isFalse);
    expect(await dao.getActive(alice), isEmpty);
  });

  test('owner scoping', () async {
    await upsert(bob, 'j1', JobState.queued);

    expect(await dao.watchActive(alice).first, isEmpty);
    expect(await dao.watchLatestForGame(alice, 'game-j1').first, isNull);
    expect(await dao.remove(alice, 'j1'), isFalse);
    expect(await dao.removeFinished(alice), 0);
    await dao.markPolled(alice, ['j1']);
    await upsert(alice, 'j1', JobState.done);

    final job = (await dao.getActive(bob)).single;
    expect(job.state, JobState.queued);
    expect(job.lastPolledAt, isNull);
  });
}
