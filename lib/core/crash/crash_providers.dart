// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/core/consent/consent_state.dart';
import 'package:bogner_chess/core/crash/crash_reporter.dart';
import 'package:bogner_chess/core/crash/sentry_config.dart';
import 'package:bogner_chess/core/crash/sentry_crash_reporter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// Tests replace the SDK with a fake.
final sentryBackendProvider = Provider<SentryBackend>(
  (ref) => const SentryFlutterBackend(),
);

/// Sentry behind the [CrashReporter] interface, following the analytics
/// consent: one switch in the settings covers product analytics and crash
/// reports. Without a `SENTRY_DSN` in the configuration this is the no-op
/// reporter and the SDK is never touched.
final consentGatedCrashReporterProvider = Provider<CrashReporter>((ref) {
  final env = ref.watch(envProvider);
  if (env.sentryDsn.isEmpty) {
    return const NoopCrashReporter();
  }
  final reporter = ConsentGatedCrashReporter(
    backend: ref.watch(sentryBackendProvider),
    config: () async {
      AppInfo? info;
      try {
        info = await ref.read(appInfoProvider.future);
      } on Object {
        // Reports without a release are still reports.
      }
      return SentryAppConfig(
        dsn: env.sentryDsn,
        environment: env.envName,
        version: info?.version,
        buildNumber: info?.buildNumber,
      );
    },
  );
  ref.listen(analyticsConsentProvider, (_, next) {
    reporter.setConsent(granted: next == AnalyticsConsent.granted);
  }, fireImmediately: true);
  ref.onDispose(() => reporter.setConsent(granted: false));
  return reporter;
});

/// For the root `ProviderContainer` of the running app (`main.dart`).
final List<Override> crashOverrides = [
  crashReporterProvider.overrideWith(
    (ref) => ref.watch(consentGatedCrashReporterProvider),
  ),
];
