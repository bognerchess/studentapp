// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:convert';

import 'package:bogner_chess/core/analytics/analysis_analytics.dart';
import 'package:bogner_chess/core/analytics/analytics.dart';
import 'package:bogner_chess/core/analytics/outbox_analytics.dart';
import 'package:bogner_chess/core/analytics/props_sanitizer.dart';
import 'package:bogner_chess/core/analytics/session_tracker.dart';
import 'package:bogner_chess/core/api/models/stage_models.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/test_database.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late SessionTracker session;
  late bool consent;
  late String? sub;
  late int enqueued;
  late OutboxAnalytics analytics;

  setUp(() {
    Log.sink = (_) {};
    clock = FakeClock();
    db = openTestDatabase(clock);
    var ids = 0;
    session = SessionTracker(now: clock.call, newId: () => 'session-${++ids}');
    consent = true;
    sub = alice;
    enqueued = 0;
    analytics = OutboxAnalytics(
      outbox: db.eventOutboxDao,
      deviceId: () async => 'device-1',
      consent: () async => consent,
      session: session,
      ownerSub: () => sub,
      now: clock.call,
      onEnqueued: () => enqueued++,
    );
  });

  tearDown(() async {
    Log.resetSink();
    await db.close();
  });

  Future<List<OutboxEvent>> rows() async {
    await analytics.idle;
    return db.eventOutboxDao.takeBatch(100);
  }

  test('an event gets time, session, device and owner', () async {
    analytics.track(AnalyticsEvents.gameSubmitted, {'plies': 80});
    final row = (await rows()).single;

    expect(row.name, 'game_submitted');
    expect(row.deviceId, 'device-1');
    expect(row.sessionId, 'session-1');
    expect(row.ownerSub, alice);
    expect(row.occurredAt.isAtSameMomentAs(clock()), isTrue);
    expect(jsonDecode(row.propsJson), {'plies': 80});
    expect(enqueued, 1);
  });

  test(
    'without consent nothing is written, and nothing is kept for later',
    () async {
      consent = false;
      analytics.track(AnalyticsEvents.appOpen);
      expect(await rows(), isEmpty);

      consent = true;
      analytics.track(AnalyticsEvents.reviewOpened);
      expect([for (final row in await rows()) row.name], ['review_opened']);
    },
  );

  test('the gate is asked per event, at the time of the event', () async {
    final gate = Completer<bool>();
    final slow = OutboxAnalytics(
      outbox: db.eventOutboxDao,
      deviceId: () async => 'device-1',
      // The stored decision is still being read: the event waits for it.
      consent: () => gate.future,
      session: session,
      ownerSub: () => sub,
      now: clock.call,
    );
    slow.track(AnalyticsEvents.appOpen, {'start': 'cold'});
    final at = clock();
    clock.advance(const Duration(seconds: 5));
    gate.complete(true);
    await slow.idle;

    final row = (await db.eventOutboxDao.takeBatch(10)).single;
    expect(row.name, 'app_open');
    expect(row.occurredAt.isAtSameMomentAs(at), isTrue);
  });

  test('an unknown name is dropped', () async {
    analytics.track('made_up_event');
    expect(await rows(), isEmpty);
  });

  test('properties are sanitised', () async {
    analytics.track(AnalyticsEvents.pgnImported, {
      'source': 'paste',
      'white': 'Hans Muster',
      'pgn': '1. e4 e5',
    });
    expect(jsonDecode((await rows()).single.propsJson), {'source': 'paste'});
  });

  test('signed out, an event has no owner', () async {
    sub = null;
    analytics.track(AnalyticsEvents.appOpen);
    expect((await rows()).single.ownerSub, isNull);
  });

  test('events keep their order and the session of their moment', () async {
    analytics.track(AnalyticsEvents.appOpen);
    session.onBackgrounded();
    clock.advance(const Duration(minutes: 31));
    session.onForegrounded();
    analytics
      ..track(AnalyticsEvents.appOpen)
      ..track(AnalyticsEvents.reviewOpened);

    expect(
      [for (final row in await rows()) '${row.name}/${row.sessionId}'],
      ['app_open/session-1', 'app_open/session-2', 'review_opened/session-2'],
    );
  });

  test('track never throws, not even with a closed database', () async {
    await db.close();
    expect(() => analytics.track(AnalyticsEvents.appOpen), returnsNormally);
    await analytics.idle;
    db = openTestDatabase(clock);
  });

  test('every event name is snake case, as the server expects', () {
    for (final name in AnalyticsEvents.all) {
      expect(name, matches(RegExp(r'^[a-z][a-z_]+$')));
    }
    expect(AnalyticsEvents.all, hasLength(18));
  });

  group('the analysis pipeline', () {
    late _Recorder analytics;

    setUp(() => analytics = _Recorder());

    // A record that holds a map is only equal to itself, so the name and the
    // properties of an event are compared apart.
    Iterable<String> names() => analytics.events.map((e) => e.$1);
    Iterable<Map<String, Object?>> props() => analytics.events.map((e) => e.$2);

    test('one request per tap, whatever the server then runs', () {
      analytics
        ..analysisRequested(source: 'game_detail')
        ..analysisRequested(source: 'submit_queue');

      expect(names(), ['analysis_requested', 'analysis_requested']);
      expect(props(), [
        {'source': 'game_detail'},
        {'source': 'submit_queue'},
      ]);
    });

    test('the app no longer has an event for starting a stage', () {
      expect(AnalyticsEvents.all, isNot(contains('analysis_stage_started')));
    });

    test('ready carries the seconds it took, failed its code', () {
      analytics
        ..stageReady(
          AnalysisStage.deepEvaluation,
          took: const Duration(minutes: 2, seconds: 5),
        )
        ..stageReady(AnalysisStage.baseEvaluation)
        ..stageFailed(AnalysisStage.coaching, code: 'stage_input_missing')
        ..coachRequested('de');

      expect(names(), [
        'analysis_stage_ready',
        'analysis_stage_ready',
        'analysis_stage_failed',
        'coach_requested',
      ]);
      expect(props(), [
        {'stage': 'deep_evaluation', 'duration_s': 125},
        {'stage': 'base_evaluation'},
        {'stage': 'coaching', 'code': 'stage_input_missing'},
        {'language': 'de'},
      ]);
    });

    test('a stage this build does not know carries no name', () {
      analytics.stageReady(AnalysisStage.unknown);

      expect(props().single, <String, Object?>{});
    });

    test('every property survives the sanitiser', () {
      analytics
        ..analysisRequested(source: 'submit_queue')
        ..stageReady(AnalysisStage.coaching, took: const Duration(seconds: 3))
        ..stageFailed(AnalysisStage.deepEvaluation, code: 'too_many_attempts');

      for (final event in props()) {
        expect(sanitizeEventProps(event), event);
      }
    });
  });
}

/// The events a caller fired, in order. The pipeline's helpers are about which
/// event goes out with which properties, not about the outbox.
class _Recorder implements Analytics {
  final List<(String, Map<String, Object?>)> events = [];

  @override
  void track(String name, [Map<String, Object?> props = const {}]) =>
      events.add((name, props));
}
