// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/api/config_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The remote configuration, loaded once per process and kept. Everything
/// that reads it has a built-in default for the time before it arrives and
/// for a device that is offline; invalidate it to ask again.
final mobileConfigProvider = FutureProvider<MobileConfig>(
  (ref) => ref.watch(configApiProvider).mobileConfig(),
  // No automatic retry: the job tracker asks again on the next resume.
  retry: (_, _) => null,
);

/// The language the coach should write in: the device language when the
/// server supports it, else English. Before the configuration is known,
/// German and English count as supported.
String coachLanguageOf(MobileConfig? config, String languageCode) {
  final code = languageCode.toLowerCase();
  if (config != null) {
    return config.coachLanguageFor(code);
  }
  return const {'en', 'de'}.contains(code) ? code : 'en';
}
