// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/crash/sentry_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// The privacy promises of docs/privacy.md, held against the options the app
/// really sets.
void main() {
  const config = SentryAppConfig(
    dsn: 'https://public@sentry.example.test/1',
    environment: 'staging',
    version: '1.2.3',
    buildNumber: '45',
  );

  SentryFlutterOptions configured() {
    final options = SentryFlutterOptions();
    configureSentryOptions(options, config);
    return options;
  }

  test('identity of the build', () {
    final options = configured();
    expect(options.dsn, config.dsn);
    expect(options.environment, 'staging');
    expect(options.release, 'bogner-chess-ios@1.2.3+45');
    expect(options.dist, '45');
  });

  test('a release without version information is null, not a wrong one', () {
    const unknown = SentryAppConfig(
      dsn: 'x',
      environment: 'dev',
      version: null,
      buildNumber: null,
    );
    expect(unknown.release, isNull);
  });

  test('no personal data, no screenshots, no view hierarchy, no replay', () {
    final options = configured();
    expect(options.sendDefaultPii, isFalse);
    expect(options.attachScreenshot, isFalse);
    // Read-only use of an experimental member: this is the pin the config
    // refers to.
    // ignore: experimental_member_use
    expect(options.attachViewHierarchy, isFalse);
    expect(options.replay.sessionSampleRate, 0);
    expect(options.replay.onErrorSampleRate, 0);
    expect(options.enableUserInteractionBreadcrumbs, isFalse);
    expect(options.enableUserInteractionTracing, isFalse);
    expect(options.enablePrintBreadcrumbs, isFalse);
    expect(options.recordHttpBreadcrumbs, isFalse);
    expect(options.captureFailedRequests, isFalse);
    expect(options.maxRequestBodySize, MaxRequestBodySize.never);
    expect(options.enableAutoNativeBreadcrumbs, isFalse);
    expect(options.enableAutoSessionTracking, isFalse);
    expect(options.enableLogs, isFalse);
  });

  test('no performance tracing', () {
    final options = configured();
    expect(options.tracesSampleRate, isNull);
    expect(options.tracesSampler, isNull);
    expect(options.isTracingEnabled(), isFalse);
    expect(options.enableAutoPerformanceTracing, isFalse);
  });

  test('native crash handling is on', () {
    final options = configured();
    expect(options.enableNativeCrashHandling, isTrue);
    expect(options.enableWatchdogTerminationTracking, isTrue);
    expect(options.beforeSend, isNotNull);
    expect(options.beforeBreadcrumb, isNotNull);
  });

  group('beforeSend', () {
    test('removes user, request and server name', () {
      final event = SentryEvent(
        user: SentryUser(id: 'sub-1', email: 'hans@example.test'),
        request: SentryRequest(url: 'https://api.example.test/graphql'),
        serverName: 'the iPhone of Hans',
      );
      final scrubbed = scrubSentryEvent(event, Hint())!;
      expect(scrubbed.user, isNull);
      expect(scrubbed.request, isNull);
      expect(scrubbed.serverName, isNull);
    });

    test('scrubs exception values and the message, keeps the type', () {
      final event = SentryEvent(
        message: SentryMessage('import failed for [White "Hans Muster"]'),
        exceptions: [
          SentryException(
            type: 'FormatException',
            value:
                'Unexpected character in "1. e4 e5 2. Nf3" by hans@example.ch',
          ),
        ],
      );
      final scrubbed = scrubSentryEvent(event, Hint())!;
      final exception = scrubbed.exceptions!.single;
      expect(exception.type, 'FormatException');
      expect(exception.value, isNot(contains('e4')));
      expect(exception.value, isNot(contains('hans@')));
      expect(scrubbed.message!.formatted, isNot(contains('Hans')));
    });

    test('scrubs the breadcrumbs that travel with the event', () {
      final event = SentryEvent(
        breadcrumbs: [
          Breadcrumb(message: 'opened /games/abc-123/review'),
          Breadcrumb(category: 'ui.click', message: 'Submit'),
          Breadcrumb(
            category: 'http',
            data: {'url': 'https://api.example.test/graphql?token=abc'},
          ),
        ],
      );
      final scrubbed = scrubSentryEvent(event, Hint())!;
      expect(scrubbed.breadcrumbs, hasLength(1));
      expect(scrubbed.breadcrumbs!.single.message, 'opened /games/:id/review');
    });
  });

  group('beforeBreadcrumb', () {
    test('drops taps, prints and requests', () {
      for (final category in ['ui.click', 'ui.input', 'console', 'http']) {
        expect(
          scrubSentryBreadcrumb(Breadcrumb(category: category), Hint()),
          isNull,
          reason: category,
        );
      }
      expect(scrubSentryBreadcrumb(null, Hint()), isNull);
    });

    test('keeps the app life cycle', () {
      final crumb = scrubSentryBreadcrumb(
        Breadcrumb(category: 'app.lifecycle', data: {'state': 'paused'}),
        Hint(),
      )!;
      expect(crumb.data, {'state': 'paused'});
    });

    test('removes data keys that are not on the allow-list', () {
      final crumb = scrubSentryBreadcrumb(
        Breadcrumb(
          category: 'navigation',
          message: 'moves: 1. e4 e5 2. Nf3',
          data: {
            'from': '/games/abc',
            'to': '/games/abc/review',
            'arguments': {'white': 'Hans Muster'},
            'status_code': 200,
            'reason': 'said "Hans Muster"',
          },
        ),
        Hint(),
      )!;
      expect(crumb.message, isNot(contains('e4')));
      expect(crumb.data, {'status_code': 200, 'reason': 'said "<redacted>"'});
    });
  });
}
