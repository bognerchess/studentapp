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
    return dao.put(
      owner,
      gameId,
      schemaVersion: 1,
      schemaMinor: minor,
      payload: payload,
    );
  }

  test('put stores the document and get reads it back', () async {
    await put(alice, 'g1', '{"schema_version":1}', minor: 2);

    final cached = (await dao.get(alice, 'g1'))!;
    expect(cached.schemaVersion, 1);
    expect(cached.schemaMinor, 2);
    expect(cached.payload, '{"schema_version":1}');
    expect(cached.fetchedAt.isAtSameMomentAs(clock()), isTrue);
    expect(await dao.get(alice, 'other'), isNull);
  });

  test('put replaces the document of the same game', () async {
    await put(alice, 'g1', 'old');
    clock.advance(const Duration(hours: 1));
    await dao.put(
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

  test('owner scoping', () async {
    await put(bob, 'g1', 'bobs');

    expect(await dao.get(alice, 'g1'), isNull);
    expect(await dao.watch(alice, 'g1').first, isNull);
    expect(await dao.remove(alice, 'g1'), isFalse);
    await put(alice, 'g1', 'stolen');
    expect(await dao.get(alice, 'g1'), isNull);
    expect((await dao.get(bob, 'g1'))!.payload, 'bobs');
  });
}
