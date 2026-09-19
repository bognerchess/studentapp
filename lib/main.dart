// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/app.dart';
import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/crash/crash_reporter.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/features/about/domain/additional_licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _log = Log('main');

void main() {
  // One container for the whole process, created before the first frame so
  // that errors during start-up already reach the crash reporter.
  final container = ProviderContainer();
  final crash = container.read(crashReporterProvider);

  void report(Object error, StackTrace? stack, String reason, bool fatal) {
    _log.error('uncaught ($reason)', error: error, stackTrace: stack);
    crash.recordError(error, stack, fatal: fatal, reason: reason);
  }

  runZonedGuarded(
    () {
      // Binding and runApp must share this zone.
      WidgetsFlutterBinding.ensureInitialized();

      // Errors thrown while building, laying out or painting.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        report(details.exception, details.stack, 'flutter', false);
      };
      // Errors from platform callbacks outside any Dart zone.
      PlatformDispatcher.instance.onError = (error, stack) {
        report(error, stack, 'platform', true);
        return true;
      };

      // Reads the dart-defines; throws on a release build with fake auth or
      // a plain-http API rather than letting such a build start.
      final env = container.read(envProvider);
      _log.info('starting env=${env.envName} auth=${env.authMode.name}');

      // Artwork and vendored source that Flutter's licence collector cannot
      // see (About -> Open-source licences).
      registerAdditionalLicenses();

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const BognerChessApp(),
        ),
      );
    },
    // Everything asynchronous that nobody caught.
    (error, stack) => report(error, stack, 'zone', true),
  );
}
