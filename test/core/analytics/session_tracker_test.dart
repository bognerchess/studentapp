// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analytics/session_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late int ids;
  late SessionTracker tracker;

  setUp(() {
    now = DateTime.utc(2026, 9, 20, 12);
    ids = 0;
    tracker = SessionTracker(now: () => now, newId: () => 'session-${++ids}');
  });

  test('a start begins a session', () {
    expect(tracker.sessionId, 'session-1');
  });

  test('a short time in the background keeps the session', () {
    tracker.onBackgrounded();
    now = now.add(const Duration(minutes: 29, seconds: 59));
    expect(tracker.onForegrounded(), isFalse);
    expect(tracker.sessionId, 'session-1');
  });

  test('30 minutes in the background begin a new one', () {
    tracker.onBackgrounded();
    now = now.add(const Duration(minutes: 30));
    expect(tracker.onForegrounded(), isTrue);
    expect(tracker.sessionId, 'session-2');
  });

  test('the background time counts from the first pause', () {
    tracker.onBackgrounded();
    now = now.add(const Duration(minutes: 20));
    tracker.onBackgrounded();
    now = now.add(const Duration(minutes: 20));
    expect(tracker.onForegrounded(), isTrue);
  });

  test('a resume without a pause changes nothing', () {
    now = now.add(const Duration(hours: 5));
    expect(tracker.onForegrounded(), isFalse);
    expect(tracker.sessionId, 'session-1');
  });

  test('each background stretch is measured on its own', () {
    tracker.onBackgrounded();
    now = now.add(const Duration(minutes: 20));
    expect(tracker.onForegrounded(), isFalse);
    now = now.add(const Duration(minutes: 20));
    tracker.onBackgrounded();
    now = now.add(const Duration(minutes: 20));
    expect(tracker.onForegrounded(), isFalse);
    expect(tracker.sessionId, 'session-1');
  });

  test('the default id is a UUID', () {
    final real = SessionTracker(now: () => now);
    expect(
      real.sessionId,
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab]')),
    );
  });
}
