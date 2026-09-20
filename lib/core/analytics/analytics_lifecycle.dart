// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/analytics/analytics.dart';
import 'package:bogner_chess/core/analytics/event_flusher.dart';
import 'package:bogner_chess/core/analytics/session_tracker.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:flutter/widgets.dart';

/// The parts of analytics that follow the life of the app rather than a
/// feature:
///
/// * `app_open` once per session: at the start of the process (`start:
///   cold`) and when the app returns after 30 minutes or more (`start: warm`).
/// * `sign_in` when the auth state goes from signed out to signed in. A
///   restored session at start is not a sign-in.
/// * When the outbox is sent: on pause, on resume, after a sign-in, and every
///   [interval] in the foreground while something waits. There is no
///   connectivity listener; after a failure the flusher backs off and one of
///   these moments tries again.
/// * Consent withdrawn: the outbox is emptied at once.
class AnalyticsLifecycle {
  AnalyticsLifecycle({
    required this._analytics,
    required this._flusher,
    required this._session,
    required this._outbox,
    this.interval = const Duration(seconds: 60),
  });

  final Analytics _analytics;
  final EventFlusher _flusher;
  final SessionTracker _session;
  final EventOutboxDao _outbox;
  final Duration interval;

  AppLifecycleListener? _listener;
  Timer? _timer;

  /// Call once, after the binding exists. Records the cold `app_open`.
  void start() {
    if (_listener != null) return;
    _listener = AppLifecycleListener(onPause: onPaused, onResume: onResumed);
    _startTimer();
    _analytics.track(AnalyticsEvents.appOpen, const {'start': 'cold'});
    unawaited(_flusher.flush());
  }

  void dispose() {
    _listener?.dispose();
    _listener = null;
    _timer?.cancel();
    _timer = null;
  }

  void onPaused() {
    _session.onBackgrounded();
    _timer?.cancel();
    _timer = null;
    unawaited(_flusher.flush());
  }

  void onResumed() {
    if (_session.onForegrounded()) {
      _analytics.track(AnalyticsEvents.appOpen, const {'start': 'warm'});
    }
    _startTimer();
    unawaited(_flusher.flush());
  }

  void onSignedIn() {
    _analytics.track(AnalyticsEvents.signIn);
    unawaited(_flusher.flush());
  }

  /// Consent withdrawn: nothing recorded before may still be sent.
  Future<void> onConsentWithdrawn() async {
    try {
      await _outbox.clear();
    } on Object {
      // The flusher sends nothing without consent either way.
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(interval, (_) => unawaited(_tick()));
  }

  Future<void> _tick() async {
    try {
      if (await _outbox.count() > 0) {
        await _flusher.flush();
      }
    } on Object {
      // The next tick tries again.
    }
  }
}
