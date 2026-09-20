// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/crash/crash_reporter.dart';
import 'package:bogner_chess/core/crash/crash_scrubber.dart';
import 'package:bogner_chess/core/crash/sentry_config.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// The few calls this app makes to the Sentry SDK. An interface, so that the
/// gate in [ConsentGatedCrashReporter] can be tested without the SDK's
/// static state and without a platform channel.
abstract interface class SentryBackend {
  Future<void> init(SentryAppConfig config);
  Future<void> close();
  Future<void> captureException(
    Object error,
    StackTrace? stackTrace, {
    required bool fatal,
    String? reason,
  });
  Future<void> addBreadcrumb(String message, {String? category});
}

/// The real SDK.
class SentryFlutterBackend implements SentryBackend {
  const SentryFlutterBackend();

  @override
  Future<void> init(SentryAppConfig config) {
    // No appRunner: main.dart owns the zone and the error handlers and hands
    // errors to CrashReporter.recordError. The SDK's own FlutterError and
    // PlatformDispatcher integrations chain to the handlers that exist, so
    // nothing is lost and nothing is reported twice (the SDK deduplicates).
    return SentryFlutter.init(
      (options) => configureSentryOptions(options, config),
    );
  }

  @override
  Future<void> close() => Sentry.close();

  @override
  Future<void> captureException(
    Object error,
    StackTrace? stackTrace, {
    required bool fatal,
    String? reason,
  }) {
    return Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.level = fatal ? SentryLevel.fatal : SentryLevel.error;
        if (reason != null) {
          // "flutter", "platform" or "zone": where main.dart caught it.
          unawaited(scope.setTag('caught_by', reason));
        }
      },
    );
  }

  @override
  Future<void> addBreadcrumb(String message, {String? category}) {
    return Sentry.addBreadcrumb(
      Breadcrumb(message: message, category: category),
    );
  }
}

/// The [CrashReporter] of the running app.
///
/// Sentry is initialised only when there is a DSN **and** the user has
/// consented ([setConsent]). Before that, and after consent was withdrawn,
/// the SDK is not running at all: nothing is collected, cached or sent, and
/// the native crash handler is not installed. Withdrawing consent closes the
/// SDK at once.
///
/// Errors reported while the SDK is off are dropped, not kept: consent does
/// not work backwards. Breadcrumbs pass [scrubCrashText] here already, and a
/// second time in `beforeBreadcrumb`.
class ConsentGatedCrashReporter implements CrashReporter {
  ConsentGatedCrashReporter({required this._backend, required this._config});

  final SentryBackend _backend;

  /// Asked when the SDK is switched on, so that version and build number are
  /// known by then.
  final Future<SentryAppConfig> Function() _config;

  static const _log = Log('crash');

  bool _wanted = false;
  bool _running = false;

  /// Switching on and off happens one after the other.
  Future<void> _tail = Future<void>.value();

  /// Whether the SDK is initialised right now.
  @visibleForTesting
  bool get isRunning => _running;

  /// Completes when every switch requested so far has happened.
  @visibleForTesting
  Future<void> get idle => _tail;

  /// Tells the reporter whether the user consents. Safe to call repeatedly.
  void setConsent({required bool granted}) {
    _wanted = granted;
    _tail = _tail.then((_) => _apply());
  }

  Future<void> _apply() async {
    try {
      if (_wanted && !_running) {
        final config = await _config();
        if (config.dsn.isEmpty) {
          return;
        }
        await _backend.init(config);
        _running = true;
        _log.info('crash reporting on');
      } else if (!_wanted && _running) {
        _running = false;
        await _backend.close();
        _log.info('crash reporting off');
      }
    } on Object catch (error) {
      // A crash reporter that cannot start must not be a reason to crash.
      _log.warning('switching crash reporting failed (${error.runtimeType})');
    }
  }

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
    String? reason,
  }) {
    if (!_running) return;
    unawaited(
      _guard(
        () => _backend.captureException(
          error,
          stackTrace,
          fatal: fatal,
          reason: reason,
        ),
      ),
    );
  }

  @override
  void addBreadcrumb(String message, {String? category}) {
    if (!_running) return;
    unawaited(
      _guard(
        () =>
            _backend.addBreadcrumb(scrubCrashText(message), category: category),
      ),
    );
  }

  static Future<void> _guard(Future<void> Function() call) async {
    try {
      await call();
    } on Object {
      // Never from inside an error handler.
    }
  }
}
