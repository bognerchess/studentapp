// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/consent/consent_state.dart';
import 'package:bogner_chess/core/device/device_id.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  ProviderContainer containerWith(Map<String, Object> stored) {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData(stored);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  group('analyticsConsentProvider', () {
    test('no decision: unknown, which is not granted', () async {
      final container = containerWith({});
      expect(
        container.read(analyticsConsentProvider),
        AnalyticsConsent.unknown,
      );
      await container.read(analyticsConsentProvider.notifier).loaded;
      expect(
        container.read(analyticsConsentProvider),
        AnalyticsConsent.unknown,
      );
    });

    test('a stored decision is the state once loaded', () async {
      for (final (stored, expected) in [
        ('granted', AnalyticsConsent.granted),
        ('denied', AnalyticsConsent.denied),
        ('something else', AnalyticsConsent.unknown),
      ]) {
        final container = containerWith({kAnalyticsConsentKey: stored});
        await container.read(analyticsConsentProvider.notifier).loaded;
        expect(container.read(analyticsConsentProvider), expected);
      }
    });

    test(
      'a decision is stored, and wins over a read still in flight',
      () async {
        final container = containerWith({kAnalyticsConsentKey: 'granted'});
        final notifier = container.read(analyticsConsentProvider.notifier);
        await notifier.set(granted: false);
        await notifier.loaded;

        expect(
          container.read(analyticsConsentProvider),
          AnalyticsConsent.denied,
        );
        expect(
          await SharedPreferencesAsync().getString(kAnalyticsConsentKey),
          'denied',
        );
      },
    );
  });

  group('deviceIdProvider', () {
    test('creates a UUID v4 once and keeps it', () async {
      final container = containerWith({});
      final id = await container.read(deviceIdProvider.future);
      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(await SharedPreferencesAsync().getString(kDeviceIdKey), id);

      // A new start of the app.
      final second = ProviderContainer();
      addTearDown(second.dispose);
      expect(await second.read(deviceIdProvider.future), id);
    });

    test('an existing id is used', () async {
      final container = containerWith({kDeviceIdKey: 'installation-7'});
      expect(await container.read(deviceIdProvider.future), 'installation-7');
    });
  });
}
