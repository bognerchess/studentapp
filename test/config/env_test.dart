// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';
import 'dart:io';

import 'package:bogner_chess/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> readConfig(String name) {
  final text = File('config/$name.json').readAsStringSync();
  return jsonDecode(text) as Map<String, Object?>;
}

void main() {
  const envNames = ['dev', 'fake', 'staging', 'prod'];

  for (final name in envNames) {
    test('config/$name.json defines every key and names itself', () {
      final json = readConfig(name);
      expect(json.keys, containsAll(Env.keys));
      final env = Env.fromJson(json);
      expect(env.envName, name);
      expect(env.tenantSlug, isNotEmpty);
      expect(env.oidcIssuer.scheme, 'https');
      expect(env.oidcClientId, 'bognerchess-mobile');
      expect(env.oidcRedirect, 'com.bognerchess.mobile:/oauthredirect');
    });
  }

  test('config/prod.json uses real auth and an https API', () {
    final json = readConfig('prod');
    expect(json['AUTH_MODE'], 'real');
    expect(json['API_URL'], startsWith('https://'));

    final env = Env.fromJson(json);
    expect(env.isProd, isTrue);
    expect(env.authMode, AuthMode.real);
    expect(env.apiUrl, Uri.parse('https://web.bognerchess.com/graphql'));
    expect(env.assertSafeForRelease, returnsNormally);
  });

  test('config/staging.json is releasable too', () {
    final env = Env.fromJson(readConfig('staging'));
    expect(env.isProd, isFalse);
    expect(env.assertSafeForRelease, returnsNormally);
  });

  test('only config/fake.json uses fake auth', () {
    for (final name in envNames) {
      final env = Env.fromJson(readConfig(name));
      expect(env.usesFakeAuth, name == 'fake', reason: name);
    }
  });

  test('dev and fake point at localhost and are refused in release', () {
    final dev = Env.fromJson(readConfig('dev'));
    final fake = Env.fromJson(readConfig('fake'));
    expect(dev.apiUrl, Uri.parse('http://localhost:5200/graphql'));
    expect(fake.apiUrl, Uri.parse('http://localhost:5299/graphql'));
    expect(dev.assertSafeForRelease, throwsStateError);
    expect(fake.assertSafeForRelease, throwsStateError);
  });

  test('no config file carries anything that looks like a secret', () {
    final suspicious = RegExp(
      'secret|password|private|token|api[_-]?key',
      caseSensitive: false,
    );
    for (final name in envNames) {
      final json = readConfig(name);
      for (final key in json.keys) {
        expect(suspicious.hasMatch(key), isFalse, reason: '$name: $key');
      }
      expect(json['SENTRY_DSN'], isEmpty, reason: name);
    }
  });

  test('only the exact word "fake" selects fake auth', () {
    expect(Env.parseAuthMode('fake'), AuthMode.fake);
    expect(Env.parseAuthMode('real'), AuthMode.real);
    expect(Env.parseAuthMode(''), AuthMode.real);
    expect(Env.parseAuthMode('FAKE'), AuthMode.real);
    expect(Env.parseAuthMode('fake '), AuthMode.real);
  });

  test('a missing key is a format error', () {
    final json = readConfig('prod')..remove('API_URL');
    expect(() => Env.fromJson(json), throwsFormatException);
  });

  test('without dart-defines the dev values apply', () {
    final env = Env.fromEnvironment();
    expect(env.envName, 'dev');
    expect(env.authMode, AuthMode.real);
    expect(env.apiUrl.host, 'localhost');
    // Meaningless when the test run itself was given a config file.
  }, skip: const bool.hasEnvironment('ENV_NAME'));
}
