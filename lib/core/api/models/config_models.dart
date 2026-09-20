// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/foundation.dart';

/// Remote configuration of the app.
@immutable
class MobileConfig {
  const MobileConfig({
    required this.minSupportedAppVersion,
    required this.maxAnalysisSchemaVersion,
    required this.supportedCoachLanguages,
    required this.jobPollInterval,
    required this.featureFlags,
    required this.currentAiConsentVersion,
  });

  /// Older app versions must ask the user to update ("1.2.0").
  final String minSupportedAppVersion;

  /// The highest analysis document major version the backend serves.
  final int maxAnalysisSchemaVersion;

  /// Lower-case language codes the coach can write in.
  final List<String> supportedCoachLanguages;

  /// The initial interval of the foreground job poller.
  final Duration jobPollInterval;

  final Map<String, bool> featureFlags;

  /// The AI consent version to present; 0 when none is published.
  final int currentAiConsentVersion;

  /// False for a flag the server does not know.
  bool isEnabled(String flag) => featureFlags[flag] ?? false;

  /// The coach language for [languageCode]: itself when supported, else
  /// English.
  String coachLanguageFor(String languageCode) {
    final code = languageCode.toLowerCase();
    return supportedCoachLanguages.contains(code) ? code : 'en';
  }
}
