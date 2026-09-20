// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/crash/crash_scrubber.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// What the app tells Sentry about itself.
@immutable
class SentryAppConfig {
  const SentryAppConfig({
    required this.dsn,
    required this.environment,
    required this.version,
    required this.buildNumber,
  });

  final String dsn;

  /// `Env.envName`: dev, staging, prod.
  final String environment;
  final String? version;
  final String? buildNumber;

  /// Set explicitly, because the SDK's default (`<bundle id>@…`) and the
  /// default of the symbol-upload plugin (`<pubspec name>@…`) differ, and a
  /// release that does not match gets no symbolicated stack traces.
  String? get release => version == null
      ? null
      : buildNumber == null
      ? '$kSentryReleasePrefix@$version'
      : '$kSentryReleasePrefix@$version+$buildNumber';
}

const String kSentryReleasePrefix = 'bogner-chess-ios';

/// Every Sentry option of this app, in one function, so that a test can hold
/// the privacy promises of `docs/privacy.md` against it.
///
/// Crash reports only: no performance tracing, no session replay, no
/// screenshots, no view hierarchy, no user, no sessions.
void configureSentryOptions(
  SentryFlutterOptions options,
  SentryAppConfig config,
) {
  options
    ..dsn = config.dsn
    ..environment = config.environment
    ..release = config.release
    ..dist = config.buildNumber
    // Privacy.
    ..sendDefaultPii = false
    ..attachScreenshot = false
    // attachViewHierarchy stays at its default, false (the setter is marked
    // experimental; a test pins the value).
    ..reportViewHierarchyIdentifiers = false
    ..enableUserInteractionBreadcrumbs = false
    ..enableUserInteractionTracing = false
    ..enablePrintBreadcrumbs = false
    ..recordHttpBreadcrumbs = false
    ..captureFailedRequests = false
    ..maxRequestBodySize = MaxRequestBodySize.never
    ..enableAutoNativeBreadcrumbs = false
    ..enableAutoSessionTracking = false
    ..enableLogs = false
    ..enableMetrics = false
    ..reportPackages = false
    // No performance monitoring in the MVP. null is "off"; with 0 the SDK
    // would still build transactions and then discard them.
    ..tracesSampleRate = null
    ..enableAutoPerformanceTracing = false
    ..enableFramesTracking = false
    ..enableTimeToFullDisplayTracing = false
    ..propagateTraceparent = false
    // Crashes: Dart errors come through CrashReporter.recordError, native
    // ones (signals, Swift and Objective-C exceptions, watchdog
    // terminations, app hangs) through sentry-cocoa.
    ..enableNativeCrashHandling = true
    ..enableWatchdogTerminationTracking = true
    ..enableAppHangTracking = true
    ..enableAppLifecycleBreadcrumbs = true
    ..attachStacktrace = true
    ..beforeSend = scrubSentryEvent
    ..beforeBreadcrumb = scrubSentryBreadcrumb;
  options.replay
    ..sessionSampleRate = 0
    ..onErrorSampleRate = 0;
}

/// `beforeSend`: the last look at a Dart event before it leaves the device.
/// Removes the user and the request, and scrubs every text a developer did
/// not write (see [scrubCrashText]). Stack traces stay: they hold symbols of
/// the app, not content.
SentryEvent? scrubSentryEvent(SentryEvent event, Hint hint) {
  event
    ..user = null
    ..request = null
    ..serverName = null;
  final message = event.message;
  if (message != null) {
    event.message = SentryMessage(scrubCrashText(message.formatted));
  }
  for (final exception in event.exceptions ?? const <SentryException>[]) {
    final value = exception.value;
    if (value != null) {
      exception.value = scrubCrashText(value);
    }
  }
  event.breadcrumbs = [
    for (final breadcrumb in event.breadcrumbs ?? const <Breadcrumb>[])
      ?scrubSentryBreadcrumb(breadcrumb, hint),
  ];
  // ignore: deprecated_member_use
  event.extra = null;
  return event;
}

/// `beforeBreadcrumb`: drops whole categories, scrubs the message and keeps
/// only allow-listed data keys with scalar values.
Breadcrumb? scrubSentryBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
  if (breadcrumb == null) return null;
  final category = breadcrumb.category;
  if (category != null &&
      (kDroppedBreadcrumbCategories.contains(category) ||
          category.startsWith('ui.'))) {
    return null;
  }
  final message = breadcrumb.message;
  if (message != null) {
    breadcrumb.message = scrubCrashText(message);
  }
  final data = breadcrumb.data;
  if (data != null) {
    final kept = <String, dynamic>{
      for (final MapEntry(:key, :value) in data.entries)
        if (kAllowedBreadcrumbDataKeys.contains(key) &&
            (value is num || value is bool || value is String))
          key: value is String ? scrubCrashText(value) : value,
    };
    breadcrumb.data = kept.isEmpty ? null : kept;
  }
  return breadcrumb;
}
