// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/analytics/analytics.dart';
import 'package:bogner_chess/core/analytics/analytics_lifecycle.dart';
import 'package:bogner_chess/core/analytics/event_flusher.dart';
import 'package:bogner_chess/core/analytics/outbox_analytics.dart';
import 'package:bogner_chess/core/analytics/session_tracker.dart';
import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/auth/sign_out_hooks.dart';
import 'package:bogner_chess/core/consent/consent_state.dart';
import 'package:bogner_chess/core/device/device_id.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// The signed-in subject, or null.
String? _subOf(AuthState state) => switch (state) {
  SignedIn(:final sub) => sub,
  SignedOut() => null,
};

final sessionTrackerProvider = Provider<SessionTracker>(
  (ref) => SessionTracker(now: DateTime.now),
);

final eventFlusherProvider = Provider<EventFlusher>((ref) {
  return EventFlusher(
    outbox: ref.watch(appDatabaseProvider).eventOutboxDao,
    api: ref.watch(eventsApiProvider),
    currentSub: () => _subOf(ref.read(authStateProvider)),
    consentGranted: () =>
        ref.read(analyticsConsentProvider) == AnalyticsConsent.granted,
    appVersion: () async {
      try {
        final info = await ref.read(appInfoProvider.future);
        return '${info.version}+${info.buildNumber}';
      } on Object {
        return null;
      }
    },
    now: DateTime.now,
  );
});

/// The consent-gated, outbox-backed [Analytics].
final outboxAnalyticsProvider = Provider<OutboxAnalytics>((ref) {
  return OutboxAnalytics(
    outbox: ref.watch(appDatabaseProvider).eventOutboxDao,
    deviceId: () => ref.read(deviceIdProvider.future),
    consent: () async {
      // After a start the stored decision has to be read first; without the
      // wait the cold `app_open` would always be dropped.
      await ref.read(analyticsConsentProvider.notifier).loaded;
      return ref.read(analyticsConsentProvider) == AnalyticsConsent.granted;
    },
    session: ref.watch(sessionTrackerProvider),
    ownerSub: () => _subOf(ref.read(authStateProvider)),
    now: DateTime.now,
  );
});

/// `main.dart` reads this once and calls `start()`.
final analyticsLifecycleProvider = Provider<AnalyticsLifecycle>((ref) {
  final lifecycle = AnalyticsLifecycle(
    analytics: ref.watch(analyticsProvider),
    flusher: ref.watch(eventFlusherProvider),
    session: ref.watch(sessionTrackerProvider),
    outbox: ref.watch(appDatabaseProvider).eventOutboxDao,
  );

  ref.listen(authStateProvider, (previous, next) {
    if (previous is SignedOut && next is SignedIn) {
      lifecycle.onSignedIn();
    }
  });
  ref.listen(analyticsConsentProvider, (previous, next) {
    if (next == AnalyticsConsent.denied) {
      unawaited(lifecycle.onConsentWithdrawn());
    }
  });
  // The last chance to send what this account recorded: a sign-out removes
  // its events from the outbox.
  final removeHook = ref
      .read(beforeSignOutHooksProvider)
      .add((_) => ref.read(eventFlusherProvider).flush(force: true));

  ref.onDispose(() {
    removeHook();
    lifecycle.dispose();
  });
  return lifecycle;
});

/// For the root `ProviderContainer` of the running app. Tests leave them out
/// and keep the no-op default, which opens no database.
final List<Override> analyticsOverrides = [
  analyticsProvider.overrideWith((ref) => ref.watch(outboxAnalyticsProvider)),
];
