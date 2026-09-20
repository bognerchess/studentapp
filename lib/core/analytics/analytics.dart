// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Names of the product events the backend accepts (`trackMobileEvents`
/// drops anything else). Keep in sync with `docs/analytics-events.md`.
abstract final class AnalyticsEvents {
  static const appOpen = 'app_open';
  static const signIn = 'sign_in';
  static const gameEntryStarted = 'game_entry_started';
  static const gameEntryCompleted = 'game_entry_completed';
  static const pgnImported = 'pgn_imported';
  static const gameSubmitted = 'game_submitted';
  static const analysisRequested = 'analysis_requested';
  static const analysisLimitHit = 'analysis_limit_hit';
  static const analysisReadyOpened = 'analysis_ready_opened';
  static const reviewOpened = 'review_opened';
  static const commentFeedback = 'comment_feedback';
  static const pushPermissionResult = 'push_permission_result';
  static const consentAiAccepted = 'consent_ai_accepted';
  static const consentAnalyticsChanged = 'consent_analytics_changed';
  static const accountDeleted = 'account_deleted';

  /// Every name above. An event with another name is dropped on the device
  /// already; the server would drop it too.
  static const Set<String> all = {
    appOpen,
    signIn,
    gameEntryStarted,
    gameEntryCompleted,
    pgnImported,
    gameSubmitted,
    analysisRequested,
    analysisLimitHit,
    analysisReadyOpened,
    reviewOpened,
    commentFeedback,
    pushPermissionResult,
    consentAiAccepted,
    consentAnalyticsChanged,
    accountDeleted,
  };
}

/// Fire-and-forget product analytics. Features call [track]; whether anything
/// is recorded (consent) and how it is delivered (outbox, batching) is the
/// implementation's business. Properties must never contain names, e-mail
/// addresses, moves or free text: counts, durations, enum-like strings only.
abstract class Analytics {
  void track(String name, [Map<String, Object?> props = const {}]);
}

class NoopAnalytics implements Analytics {
  const NoopAnalytics();

  @override
  void track(String name, [Map<String, Object?> props = const {}]) {}
}

/// A no-op unless overridden: `main.dart` installs the consent-gated,
/// outbox-backed implementation (`analyticsOverrides` in
/// `analytics_providers.dart`), so that widget tests record nothing and open
/// no database.
final analyticsProvider = Provider<Analytics>((ref) => const NoopAnalytics());
