// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/push/push_permission.dart';
import 'package:bogner_chess/core/push/push_platform.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/test_database.dart';

void main() {
  final now = DateTime.utc(2026, 9, 20, 12);

  PushAskDecision decide(
    PushPermissionStatus status, [
    PushAskRecord record = const PushAskRecord(),
  ]) => decidePushAsk(status: status, record: record, now: now);

  group('decidePushAsk', () {
    test('never asked: ask', () {
      expect(decide(PushPermissionStatus.notDetermined), PushAskDecision.ask);
    });

    test('allowed: nothing to ask', () {
      expect(
        decide(PushPermissionStatus.authorized),
        PushAskDecision.alreadyAuthorized,
      );
    });

    test('denied in iOS: never again, whatever the record says', () {
      expect(decide(PushPermissionStatus.denied), PushAskDecision.denied);
      expect(
        decide(
          PushPermissionStatus.denied,
          const PushAskRecord(systemAnswer: 'granted'),
        ),
        PushAskDecision.denied,
      );
    });

    test('a remembered denial wins over an undetermined status', () {
      expect(
        decide(
          PushPermissionStatus.notDetermined,
          const PushAskRecord(systemAnswer: 'denied'),
        ),
        PushAskDecision.denied,
      );
    });

    test('"Not now" waits two weeks', () {
      PushAskDecision after(Duration ago) => decide(
        PushPermissionStatus.notDetermined,
        PushAskRecord(notNowCount: 1, lastNotNowAt: now.subtract(ago)),
      );
      expect(after(const Duration(days: 1)), PushAskDecision.notNow);
      expect(
        after(const Duration(days: 13, hours: 23)),
        PushAskDecision.notNow,
      );
      expect(after(const Duration(days: 14)), PushAskDecision.ask);
    });

    test('a second "Not now" is final', () {
      expect(
        decide(
          PushPermissionStatus.notDetermined,
          PushAskRecord(
            notNowCount: 2,
            lastNotNowAt: now.subtract(const Duration(days: 400)),
          ),
        ),
        PushAskDecision.notNow,
      );
    });
  });

  group('PushAskStore', () {
    late AppDatabase db;
    late PushAskStore store;

    setUp(() {
      db = openTestDatabase(FakeClock());
      store = PushAskStore(db.kvDao);
    });

    tearDown(() => db.close());

    test('starts empty', () async {
      final record = await store.read();
      expect(record.systemAnswer, isNull);
      expect(record.notNowCount, 0);
      expect(record.lastNotNowAt, isNull);
    });

    test('remembers "Not now" with count and time', () async {
      await store.recordNotNow(now);
      await store.recordNotNow(now.add(const Duration(days: 20)));
      final record = await store.read();
      expect(record.notNowCount, 2);
      expect(record.lastNotNowAt, now.add(const Duration(days: 20)));
    });

    test('remembers the answer to the system prompt', () async {
      await store.recordSystemAnswer(granted: false);
      expect((await store.read()).systemAnswer, 'denied');
    });

    test('belongs to the installation: a sign-out wipe keeps it', () async {
      await store.recordSystemAnswer(granted: false);
      await db.wipeOwner(alice);
      expect((await store.read()).systemAnswer, 'denied');
    });
  });
}
