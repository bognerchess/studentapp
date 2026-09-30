// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whoever follows a running analysis implements this, so that a push makes
/// the result appear without waiting for the next poll.
///
/// Push calls [refreshNow] when an "analysis ready" notification arrives
/// while the app is in the foreground, and when the user taps one. The call
/// is a hint: it may come twice for one analysis, for a game that is not on
/// screen, or for one that finished long ago, and it must not throw.
///
/// An implementation calls `WorkflowTracker.refreshNow()` — that is the one
/// poller of the staged pipeline, and it needs neither of the two ids: it
/// polls the games it is watching. The ids are the notification's, so they are
/// input from outside and are not to be trusted as keys.
// ignore: one_member_abstracts
abstract interface class AnalysisReadyListener {
  /// [gameId] and [jobId] are what the notification named; both are input
  /// from outside and may be unknown to the app. `jobId` is the backend's
  /// whole-game job, which only the web client starts; the staged pipeline has
  /// no push of its own yet (a gap recorded in WP-60).
  void refreshNow({String? gameId, String? jobId});
}

class NoopAnalysisReadyListener implements AnalysisReadyListener {
  const NoopAnalysisReadyListener();

  @override
  void refreshNow({String? gameId, String? jobId}) {}
}

/// Never overridden so far, so a push refreshes nothing: the tracker polls
/// while the app is in the foreground, and a completion that happened in the
/// background is picked up on the next open. An override belongs in `app.dart`
/// and is one line — `ref.read(workflowTrackerProvider).refreshNow()`. Read by
/// `PushService` at the moment of the push, never cached.
final analysisReadyListenerProvider = Provider<AnalysisReadyListener>(
  (ref) => const NoopAnalysisReadyListener(),
);
