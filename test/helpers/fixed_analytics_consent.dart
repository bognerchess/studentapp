// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/consent/consent_state.dart';

/// An [AnalyticsConsentNotifier] with a fixed answer, for tests of the
/// consumers of the consent (analytics, crash reporting). It reads no storage
/// and asks no server; [set] only changes the in-memory answer.
class FixedAnalyticsConsent extends AnalyticsConsentNotifier {
  FixedAnalyticsConsent(this._answer);

  /// From the stored form the consumers' tests use: 'granted', 'denied' or
  /// null for "not answered yet".
  factory FixedAnalyticsConsent.fromStored(String? stored) =>
      FixedAnalyticsConsent(switch (stored) {
        'granted' => AnalyticsConsent.granted,
        'denied' => AnalyticsConsent.denied,
        _ => AnalyticsConsent.unknown,
      });

  final AnalyticsConsent _answer;

  @override
  AnalyticsConsent build() => _answer;

  @override
  Future<void> get loaded => Future<void>.value();

  @override
  Future<void> set({required bool granted, int? shownVersion}) async {
    state = granted ? AnalyticsConsent.granted : AnalyticsConsent.denied;
  }
}
