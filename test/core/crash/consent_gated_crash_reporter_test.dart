// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/core/consent/consent_state.dart';
import 'package:bogner_chess/core/crash/crash_providers.dart';
import 'package:bogner_chess/core/crash/crash_reporter.dart';
import 'package:bogner_chess/core/crash/sentry_config.dart';
import 'package:bogner_chess/core/crash/sentry_crash_reporter.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../helpers/fixed_analytics_consent.dart';
import '../../helpers/pump_app.dart';

class FakeSentryBackend implements SentryBackend {
  final List<String> calls = [];
  SentryAppConfig? config;
  Object? initError;

  @override
  Future<void> init(SentryAppConfig config) async {
    if (initError != null) {
      // Deliberately anything: the reporter must survive it.
      // ignore: only_throw_errors
      throw initError!;
    }
    this.config = config;
    calls.add('init');
  }

  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<void> captureException(
    Object error,
    StackTrace? stackTrace, {
    required bool fatal,
    String? reason,
  }) async => calls.add('capture:$error:$fatal:$reason');

  @override
  Future<void> addBreadcrumb(String message, {String? category}) async =>
      calls.add('crumb:$message:$category');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const config = SentryAppConfig(
    dsn: 'https://public@sentry.example.test/1',
    environment: 'staging',
    version: '1.2.3',
    buildNumber: '45',
  );

  setUp(() => Log.sink = (_) {});
  tearDown(Log.resetSink);

  group('ConsentGatedCrashReporter', () {
    late FakeSentryBackend backend;
    late ConsentGatedCrashReporter reporter;

    setUp(() {
      backend = FakeSentryBackend();
      reporter = ConsentGatedCrashReporter(
        backend: backend,
        config: () async => config,
      );
    });

    test('before consent the SDK is not touched, errors are dropped', () async {
      reporter
        ..recordError(StateError('boom'), StackTrace.current)
        ..addBreadcrumb('something');
      await reporter.idle;
      expect(backend.calls, isEmpty);
      expect(reporter.isRunning, isFalse);
    });

    test('consent starts the SDK once, with the configuration', () async {
      reporter
        ..setConsent(granted: true)
        ..setConsent(granted: true);
      await reporter.idle;
      expect(backend.calls, ['init']);
      expect(backend.config, same(config));
      expect(reporter.isRunning, isTrue);
    });

    test('errors and scrubbed breadcrumbs reach the running SDK', () async {
      reporter.setConsent(granted: true);
      await reporter.idle;
      reporter
        ..addBreadcrumb('imported [White "Hans Muster"]', category: 'import')
        ..recordError('boom', null, fatal: true, reason: 'zone');
      await pumpEventQueue();
      expect(backend.calls, [
        'init',
        'crumb:imported [<pgn tag>]:import',
        'capture:boom:true:zone',
      ]);
    });

    test('withdrawing consent closes the SDK; later errors drop', () async {
      reporter.setConsent(granted: true);
      await reporter.idle;
      reporter.setConsent(granted: false);
      await reporter.idle;
      reporter.recordError('late', null);
      await pumpEventQueue();
      expect(backend.calls, ['init', 'close']);
      expect(reporter.isRunning, isFalse);
    });

    test('quick changes end in the last state', () async {
      reporter
        ..setConsent(granted: true)
        ..setConsent(granted: false)
        ..setConsent(granted: true);
      await reporter.idle;
      expect(reporter.isRunning, isTrue);
      expect(backend.calls.where((call) => call == 'init'), hasLength(1));
    });

    test('an empty DSN never starts the SDK', () async {
      final noDsn = ConsentGatedCrashReporter(
        backend: backend,
        config: () async => const SentryAppConfig(
          dsn: '',
          environment: 'dev',
          version: null,
          buildNumber: null,
        ),
      )..setConsent(granted: true);
      await noDsn.idle;
      expect(backend.calls, isEmpty);
    });

    test('an SDK that cannot start is survived', () async {
      backend.initError = StateError('no native side');
      reporter.setConsent(granted: true);
      await reporter.idle;
      expect(reporter.isRunning, isFalse);
      expect(() => reporter.recordError('x', null), returnsNormally);
    });
  });

  group('the provider', () {
    ProviderContainer containerWith({
      required String dsn,
      required FakeSentryBackend backend,
      String? storedConsent,
    }) {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final base = testEnv(envName: 'staging');
      final container = ProviderContainer(
        overrides: [
          analyticsConsentProvider.overrideWith(
            () => FixedAnalyticsConsent.fromStored(storedConsent),
          ),
          envProvider.overrideWithValue(
            Env(
              envName: base.envName,
              apiUrl: base.apiUrl,
              tenantSlug: base.tenantSlug,
              oidcIssuer: base.oidcIssuer,
              oidcClientId: base.oidcClientId,
              oidcRedirect: base.oidcRedirect,
              sentryDsn: dsn,
              authMode: base.authMode,
            ),
          ),
          appInfoProvider.overrideWith(
            (ref) async => const AppInfo(version: '1.2.3', buildNumber: '45'),
          ),
          sentryBackendProvider.overrideWithValue(backend),
          ...crashOverrides,
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('without a DSN it is the no-op reporter', () {
      final backend = FakeSentryBackend();
      final container = containerWith(dsn: '', backend: backend);
      expect(container.read(crashReporterProvider), isA<NoopCrashReporter>());
    });

    test('with a DSN and stored consent the SDK starts', () async {
      final backend = FakeSentryBackend();
      final container = containerWith(
        dsn: config.dsn,
        backend: backend,
        storedConsent: 'granted',
      );
      final reporter =
          container.read(crashReporterProvider) as ConsentGatedCrashReporter;
      await container.read(analyticsConsentProvider.notifier).loaded;
      await reporter.idle;

      expect(backend.calls, ['init']);
      expect(backend.config!.environment, 'staging');
      expect(backend.config!.release, 'bogner-chess-ios@1.2.3+45');
    });

    test('with a DSN but no decision the SDK stays off', () async {
      final backend = FakeSentryBackend();
      final container = containerWith(dsn: config.dsn, backend: backend);
      final reporter =
          container.read(crashReporterProvider) as ConsentGatedCrashReporter;
      await container.read(analyticsConsentProvider.notifier).loaded;
      await reporter.idle;
      expect(backend.calls, isEmpty);
    });

    test('the switch in the settings turns it on and off', () async {
      final backend = FakeSentryBackend();
      final container = containerWith(dsn: config.dsn, backend: backend);
      final reporter =
          container.read(crashReporterProvider) as ConsentGatedCrashReporter;
      final consent = container.read(analyticsConsentProvider.notifier);
      await consent.loaded;

      await consent.set(granted: true);
      await reporter.idle;
      expect(backend.calls, ['init']);

      await consent.set(granted: false);
      await reporter.idle;
      expect(backend.calls, ['init', 'close']);
    });
  });
}
