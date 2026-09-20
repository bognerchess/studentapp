// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:convert';

import 'package:bogner_chess/core/analytics/analytics.dart';
import 'package:bogner_chess/core/analytics/props_sanitizer.dart';
import 'package:bogner_chess/core/analytics/session_tracker.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:flutter/foundation.dart';

/// Answers "may this event be recorded?" at the moment it happens. It is
/// asynchronous only because the stored decision is read from the
/// preferences after a start; once that is done it answers at once.
typedef AnalyticsConsentGate = Future<bool> Function();

/// The [Analytics] of the running app: consent gate, sanitiser, outbox.
///
/// * Without the user's consent nothing is written, not even to the local
///   database. Events from before the decision are dropped, not kept for
///   later: consent does not work backwards.
/// * The name must be one of [AnalyticsEvents.all]; properties go through
///   [sanitizeEventProps].
/// * The event gets the time of the call (UTC), the session id of that moment
///   and the signed-in subject as owner, and waits in the [EventOutboxDao]
///   for the `EventFlusher`. The app version travels with the batch.
///
/// [track] never throws and never blocks: analytics must not be able to break
/// a feature.
class OutboxAnalytics implements Analytics {
  OutboxAnalytics({
    required this._outbox,
    required this._deviceId,
    required this._consent,
    required this._session,
    required this._ownerSub,
    required this._now,
    this._onEnqueued,
  });

  final EventOutboxDao _outbox;
  final Future<String> Function() _deviceId;
  final AnalyticsConsentGate _consent;
  final SessionTracker _session;
  final String? Function() _ownerSub;
  final DateTime Function() _now;
  final void Function()? _onEnqueued;

  static const _log = Log('analytics');

  /// Writes happen one after the other, so events keep their order.
  Future<void> _tail = Future<void>.value();

  /// Completes when everything tracked so far has been written or dropped.
  @visibleForTesting
  Future<void> get idle => _tail;

  @override
  void track(String name, [Map<String, Object?> props = const {}]) {
    // What belongs to the moment of the call is read now, not when the
    // write gets its turn.
    final occurredAt = _now().toUtc();
    final sessionId = _session.sessionId;
    final ownerSub = _ownerSub();
    _tail = _tail.then(
      (_) => _record(name, props, occurredAt, sessionId, ownerSub),
    );
  }

  Future<void> _record(
    String name,
    Map<String, Object?> props,
    DateTime occurredAt,
    String sessionId,
    String? ownerSub,
  ) async {
    try {
      if (!AnalyticsEvents.all.contains(name)) {
        // A typo or an event that was never agreed on. Names are constants,
        // so this is safe to log.
        _log.warning('dropped an event with an unknown name');
        return;
      }
      if (!await _consent()) {
        return;
      }
      await _outbox.enqueue(
        deviceId: await _deviceId(),
        sessionId: sessionId,
        name: name,
        ownerSub: ownerSub,
        occurredAt: occurredAt,
        propsJson: jsonEncode(sanitizeEventProps(props)),
      );
      _onEnqueued?.call();
    } on Object catch (error) {
      _log.warning('could not record an event (${error.runtimeType})');
    }
  }
}
