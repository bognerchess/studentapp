// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whoever shows analysis jobs implements this, so that a push makes the
/// result appear without waiting for the next poll.
///
/// Push calls [refreshNow] when an "analysis ready" notification arrives
/// while the app is in the foreground, and when the user taps one. The call
/// is a hint: it may come twice for one job, for a game that is not on
/// screen, or for a job that finished long ago, and it must not throw.
// ignore: one_member_abstracts
abstract interface class AnalysisReadyListener {
  /// [gameId] and [jobId] are what the notification named; both are input
  /// from outside and may be unknown to the app.
  void refreshNow({String? gameId, String? jobId});
}

class NoopAnalysisReadyListener implements AnalysisReadyListener {
  const NoopAnalysisReadyListener();

  @override
  void refreshNow({String? gameId, String? jobId}) {}
}

/// Overridden where the job tracker lives (the coordinator connects it to
/// `jobTrackerProvider`). Read by `PushService` at the moment of the push,
/// never cached.
final analysisReadyListenerProvider = Provider<AnalysisReadyListener>(
  (ref) => const NoopAnalysisReadyListener(),
);
