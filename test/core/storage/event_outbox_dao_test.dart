// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late EventOutboxDao dao;

  setUp(() {
    clock = FakeClock();
    db = openTestDatabase(clock);
    dao = db.eventOutboxDao;
  });

  tearDown(() => db.close());

  Future<int> enqueue(String name, {String? owner, int? maxRows}) {
    return dao.enqueue(
      deviceId: 'device-1',
      sessionId: 'session-1',
      name: name,
      ownerSub: owner,
      maxRows: maxRows ?? EventOutboxDao.defaultMaxRows,
    );
  }

  test('enqueue stores the event with defaults', () async {
    final id = await enqueue('app_opened');
    final event = (await dao.takeBatch(10)).single;

    expect(event.id, id);
    expect(event.ownerSub, isNull);
    expect(event.deviceId, 'device-1');
    expect(event.sessionId, 'session-1');
    expect(event.name, 'app_opened');
    expect(event.propsJson, '{}');
    expect(event.attempts, 0);
    expect(event.occurredAt.isAtSameMomentAs(clock()), isTrue);
  });

  test('enqueue keeps an explicit time, owner and properties', () async {
    final at = DateTime.utc(2026, 9, 1, 8);
    await dao.enqueue(
      deviceId: 'd',
      sessionId: 's',
      name: 'game_submitted',
      ownerSub: alice,
      occurredAt: at,
      propsJson: '{"plies":80}',
    );
    final event = (await dao.takeBatch(1)).single;

    expect(event.ownerSub, alice);
    expect(event.propsJson, '{"plies":80}');
    expect(event.occurredAt.isAtSameMomentAs(at), isTrue);
  });

  test('takeBatch returns the oldest N in order', () async {
    for (var i = 0; i < 5; i++) {
      await enqueue('e$i');
    }
    expect((await dao.takeBatch(3)).map((e) => e.name), ['e0', 'e1', 'e2']);
    expect(await dao.count(), 5, reason: 'taking does not remove');
  });

  test('removeByIds after a successful send', () async {
    for (var i = 0; i < 4; i++) {
      await enqueue('e$i');
    }
    final batch = await dao.takeBatch(2);
    expect(await dao.removeByIds(batch.map((e) => e.id)), 2);
    expect((await dao.takeBatch(10)).map((e) => e.name), ['e2', 'e3']);
  });

  test('bumpAttempts and removeExhausted after failed sends', () async {
    final a = await enqueue('a');
    final b = await enqueue('b');
    await dao.bumpAttempts([a, b]);
    await dao.bumpAttempts([a]);

    final events = await dao.takeBatch(10);
    expect(events.map((e) => e.attempts), [2, 1]);

    expect(await dao.removeExhausted(2), 1);
    expect((await dao.takeBatch(10)).single.id, b);
  });

  test('the outbox is capped: the oldest events go first', () async {
    for (var i = 0; i < 7; i++) {
      await enqueue('e$i', maxRows: 5);
    }
    expect(await dao.count(), 5);
    expect((await dao.takeBatch(10)).map((e) => e.name), [
      'e2',
      'e3',
      'e4',
      'e5',
      'e6',
    ]);

    expect(await dao.trim(2), 3);
    expect((await dao.takeBatch(10)).map((e) => e.name), ['e5', 'e6']);
  });

  test('clear empties the outbox', () async {
    await enqueue('a');
    await enqueue('b', owner: alice);
    expect(await dao.clear(), 2);
    expect(await dao.count(), 0);
  });
}
