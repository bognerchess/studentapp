// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:io';

import 'package:bogner_chess/core/analytics/analytics.dart';
import 'package:bogner_chess/core/api/legal_api.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/consent/consent_state.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/account_harness.dart';
import '../../helpers/fixture_link.dart';
import '../../helpers/pump_app.dart' show TestAuthNotifier;
import '../storage/test_database.dart';

const _user = SignedIn('sub-1', email: 'a@example.test');

void main() {
  late AppDatabase db;
  late FixtureLink api;
  late RecordingAnalytics analytics;

  setUp(() {
    db = openTestDatabase(FakeClock());
    api = FixtureLink({'MyConsent': 'required'});
    analytics = RecordingAnalytics();
  });
  tearDown(() => db.close());

  /// A fresh "app start" on the same database and server.
  ProviderContainer start({AuthState auth = _user, bool storage = true}) {
    final container = ProviderContainer(
      overrides: [
        ...api.overrides,
        if (storage)
          appDatabaseProvider.overrideWithValue(db)
        else
          appDatabaseProvider.overrideWith(
            (ref) => throw StateError('no storage on this platform'),
          ),
        analyticsProvider.overrideWithValue(analytics),
        authStateProvider.overrideWith(() => TestAuthNotifier(auth)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<AnalyticsConsentNotifier> loaded(ProviderContainer container) async {
    container.listen(analyticsConsentProvider, (_, _) {});
    final notifier = container.read(analyticsConsentProvider.notifier);
    await notifier.loaded;
    return notifier;
  }

  Map<String, dynamic> inputOf(FixtureRequest request) =>
      request.variables['input'] as Map<String, dynamic>;

  group('analyticsConsentProvider', () {
    test('is off by default and asks once', () async {
      final container = start();
      final notifier = await loaded(container);

      expect(
        container.read(analyticsConsentProvider),
        AnalyticsConsent.unknown,
      );
      expect(await notifier.takeFirstRunPrompt(), isTrue);
      expect(await notifier.takeFirstRunPrompt(), isFalse);
      expect(api.requestsOf('RecordConsent'), isEmpty);

      // The next start does not ask again, and it is still off.
      final next = start();
      final again = await loaded(next);
      expect(await again.takeFirstRunPrompt(), isFalse);
      expect(next.read(analyticsConsentProvider), AnalyticsConsent.unknown);
    });

    test(
      'granting is stored, recorded with the version, and tracked',
      () async {
        final container = start();
        final notifier = await loaded(container);

        await notifier.set(granted: true, shownVersion: 1);

        expect(
          container.read(analyticsConsentProvider),
          AnalyticsConsent.granted,
        );
        expect(inputOf(api.requestsOf('RecordConsent').single), {
          'key': 'ANALYTICS_CONSENT',
          'version': 1,
          'accepted': true,
        });
        expect(analytics.events.single.name, 'consent_analytics_changed');
        expect(analytics.events.single.props, {'granted': true});

        // Persisted: the next start knows without asking anybody.
        api.requests.clear();
        final next = start();
        final again = await loaded(next);
        expect(next.read(analyticsConsentProvider), AnalyticsConsent.granted);
        expect(api.requests, isEmpty);
        expect(await again.takeFirstRunPrompt(), isFalse);
      },
    );

    test('refusing is stored and recorded as not accepted', () async {
      final container = start();
      final notifier = await loaded(container);

      await notifier.set(granted: false);

      expect(container.read(analyticsConsentProvider), AnalyticsConsent.denied);
      // Without a text on screen the current version is asked for.
      expect(inputOf(api.requestsOf('RecordConsent').single), {
        'key': 'ANALYTICS_CONSENT',
        'version': 1,
        'accepted': false,
      });
      expect(await notifier.takeFirstRunPrompt(), isFalse);
    });

    test('an answer given offline is recorded on the next start', () async {
      api.fail('RecordConsent', const SocketException('offline'));
      final container = start();
      final notifier = await loaded(container);
      await notifier.set(granted: true, shownVersion: 1);
      expect(
        container.read(analyticsConsentProvider),
        AnalyticsConsent.granted,
      );
      expect(api.requestsOf('RecordConsent'), hasLength(1));

      api.use('RecordConsent', 'default');
      final next = start();
      await loaded(next);
      expect(next.read(analyticsConsentProvider), AnalyticsConsent.granted);
      expect(api.requestsOf('RecordConsent'), hasLength(2));
      expect(inputOf(api.requestsOf('RecordConsent').last)['accepted'], isTrue);

      // Sent: the start after that has nothing left to do.
      final third = start();
      await loaded(third);
      expect(api.requestsOf('RecordConsent'), hasLength(2));
    });

    test('a record the server rejects is not retried for ever', () async {
      api.use('RecordConsent', 'input_invalid');
      final container = start();
      final notifier = await loaded(container);
      await notifier.set(granted: true, shownVersion: 7);

      api.use('RecordConsent', 'default');
      await loaded(start());
      expect(api.requestsOf('RecordConsent'), hasLength(1));
    });

    test('takes over what the person said on another device', () async {
      api.use('MyConsent', 'default'); // accepted the current version
      final container = start();
      final notifier = await loaded(container);
      expect(
        container.read(analyticsConsentProvider),
        AnalyticsConsent.granted,
      );
      expect(await notifier.takeFirstRunPrompt(), isFalse);
      expect(api.requestsOf('RecordConsent'), isEmpty);

      api.use('MyConsent', 'withdrawn');
      final other = start(auth: const SignedIn('sub-2'));
      final otherNotifier = await loaded(other);
      expect(other.read(analyticsConsentProvider), AnalyticsConsent.denied);
      expect(await otherNotifier.takeFirstRunPrompt(), isFalse);
    });

    test(
      'belongs to the account: signed out is unknown, a wipe forgets',
      () async {
        final container = start();
        final notifier = await loaded(container);
        await notifier.set(granted: true, shownVersion: 1);

        (container.read(authStateProvider.notifier) as TestAuthNotifier).set(
          const SignedOut(),
        );
        expect(
          container.read(analyticsConsentProvider),
          AnalyticsConsent.unknown,
        );
        await container
            .read(analyticsConsentProvider.notifier)
            .set(granted: true);
        expect(
          container.read(analyticsConsentProvider),
          AnalyticsConsent.unknown,
        );

        // What a sign-out does to the database.
        await db.wipeOwner(_user.sub, keepDrafts: true);
        api.use('MyConsent', 'required');
        final next = start();
        await loaded(next);
        expect(next.read(analyticsConsentProvider), AnalyticsConsent.unknown);
      },
    );

    test('without storage it stays off and nobody is asked', () async {
      final container = start(storage: false);
      final notifier = await loaded(container);

      expect(
        container.read(analyticsConsentProvider),
        AnalyticsConsent.unknown,
      );
      expect(await notifier.takeFirstRunPrompt(), isFalse);
    });

    test('offline at the first start: off, and the question is due', () async {
      api.fail('MyConsent', const SocketException('offline'));
      final container = start();
      final notifier = await loaded(container);
      expect(
        container.read(analyticsConsentProvider),
        AnalyticsConsent.unknown,
      );
      expect(await notifier.takeFirstRunPrompt(), isTrue);
    });
  });

  group('aiConsentStatusProvider', () {
    test('required until the current version is accepted', () async {
      api.use('MyAiConsent', 'required');
      final container = start();
      final status = await container.read(aiConsentStatusProvider.future);
      expect(status.required, isTrue);
      expect(status.acceptedVersion, isNull);

      final after = await container
          .read(aiConsentStatusProvider.notifier)
          .accept(1);
      expect(after.required, isFalse);
      expect(container.read(aiConsentStatusProvider).value?.required, isFalse);
      expect(inputOf(api.requestsOf('RecordAiConsent').single)['version'], 1);
      expect(analytics.events.single.name, AnalyticsEvents.consentAiAccepted);
      expect(analytics.events.single.props, {'version': 1});
    });

    test('a new version of the text asks again', () async {
      api.use('MyAiConsent', 'new_version');
      final status = await start().read(aiConsentStatusProvider.future);
      expect(status.required, isTrue);
      expect(status.acceptedVersion, 1);
      expect(status.currentVersion, 2);
    });

    test('accepting offline fails and changes nothing', () async {
      api
        ..use('MyAiConsent', 'required')
        ..fail('RecordAiConsent', const SocketException('offline'));
      final container = start();
      await container.read(aiConsentStatusProvider.future);

      await expectLater(
        container.read(aiConsentStatusProvider.notifier).accept(1),
        throwsA(isA<ApiNetworkError>()),
      );
      expect(container.read(aiConsentStatusProvider).value?.required, isTrue);
      expect(analytics.events, isEmpty);
    });

    test('offline is an error state, without silent retries', () async {
      api.fail('MyAiConsent', const SocketException('offline'));
      final container = start();
      await expectLater(
        container.read(aiConsentStatusProvider.future),
        throwsA(isA<ApiNetworkError>()),
      );
      expect(api.requestsOf('MyAiConsent'), hasLength(1));
    });

    test('withdrawing is recorded and read back', () async {
      final container = start();
      await container.read(aiConsentStatusProvider.future);
      api.use('MyAiConsent', 'required');

      await container.read(aiConsentStatusProvider.notifier).withdraw(1);

      expect(inputOf(api.requestsOf('RecordConsent').single), {
        'key': 'AI_CONSENT',
        'version': 1,
        'accepted': false,
      });
      expect(container.read(aiConsentStatusProvider).value?.required, isTrue);
    });
  });
}
