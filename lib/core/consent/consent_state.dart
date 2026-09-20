// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/storage/preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Preferences key of the analytics decision: `granted` or `denied`.
const String kAnalyticsConsentKey = 'analytics_consent';

/// What the user said about product analytics and crash reports. Nothing is
/// recorded or sent unless this is [granted]; [unknown] (no decision yet)
/// counts as "no".
enum AnalyticsConsent { unknown, granted, denied }

/// The decision, kept in the preferences of this installation.
///
/// The state is [AnalyticsConsent.unknown] until the stored value has been
/// read; [loaded] completes then. Who must not lose the first event of a
/// start (`app_open`) waits for it.
class AnalyticsConsentNotifier extends Notifier<AnalyticsConsent> {
  final Completer<void> _loaded = Completer<void>();
  bool _decidedSinceStart = false;

  /// Completes once the stored decision is the state. Never fails.
  Future<void> get loaded => _loaded.future;

  @override
  AnalyticsConsent build() {
    unawaited(_load());
    return AnalyticsConsent.unknown;
  }

  Future<void> _load() async {
    try {
      final stored = await ref
          .read(preferencesProvider)
          .getString(kAnalyticsConsentKey);
      // A decision taken while the read was in flight wins.
      if (!_decidedSinceStart && ref.mounted) {
        state = switch (stored) {
          'granted' => AnalyticsConsent.granted,
          'denied' => AnalyticsConsent.denied,
          _ => AnalyticsConsent.unknown,
        };
      }
    } on Object {
      // Unreadable preferences: stay at "unknown", which records nothing.
    } finally {
      if (!_loaded.isCompleted) {
        _loaded.complete();
      }
    }
  }

  /// Records the user's decision.
  Future<void> set({required bool granted}) async {
    _decidedSinceStart = true;
    state = granted ? AnalyticsConsent.granted : AnalyticsConsent.denied;
    await ref
        .read(preferencesProvider)
        .setString(kAnalyticsConsentKey, granted ? 'granted' : 'denied');
  }
}

final analyticsConsentProvider =
    NotifierProvider<AnalyticsConsentNotifier, AnalyticsConsent>(
      AnalyticsConsentNotifier.new,
    );
