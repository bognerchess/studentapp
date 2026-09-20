// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:bogner_chess/core/api/events_api.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:flutter/foundation.dart';

/// Why a [EventFlusher.flush] ended.
enum FlushOutcome {
  /// The outbox is empty now (or was already).
  drained,

  /// Nobody is signed in, or there is no consent: nothing was sent.
  notAllowed,

  /// A send failed in a way worth retrying; the events wait.
  failed,

  /// An earlier failure is still backing off.
  backingOff,
}

/// Sends the event outbox to the server.
///
/// * Only while somebody is signed in (the mutation needs a session) and
///   analytics consent is granted.
/// * One call carries at most [EventsApi.maxBatchSize] events of **one**
///   session, because session and device id belong to the call, not to the
///   event. The oldest events go first.
/// * After an answer the whole batch is removed: what the server counted as
///   rejected is dropped for good. A failure that is worth retrying bumps the
///   batch's attempt counter and starts a back-off that doubles up to
///   [maxBackoff]; events that failed [maxAttempts] times are removed. A
///   failure that will not go away (a validation error) removes the batch.
/// * Events recorded under another account are never sent under this one;
///   they are dropped.
///
/// [flush] is single-flight and never throws. When to call it is decided by
/// `EventFlushScheduler`.
class EventFlusher {
  EventFlusher({
    required this._outbox,
    required this._api,
    required this._currentSub,
    required this._consentGranted,
    required this._appVersion,
    required this._now,
    this.maxAttempts = 10,
    this.baseBackoff = const Duration(seconds: 60),
    this.maxBackoff = const Duration(hours: 1),
  });

  final EventOutboxDao _outbox;
  final EventsApi _api;

  /// The signed-in subject, or null.
  final String? Function() _currentSub;
  final bool Function() _consentGranted;
  final Future<String?> Function() _appVersion;
  final DateTime Function() _now;

  final int maxAttempts;
  final Duration baseBackoff;
  final Duration maxBackoff;

  static const _log = Log('analytics.flush');

  Future<FlushOutcome>? _inFlight;
  int _consecutiveFailures = 0;
  DateTime? _notBefore;

  /// When the back-off of the last failure ends; null when there is none.
  @visibleForTesting
  DateTime? get notBefore => _notBefore;

  /// Sends what is waiting. [force] ignores a running back-off: for the last
  /// flush before a sign-out.
  Future<FlushOutcome> flush({bool force = false}) {
    return _inFlight ??= _flush(force).whenComplete(() => _inFlight = null);
  }

  Future<FlushOutcome> _flush(bool force) async {
    try {
      final sub = _currentSub();
      if (sub == null || !_consentGranted()) {
        return FlushOutcome.notAllowed;
      }
      final notBefore = _notBefore;
      if (!force && notBefore != null && _now().isBefore(notBefore)) {
        return FlushOutcome.backingOff;
      }
      final exhausted = await _outbox.removeExhausted(maxAttempts);
      if (exhausted > 0) {
        _log.warning('dropped $exhausted events after $maxAttempts attempts');
      }
      final appVersion = await _appVersion();

      while (true) {
        // The state may change while a request is in the air.
        if (_currentSub() != sub || !_consentGranted()) {
          return FlushOutcome.notAllowed;
        }
        final rows = await _outbox.takeBatch(EventsApi.maxBatchSize);
        if (rows.isEmpty) {
          _succeeded();
          return FlushOutcome.drained;
        }
        final foreign = [
          for (final row in rows)
            if (row.ownerSub != null && row.ownerSub != sub) row.id,
        ];
        if (foreign.isNotEmpty) {
          await _outbox.removeByIds(foreign);
          continue;
        }
        final first = rows.first;
        final batch = rows
            .takeWhile(
              (row) =>
                  row.sessionId == first.sessionId &&
                  row.deviceId == first.deviceId,
            )
            .toList();
        final ids = [for (final row in batch) row.id];
        try {
          final result = await _api.track(
            deviceId: first.deviceId,
            sessionId: first.sessionId,
            appVersion: appVersion,
            events: [for (final row in batch) _eventOf(row)],
          );
          await _outbox.removeByIds(ids);
          if (result.rejected > 0) {
            _log.info('server rejected ${result.rejected} events');
          }
        } on ApiUnauthenticated {
          // The session is over; the auth layer signs out. Not the events'
          // fault: no attempt counted.
          return FlushOutcome.notAllowed;
        } on ApiError catch (error) {
          if (!error.isRetryable) {
            await _outbox.removeByIds(ids);
            _log.warning('dropped ${ids.length} events (${error.runtimeType})');
            continue;
          }
          await _outbox.bumpAttempts(ids);
          _failed(error is ApiRejected ? error.retryAfter : null);
          return FlushOutcome.failed;
        }
      }
    } on Object catch (error) {
      // The database, or something unforeseen. Try again later.
      _log.warning('flush failed (${error.runtimeType})');
      _failed(null);
      return FlushOutcome.failed;
    }
  }

  void _succeeded() {
    _consecutiveFailures = 0;
    _notBefore = null;
  }

  void _failed(Duration? retryAfter) {
    _consecutiveFailures++;
    final doubled =
        baseBackoff * math.pow(2, math.min(_consecutiveFailures - 1, 16));
    var wait = doubled > maxBackoff ? maxBackoff : doubled;
    if (retryAfter != null && retryAfter > wait) {
      wait = retryAfter;
    }
    _notBefore = _now().add(wait);
  }

  static AnalyticsEvent _eventOf(OutboxEvent row) {
    Map<String, Object?>? props;
    try {
      final decoded = jsonDecode(row.propsJson);
      if (decoded is Map<String, Object?> && decoded.isNotEmpty) {
        props = decoded;
      }
    } on FormatException {
      // Written by this app, so not expected; the event still counts.
    }
    return AnalyticsEvent(
      name: row.name,
      occurredAt: row.occurredAt.toUtc(),
      props: props,
    );
  }
}
