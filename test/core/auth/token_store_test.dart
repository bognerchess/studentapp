// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/auth/install_marker.dart';
import 'package:bogner_chess/core/auth/token_store.dart';
import 'package:bogner_chess/core/auth/tokens.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  final tokens = Tokens(
    accessToken: 'a',
    refreshToken: 'r',
    idToken: 'i',
    expiresAt: DateTime.utc(2026, 9, 19, 12, 5),
    obtainedAt: DateTime.utc(2026, 9, 19, 12),
  );

  group('SecureTokenStore', () {
    setUp(() {
      Log.sink = (_) {};
    });
    tearDown(Log.resetSink);

    test('uses first_unlock_this_device', () {
      expect(
        SecureTokenStore.iosOptions.toMap()['accessibility'],
        'first_unlock_this_device',
      );
    });

    test('write, read, clear', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = SecureTokenStore();
      expect(await store.read(), isNull);

      await store.write(tokens);
      final read = await store.read();
      expect(read?.accessToken, 'a');
      expect(read?.refreshToken, 'r');
      expect(read?.expiresAt, tokens.expiresAt);

      await store.clear();
      expect(await store.read(), isNull);
    });

    test('keeps everything in one Keychain item', () async {
      FlutterSecureStorage.setMockInitialValues({});
      await SecureTokenStore().write(tokens);
      expect(await const FlutterSecureStorage().readAll(), {
        SecureTokenStore.storageKey: anything,
      });
    });

    test('unreadable content counts as absent and is removed', () async {
      for (final raw in ['not json', '[]', '{"access_token": 1}']) {
        FlutterSecureStorage.setMockInitialValues({
          SecureTokenStore.storageKey: raw,
        });
        final store = SecureTokenStore();
        expect(await store.read(), isNull, reason: raw);
        expect(await const FlutterSecureStorage().readAll(), isEmpty);
      }
    });
  });

  group('PreferencesInstallMarker', () {
    test('is unset on a fresh installation and stays set afterwards', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final marker = PreferencesInstallMarker(SharedPreferencesAsync.new);
      expect(await marker.isSet(), isFalse);
      await marker.set();
      expect(await marker.isSet(), isTrue);
      expect(
        await PreferencesInstallMarker(SharedPreferencesAsync.new).isSet(),
        isTrue,
      );
    });
  });
}
