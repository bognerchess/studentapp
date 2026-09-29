// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

const _deep = 'DEEP_EVALUATION';
const _coaching = 'COACHING';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late PendingWorkflowsDao dao;

  setUp(() {
    clock = FakeClock();
    db = openTestDatabase(clock);
    dao = db.pendingWorkflowsDao;
  });

  tearDown(() => db.close());

  Future<void> upsert(
    String owner,
    String gameId, {
    String target = _deep,
    WorkflowState state = WorkflowState.running,
  }) => dao.upsert(owner, gameId: gameId, targetStage: target, state: state);

  test('WorkflowState.isActive', () {
    expect(WorkflowState.values.where((s) => s.isActive), [
      WorkflowState.running,
    ]);
  });

  test('upsert records a game to watch', () async {
    await upsert(alice, 'g1');

    final row = (await dao.get(alice, 'g1'))!;
    expect(row.gameId, 'g1');
    expect(row.targetStage, _deep);
    expect(row.state, WorkflowState.running);
    expect(row.createdAt.isAtSameMomentAs(clock()), isTrue);
    expect(row.lastPolledAt, isNull);
  });

  test(
    'a second upsert moves the target without restarting the clock',
    () async {
      await upsert(alice, 'g1');
      await dao.markPolled(alice, ['g1']);
      final created = (await dao.get(alice, 'g1'))!.createdAt;
      clock.advance(const Duration(minutes: 5));

      // Asking for the coach after the engine chain finished is the same
      // workflow going further, not a new one.
      await upsert(alice, 'g1', target: _coaching);

      final row = (await dao.get(alice, 'g1'))!;
      expect(row.targetStage, _coaching);
      expect(row.createdAt.isAtSameMomentAs(created), isTrue);
      expect(row.lastPolledAt, isNotNull);
    },
  );

  test('watchActive lists the running games, oldest first', () async {
    await upsert(alice, 'g1');
    clock.advance(const Duration(seconds: 1));
    await upsert(alice, 'g2');
    await upsert(alice, 'g3', state: WorkflowState.done);
    await upsert(alice, 'g4', state: WorkflowState.failed);

    final active = await dao.watchActive(alice).first;
    expect(active.map((w) => w.gameId), ['g1', 'g2']);
    expect(await dao.getActive(alice), hasLength(2));
  });

  test(
    'watchActive emits when a game is added and when one finishes',
    () async {
      final seen = <List<String>>[];
      final sub = dao
          .watchActive(alice)
          .listen((rows) => seen.add([for (final r in rows) r.gameId]));
      await pumpEventQueue();
      await upsert(alice, 'g1');
      await pumpEventQueue();
      await dao.setState(alice, 'g1', WorkflowState.done);
      await pumpEventQueue();
      await sub.cancel();

      expect(seen, [
        <String>[],
        ['g1'],
        <String>[],
      ]);
    },
  );

  test('setState says whether there was a row to move', () async {
    expect(await dao.setState(alice, 'g1', WorkflowState.done), isFalse);
    await upsert(alice, 'g1');

    expect(await dao.setState(alice, 'g1', WorkflowState.failed), isTrue);
    final row = (await dao.get(alice, 'g1'))!;
    expect(row.state, WorkflowState.failed);
    // The target is what the user asked for; a failure does not change it.
    expect(row.targetStage, _deep);
  });

  test('markPolled stamps only the games it names', () async {
    await upsert(alice, 'g1');
    await upsert(alice, 'g2');
    clock.advance(const Duration(seconds: 3));

    await dao.markPolled(alice, ['g1']);

    expect(
      (await dao.get(alice, 'g1'))!.lastPolledAt!.isAtSameMomentAs(clock()),
      isTrue,
    );
    expect((await dao.get(alice, 'g2'))!.lastPolledAt, isNull);
  });

  test('watch follows one game', () async {
    final seen = <String?>[];
    final sub = dao.watch(alice, 'g1').listen((w) => seen.add(w?.state.name));
    await pumpEventQueue();
    await upsert(alice, 'g1');
    await pumpEventQueue();
    await dao.remove(alice, 'g1');
    await pumpEventQueue();
    await sub.cancel();

    expect(seen, [null, 'running', null]);
  });

  test('remove', () async {
    await upsert(alice, 'g1');

    expect(await dao.remove(alice, 'g1'), isTrue);
    expect(await dao.remove(alice, 'g1'), isFalse);
    expect(await dao.get(alice, 'g1'), isNull);
  });

  test('removeFinished drops what is done or failed', () async {
    await upsert(alice, 'g1');
    await upsert(alice, 'g2', state: WorkflowState.done);
    await upsert(alice, 'g3', state: WorkflowState.failed);

    expect(await dao.removeFinished(alice), 2);
    expect((await dao.getActive(alice)).map((w) => w.gameId), ['g1']);
  });

  test('owner scoping', () async {
    await upsert(bob, 'g1');

    expect(await dao.get(alice, 'g1'), isNull);
    expect(await dao.watch(alice, 'g1').first, isNull);
    expect(await dao.getActive(alice), isEmpty);
    expect(await dao.setState(alice, 'g1', WorkflowState.failed), isFalse);
    expect(await dao.remove(alice, 'g1'), isFalse);
    expect(await dao.removeFinished(alice), 0);
    await dao.markPolled(alice, ['g1']);
    await upsert(alice, 'g1', target: _coaching);

    final stolen = (await dao.get(bob, 'g1'))!;
    expect(stolen.targetStage, _deep);
    expect(stolen.state, WorkflowState.running);
    expect(stolen.lastPolledAt, isNull);
    expect(await dao.get(alice, 'g1'), isNull);
  });
}
