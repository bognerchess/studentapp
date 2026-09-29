// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late AnalysisCacheDao dao;

  setUp(() {
    clock = FakeClock();
    db = openTestDatabase(clock);
    dao = db.analysisCacheDao;
  });

  tearDown(() => db.close());

  Future<void> put(
    String owner,
    String gameId,
    String payload, {
    int minor = 0,
  }) {
    return dao.putCoach(
      owner,
      gameId,
      schemaVersion: 1,
      schemaMinor: minor,
      payload: payload,
    );
  }

  test('putCoach stores the document and get reads it back', () async {
    await put(alice, 'g1', '{"schema_version":1}', minor: 2);

    final cached = (await dao.get(alice, 'g1'))!;
    expect(cached.schemaVersion, 1);
    expect(cached.schemaMinor, 2);
    expect(cached.payload, '{"schema_version":1}');
    expect(cached.fetchedAt.isAtSameMomentAs(clock()), isTrue);
    expect(await dao.get(alice, 'other'), isNull);
  });

  test('putCoach replaces the document of the same game', () async {
    await put(alice, 'g1', 'old');
    clock.advance(const Duration(hours: 1));
    await dao.putCoach(
      alice,
      'g1',
      schemaVersion: 2,
      schemaMinor: 1,
      payload: 'new',
    );

    final cached = (await dao.get(alice, 'g1'))!;
    expect(cached.payload, 'new');
    expect(cached.schemaVersion, 2);
    expect(cached.fetchedAt.isAtSameMomentAs(clock()), isTrue);
  });

  test('watch emits the new document', () async {
    final seen = <String?>[];
    final sub = dao.watch(alice, 'g1').listen((a) => seen.add(a?.payload));
    await pumpEventQueue();
    await put(alice, 'g1', 'first');
    await pumpEventQueue();
    await sub.cancel();

    expect(seen, [null, 'first']);
  });

  test('remove', () async {
    await put(alice, 'g1', 'x');
    expect(await dao.remove(alice, 'g1'), isTrue);
    expect(await dao.remove(alice, 'g1'), isFalse);
    expect(await dao.get(alice, 'g1'), isNull);
  });

  Future<bool> putEngine(
    String owner,
    String gameId,
    String payload, {
    String stage = 'BASE_EVALUATION',
    String runIds = '{"BASE_EVALUATION":"run-be"}',
  }) {
    return dao.putEngine(
      owner,
      gameId,
      schemaVersion: 1,
      schemaMinor: 0,
      payload: payload,
      stage: stage,
      stageRunIds: runIds,
    );
  }

  group('source', () {
    test('a coach document says so and carries no stage', () async {
      await put(alice, 'g1', 'coached');

      final cached = (await dao.get(alice, 'g1'))!;
      expect(cached.source, AnalysisSource.coach);
      expect(cached.stage, isNull);
      expect(cached.stageRunIds, isNull);
    });

    test('an engine assembly carries its stage and its run ids', () async {
      expect(await putEngine(alice, 'g1', 'assembled'), isTrue);

      final cached = (await dao.get(alice, 'g1'))!;
      expect(cached.source, AnalysisSource.engine);
      expect(cached.stage, 'BASE_EVALUATION');
      expect(cached.stageRunIds, '{"BASE_EVALUATION":"run-be"}');
      expect(cached.payload, 'assembled');
    });

    test('an engine assembly replaces an older one', () async {
      await putEngine(alice, 'g1', 'stage 1');
      clock.advance(const Duration(minutes: 2));

      expect(
        await putEngine(
          alice,
          'g1',
          'stage 3',
          stage: 'DEEP_EVALUATION',
          runIds: '{"DEEP_EVALUATION":"run-de"}',
        ),
        isTrue,
      );
      final cached = (await dao.get(alice, 'g1'))!;
      expect(cached.payload, 'stage 3');
      expect(cached.stage, 'DEEP_EVALUATION');
      expect(cached.fetchedAt.isAtSameMomentAs(clock()), isTrue);
    });

    test('an engine assembly never writes over a coach document', () async {
      await put(alice, 'g1', 'coached');

      expect(await putEngine(alice, 'g1', 'assembled'), isFalse);
      final cached = (await dao.get(alice, 'g1'))!;
      expect(cached.payload, 'coached');
      expect(cached.source, AnalysisSource.coach);
    });

    test('a coach document does write over an engine assembly', () async {
      await putEngine(alice, 'g1', 'assembled');
      await put(alice, 'g1', 'coached');

      final cached = (await dao.get(alice, 'g1'))!;
      expect(cached.payload, 'coached');
      expect(cached.source, AnalysisSource.coach);
      // The stage columns of the row it replaced are gone with it.
      expect(cached.stage, isNull);
      expect(cached.stageRunIds, isNull);
    });

    test(
      'clearCoach drops a coach row so the engine one can come back',
      () async {
        await put(alice, 'g1', 'coached');

        expect(await dao.clearCoach(alice, 'g1'), isTrue);
        expect(await dao.get(alice, 'g1'), isNull);
        expect(await putEngine(alice, 'g1', 'assembled'), isTrue);
      },
    );

    test('clearCoach leaves an engine assembly alone', () async {
      await putEngine(alice, 'g1', 'assembled');

      expect(await dao.clearCoach(alice, 'g1'), isFalse);
      expect((await dao.get(alice, 'g1'))!.payload, 'assembled');
    });
  });

  test('owner scoping', () async {
    await put(bob, 'g1', 'bobs');

    expect(await dao.get(alice, 'g1'), isNull);
    expect(await dao.watch(alice, 'g1').first, isNull);
    expect(await dao.remove(alice, 'g1'), isFalse);
    await put(alice, 'g1', 'stolen');
    expect(await dao.get(alice, 'g1'), isNull);
    expect((await dao.get(bob, 'g1'))!.payload, 'bobs');
    expect(await putEngine(alice, 'g1', 'stolen'), isFalse);
    expect(await dao.clearCoach(alice, 'g1'), isFalse);
    expect((await dao.get(bob, 'g1'))!.payload, 'bobs');
  });
}
