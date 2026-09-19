// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

import 'package:bogner_chess/core/auth/tokens.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the token set lives between app starts.
abstract interface class TokenStore {
  /// The stored tokens, or null when there are none (or they are unreadable).
  Future<Tokens?> read();

  Future<void> write(Tokens tokens);

  Future<void> clear();
}

/// The iOS Keychain, through `flutter_secure_storage`.
///
/// Accessibility is `first_unlock_this_device`: readable while the phone is
/// locked (a push can arrive then) once it was unlocked after a boot, and
/// never part of a backup or a transfer to another device.
///
/// A Keychain item outlives the app: deleting the app does not delete it.
/// `AppAuthRepository.restore` therefore clears this store on the first
/// launch of an installation.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage(iOptions: iosOptions);

  static const IOSOptions iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  /// One item holding the whole set as JSON, so that a write is atomic: there
  /// is never a new access token next to an old refresh token.
  static const String storageKey = 'auth.tokens.v1';

  static const _log = Log('auth.store');

  final FlutterSecureStorage _storage;

  @override
  Future<Tokens?> read() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null) {
      return null;
    }
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) {
        throw const FormatException('not an object');
      }
      return Tokens.fromJson(json);
    } on FormatException {
      // Written by a version this one does not understand. The content is
      // deliberately not logged.
      _log.warning('stored tokens are unreadable; clearing them');
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(Tokens tokens) =>
      _storage.write(key: storageKey, value: jsonEncode(tokens.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: storageKey);
}

/// For tests and for fake auth.
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this.tokens]);

  Tokens? tokens;

  /// Counters for tests.
  int writes = 0;
  int clears = 0;

  @override
  Future<Tokens?> read() async => tokens;

  @override
  Future<void> write(Tokens tokens) async {
    writes++;
    this.tokens = tokens;
  }

  @override
  Future<void> clear() async {
    clears++;
    tokens = null;
  }
}
