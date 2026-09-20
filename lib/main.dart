// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/app.dart';
import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/analytics/analytics_providers.dart';
import 'package:bogner_chess/core/auth/auth_providers.dart';
import 'package:bogner_chess/core/crash/crash_providers.dart';
import 'package:bogner_chess/core/crash/crash_reporter.dart';
import 'package:bogner_chess/core/links/incoming_link_service.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/push/push_service.dart';
import 'package:bogner_chess/features/about/domain/additional_licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _log = Log('main');

void main() {
  // One container for the whole process, created before the first frame so
  // that errors during start-up already reach the crash reporter.
  // The running app records analytics and crashes (both only with consent);
  // tests build their own scope and keep the no-op defaults.
  final container = ProviderContainer(
    overrides: [...analyticsOverrides, ...crashOverrides],
  );

  void report(Object error, StackTrace? stack, String reason, bool fatal) {
    _log.error('uncaught ($reason)', error: error, stackTrace: stack);
    try {
      // Read here, not once at the top: the reporter reads the stored consent
      // when it is created, which needs the binding.
      container
          .read(crashReporterProvider)
          .recordError(error, stack, fatal: fatal, reason: reason);
    } on Object {
      // An error handler must not throw.
    }
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

      // Creates the crash reporter: from here on it follows the consent.
      container.read(crashReporterProvider);

      // Artwork and vendored source that Flutter's licence collector cannot
      // see (About -> Open-source licences).
      registerAdditionalLicenses();

      // The router needs to know who is signed in before its first redirect.
      // restore() reads the Keychain and makes no network request; it never
      // throws. Still inside the guarded zone, as runApp has to be.
      Future<void> start() async {
        await container.read(authRepositoryProvider).restore();

        // Links and documents from outside the app ("Open in Bogner Chess").
        // What arrived before this line, on a cold start, is delivered first.
        container.read(incomingLinkServiceProvider).start();

        // Push: a tap that started the app is delivered first, like a link.
        // Registers the device for a signed-in user; asks for nothing (the
        // permission prompt has its own moment, see PushService).
        container.read(pushServiceProvider).start();

        // app_open, sign_in, and when the event outbox is sent.
        container.read(analyticsLifecycleProvider).start();

        runApp(
          UncontrolledProviderScope(
            container: container,
            child: const BognerChessApp(),
          ),
        );
      }

      unawaited(start());
    },
    // Everything asynchronous that nobody caught.
    (error, stack) => report(error, stack, 'zone', true),
  );
}
