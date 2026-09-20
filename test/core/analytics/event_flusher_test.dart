// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:io';

import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/analytics/event_flusher.dart';
import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixture_link.dart';
import '../../helpers/pump_app.dart';
import '../storage/test_database.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late FixtureLink api;
  late ProviderContainer container;
  late String? sub;
  late bool consent;
  late EventFlusher flusher;

  setUp(() {
    Log.sink = (_) {};
    clock = FakeClock();
    db = openTestDatabase(clock);
    api = FixtureLink();
    container = ProviderContainer(
      overrides: [envProvider.overrideWithValue(testEnv()), ...api.overrides],
    );
    sub = alice;
    consent = true;
    flusher = EventFlusher(
      outbox: db.eventOutboxDao,
      api: container.read(eventsApiProvider),
      currentSub: () => sub,
      consentGranted: () => consent,
      appVersion: () async => '1.2.3+45',
      now: clock.call,
    );
  });

  tearDown(() async {
    Log.resetSink();
    container.dispose();
    await db.close();
  });

  Future<void> enqueue(
    int count, {
    String session = 'session-1',
    String? owner = alice,
    String props = '{}',
  }) async {
    for (var i = 0; i < count; i++) {
      await db.eventOutboxDao.enqueue(
        deviceId: 'device-1',
        sessionId: session,
        name: 'review_opened',
        ownerSub: owner,
        propsJson: props,
      );
    }
  }

  List<Map<String, dynamic>> inputs() => [
    for (final request in api.requestsOf('TrackMobileEvents'))
      request.variables['input'] as Map<String, dynamic>,
  ];

  test('an empty outbox makes no request', () async {
    expect(await flusher.flush(), FlushOutcome.drained);
    expect(api.requests, isEmpty);
  });

  test('sends device, session, version, name, time and properties', () async {
    await enqueue(1, props: '{"plies":80}');
    expect(await flusher.flush(), FlushOutcome.drained);

    final input = inputs().single;
    expect(input['deviceId'], 'device-1');
    expect(input['sessionId'], 'session-1');
    expect(input['appVersion'], '1.2.3+45');
    final event = (input['events'] as List).single as Map<String, dynamic>;
    expect(event['name'], 'review_opened');
    expect(DateTime.parse(event['occurredAt'] as String).isUtc, isTrue);
    expect(event['props'], {'plies': 80});
    expect(await db.eventOutboxDao.count(), 0);
  });

  test('120 events go out in batches of at most 50, oldest first', () async {
    await enqueue(120);
    expect(await flusher.flush(), FlushOutcome.drained);

    expect(
      [for (final input in inputs()) (input['events'] as List).length],
      [50, 50, 20],
    );
    expect(await db.eventOutboxDao.count(), 0);
  });

  test('one call carries the events of one session', () async {
    await enqueue(2, session: 'session-1');
    await enqueue(3, session: 'session-2');
    await enqueue(1, session: 'session-1');
    await flusher.flush();

    expect(
      [
        for (final input in inputs())
          '${input['sessionId']}:${(input['events'] as List).length}',
      ],
      ['session-1:2', 'session-2:3', 'session-1:1'],
    );
  });

  test('events the server rejected are gone as well', () async {
    api.use('TrackMobileEvents', 'partially_rejected');
    await enqueue(3);
    expect(await flusher.flush(), FlushOutcome.drained);
    expect(await db.eventOutboxDao.count(), 0);
  });

  test('signed out: nothing is sent, nothing is lost', () async {
    sub = null;
    await enqueue(2, owner: null);
    expect(await flusher.flush(), FlushOutcome.notAllowed);
    expect(api.requests, isEmpty);
    expect(await db.eventOutboxDao.count(), 2);

    sub = alice;
    expect(await flusher.flush(), FlushOutcome.drained);
    expect(await db.eventOutboxDao.count(), 0);
  });

  test('without consent nothing is sent', () async {
    consent = false;
    await enqueue(2);
    expect(await flusher.flush(), FlushOutcome.notAllowed);
    expect(api.requests, isEmpty);
  });

  test("another account's events are dropped, never sent", () async {
    await enqueue(2, owner: bob);
    await enqueue(1, owner: null);
    await enqueue(1);
    expect(await flusher.flush(), FlushOutcome.drained);

    expect((inputs().single['events'] as List).length, 2);
    expect(await db.eventOutboxDao.count(), 0);
  });

  group('failures', () {
    test('offline keeps the batch, counts an attempt and backs off', () async {
      api.fail('TrackMobileEvents', const SocketException('offline'));
      await enqueue(3);

      expect(await flusher.flush(), FlushOutcome.failed);
      final rows = await db.eventOutboxDao.takeBatch(10);
      expect([for (final row in rows) row.attempts], [1, 1, 1]);
      expect(flusher.notBefore, clock().add(const Duration(seconds: 60)));

      // Too early: no request at all.
      clock.advance(const Duration(seconds: 59));
      expect(await flusher.flush(), FlushOutcome.backingOff);
      expect(api.requestsOf('TrackMobileEvents'), hasLength(1));

      // The second failure doubles the wait.
      clock.advance(const Duration(seconds: 1));
      expect(await flusher.flush(), FlushOutcome.failed);
      expect(flusher.notBefore, clock().add(const Duration(seconds: 120)));

      // Back online.
      api.use('TrackMobileEvents', 'default');
      clock.advance(const Duration(seconds: 120));
      expect(await flusher.flush(), FlushOutcome.drained);
      expect(flusher.notBefore, isNull);
      expect(await db.eventOutboxDao.count(), 0);
    });

    test('the back-off is capped at an hour', () async {
      api.fail('TrackMobileEvents', const SocketException('offline'));
      await enqueue(1);
      for (var i = 0; i < 9; i++) {
        await flusher.flush(force: true);
      }
      expect(flusher.notBefore, clock().add(const Duration(hours: 1)));
    });

    test('a rate limit waits at least as long as the server says', () async {
      api.use('TrackMobileEvents', 'rate_limited');
      await enqueue(1);
      expect(await flusher.flush(), FlushOutcome.failed);
      // retryAfterSeconds 42 is below the first back-off of 60 s.
      expect(flusher.notBefore, clock().add(const Duration(seconds: 60)));
      expect(await db.eventOutboxDao.count(), 1);
    });

    test('force ignores the back-off (the flush before a sign-out)', () async {
      api.fail('TrackMobileEvents', const SocketException('offline'));
      await enqueue(1);
      await flusher.flush();
      api.use('TrackMobileEvents', 'default');

      expect(await flusher.flush(), FlushOutcome.backingOff);
      expect(await flusher.flush(force: true), FlushOutcome.drained);
    });

    test('after ten failed attempts an event is dropped', () async {
      api.fail('TrackMobileEvents', const SocketException('offline'));
      await enqueue(2);
      for (var i = 0; i < 10; i++) {
        expect(await flusher.flush(force: true), FlushOutcome.failed);
      }
      expect(await db.eventOutboxDao.count(), 2);
      await enqueue(1);

      // The eleventh flush removes the exhausted ones first; the fresh event
      // is still tried.
      expect(await flusher.flush(force: true), FlushOutcome.failed);
      final rows = await db.eventOutboxDao.takeBatch(10);
      expect([for (final row in rows) row.attempts], [1]);
    });

    test('a validation error drops the batch and goes on', () async {
      await enqueue(60);
      var calls = 0;
      final invalid = api.store.response('TrackMobileEvents', 'input_invalid');
      final fine = api.store.response('TrackMobileEvents', 'default');
      api.respond('TrackMobileEvents', (_) => calls++ == 0 ? invalid : fine);

      expect(await flusher.flush(), FlushOutcome.drained);
      expect(calls, 2);
      expect(await db.eventOutboxDao.count(), 0);
      expect(flusher.notBefore, isNull);
    });

    test(
      'an ended session stops the flush without counting an attempt',
      () async {
        api.respond(
          'TrackMobileEvents',
          (_) => {
            'errors': [
              {
                'message': 'not authenticated',
                'extensions': {'code': 'AUTH_NOT_AUTHENTICATED'},
              },
            ],
          },
        );
        await enqueue(1);
        expect(await flusher.flush(), FlushOutcome.notAllowed);
        expect((await db.eventOutboxDao.takeBatch(1)).single.attempts, 0);
        expect(flusher.notBefore, isNull);
      },
    );
  });

  test('flush is single-flight', () async {
    api.delay = const Duration(milliseconds: 20);
    await enqueue(1);
    final results = await Future.wait([flusher.flush(), flusher.flush()]);
    expect(results, [FlushOutcome.drained, FlushOutcome.drained]);
    expect(api.requestsOf('TrackMobileEvents'), hasLength(1));
  });

  test('a sign-out during a request ends the flush', () async {
    await enqueue(60);
    api.respond('TrackMobileEvents', (_) {
      sub = null;
      return api.store.response('TrackMobileEvents', 'default');
    });
    expect(await flusher.flush(), FlushOutcome.notAllowed);
    expect(api.requestsOf('TrackMobileEvents'), hasLength(1));
    expect(await db.eventOutboxDao.count(), 10);
  });
}
