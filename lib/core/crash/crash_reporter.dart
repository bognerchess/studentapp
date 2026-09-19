// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the app needs from a crash reporting service.
///
/// The shell ships [NoopCrashReporter]. WP-34 adds a Sentry implementation
/// that is gated on the user's consent and sends no personal data; it
/// replaces the value of [crashReporterProvider], nothing else changes.
abstract interface class CrashReporter {
  /// Reports an error. [fatal] marks errors that ended the current frame or
  /// zone; [reason] says where it was caught ("flutter", "platform", "zone").
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
    String? reason,
  });

  /// Leaves a trail entry that is attached to the next report. Must not
  /// contain user content.
  void addBreadcrumb(String message, {String? category});
}

/// Drops everything.
class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
    String? reason,
  }) {}

  @override
  void addBreadcrumb(String message, {String? category}) {}
}

final crashReporterProvider = Provider<CrashReporter>(
  (ref) => const NoopCrashReporter(),
);
