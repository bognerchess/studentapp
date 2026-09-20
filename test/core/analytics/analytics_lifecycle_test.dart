// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/analytics/analytics.dart';
import 'package:bogner_chess/core/analytics/analytics_providers.dart';
import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/auth/sign_out_hooks.dart';
import 'package:bogner_chess/core/consent/consent_state.dart';
import 'package:bogner_chess/core/device/device_id.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../helpers/fixed_analytics_consent.dart';
import '../../helpers/fixture_link.dart';
import '../../helpers/pump_app.dart';
import '../storage/test_database.dart';

/// The providers of `analytics_providers.dart` wired as in `main.dart`, on an
/// in-memory database, in-memory preferences and a [FixtureLink].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FixtureLink api;
  late ProviderContainer container;
  late TestAuthNotifier auth;

  Future<void> boot({
    String? storedConsent = 'granted',
    AuthState initialAuth = const SignedIn(alice),
  }) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    auth = TestAuthNotifier(initialAuth);
    container = ProviderContainer(
      overrides: [
        analyticsConsentProvider.overrideWith(
          () => FixedAnalyticsConsent.fromStored(storedConsent),
        ),
        envProvider.overrideWithValue(testEnv()),
        appInfoProvider.overrideWith(
          (ref) async => const AppInfo(version: '1.2.3', buildNumber: '45'),
        ),
        appDatabaseProvider.overrideWithValue(db),
        authStateProvider.overrideWith(() => auth),
        deviceIdProvider.overrideWith((ref) async => 'device-1'),
        ...api.overrides,
        ...analyticsOverrides,
      ],
    );
    container.read(analyticsLifecycleProvider).start();
    await settle();
  }

  setUp(() {
    Log.sink = (_) {};
    db = openTestDatabase(FakeClock());
    api = FixtureLink();
  });

  tearDown(() async {
    Log.resetSink();
    container.dispose();
    await db.close();
  });

  List<String> sentNames() => [
    for (final request in api.requestsOf('TrackMobileEvents'))
      for (final event in (request.variables['input'] as Map)['events'] as List)
        (event as Map)['name'] as String,
  ];

  test('the override installs the outbox implementation', () async {
    await boot();
    expect(
      container.read(analyticsProvider),
      same(container.read(outboxAnalyticsProvider)),
    );
  });

  test('a cold start with stored consent records and sends app_open', () async {
    await boot();
    container.read(analyticsLifecycleProvider).onPaused();
    await settle();

    expect(sentNames(), ['app_open']);
    final props =
        ((api.requestsOf('TrackMobileEvents').single.variables['input']
                        as Map)['events']
                    as List)
                .single
            as Map;
    expect(props['props'], {'start': 'cold'});
  });

  test('without a decision nothing is recorded', () async {
    await boot(storedConsent: null);
    container.read(analyticsProvider).track(AnalyticsEvents.reviewOpened);
    await settle();
    expect(await db.eventOutboxDao.count(), 0);
    expect(api.requests, isEmpty);
  });

  test(
    'sign_in is recorded on the transition, not for a restored session',
    () async {
      await boot(initialAuth: const SignedOut());
      expect(await db.eventOutboxDao.count(), 1); // app_open, waiting
      expect(api.requests, isEmpty);

      auth.set(const SignedIn(alice));
      await settle();
      expect(sentNames(), ['app_open', 'sign_in']);
    },
  );

  test('withdrawing consent empties the outbox', () async {
    await boot(initialAuth: const SignedOut());
    expect(await db.eventOutboxDao.count(), 1);

    await container.read(analyticsConsentProvider.notifier).set(granted: false);
    await settle();
    expect(await db.eventOutboxDao.count(), 0);
  });

  test('the outbox is sent before a sign-out', () async {
    await boot();
    container.read(analyticsProvider).track(AnalyticsEvents.accountDeleted);
    await container.read(outboxAnalyticsProvider).idle;
    final before = api.requestsOf('TrackMobileEvents').length;

    await container.read(beforeSignOutHooksProvider).run(alice);
    expect(api.requestsOf('TrackMobileEvents').length, before + 1);
    expect(sentNames(), contains('account_deleted'));
  });

  test('a warm app_open only after half an hour away', () async {
    await boot();
    final lifecycle = container.read(analyticsLifecycleProvider)
      ..onPaused()
      ..onResumed();
    await settle();
    expect(sentNames(), ['app_open']);
    lifecycle.dispose();
  });
}

/// Lets the chained futures of track → enqueue → flush run. Real time,
/// because drift's in-memory database answers asynchronously.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 60));
