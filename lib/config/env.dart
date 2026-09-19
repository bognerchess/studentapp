// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How the app authenticates. `fake` exists for the mock server, widget tests
/// and simulator screenshots, and is refused in release builds.
enum AuthMode { real, fake }

/// The build-time configuration, read from
/// `--dart-define-from-file=config/<env>.json`.
///
/// The config files are committed and contain nothing secret: an OIDC public
/// client has no secret, and a Sentry DSN is not one.
@immutable
class Env {
  const Env({
    required this.envName,
    required this.apiUrl,
    required this.tenantSlug,
    required this.oidcIssuer,
    required this.oidcClientId,
    required this.oidcRedirect,
    required this.sentryDsn,
    required this.authMode,
  });

  /// Reads the compile-time defines. Without any define (a bare `flutter run`
  /// or `flutter test`) the values of `config/dev.json` apply.
  ///
  /// Throws a [StateError] if a release build is configured with fake auth or
  /// a non-https API, so that such a build cannot reach a user.
  factory Env.fromEnvironment() {
    final env = Env(
      envName: const String.fromEnvironment('ENV_NAME', defaultValue: 'dev'),
      apiUrl: Uri.parse(
        const String.fromEnvironment(
          'API_URL',
          defaultValue: 'http://localhost:5200/graphql',
        ),
      ),
      tenantSlug: const String.fromEnvironment(
        'TENANT_SLUG',
        defaultValue: 'htytedif',
      ),
      oidcIssuer: Uri.parse(
        const String.fromEnvironment(
          'OIDC_ISSUER',
          defaultValue: 'https://id.bognerchess.com/realms/bognerchess',
        ),
      ),
      oidcClientId: const String.fromEnvironment(
        'OIDC_CLIENT_ID',
        defaultValue: 'bognerchess-mobile',
      ),
      oidcRedirect: const String.fromEnvironment(
        'OIDC_REDIRECT',
        defaultValue: 'com.bognerchess.mobile:/oauthredirect',
      ),
      sentryDsn: const String.fromEnvironment('SENTRY_DSN'),
      authMode: parseAuthMode(const String.fromEnvironment('AUTH_MODE')),
    );
    if (kReleaseMode) {
      env.assertSafeForRelease();
    }
    return env;
  }

  /// Builds an [Env] from the decoded content of a `config/<env>.json` file.
  /// Used by tests that check the committed files.
  factory Env.fromJson(Map<String, Object?> json) {
    String read(String key) => switch (json[key]) {
      final String value => value,
      _ => throw FormatException('config key $key is missing or not a string'),
    };
    return Env(
      envName: read('ENV_NAME'),
      apiUrl: Uri.parse(read('API_URL')),
      tenantSlug: read('TENANT_SLUG'),
      oidcIssuer: Uri.parse(read('OIDC_ISSUER')),
      oidcClientId: read('OIDC_CLIENT_ID'),
      oidcRedirect: read('OIDC_REDIRECT'),
      sentryDsn: read('SENTRY_DSN'),
      authMode: parseAuthMode(read('AUTH_MODE')),
    );
  }

  /// The keys every config file must define.
  static const List<String> keys = [
    'ENV_NAME',
    'API_URL',
    'TENANT_SLUG',
    'OIDC_ISSUER',
    'OIDC_CLIENT_ID',
    'OIDC_REDIRECT',
    'SENTRY_DSN',
    'AUTH_MODE',
  ];

  /// `dev`, `fake`, `staging` or `prod`.
  final String envName;

  /// The GraphQL endpoint.
  final Uri apiUrl;

  /// Sent as `X-Tenant-Slug` with every request.
  final String tenantSlug;

  final Uri oidcIssuer;
  final String oidcClientId;
  final String oidcRedirect;

  /// Empty means crash reporting has nowhere to send to and stays off.
  final String sentryDsn;

  final AuthMode authMode;

  bool get isProd => envName == 'prod';
  bool get usesFakeAuth => authMode == AuthMode.fake;

  /// Anything but exactly `fake` is real auth, so a typo can never open the
  /// fake path.
  static AuthMode parseAuthMode(String value) =>
      value == 'fake' ? AuthMode.fake : AuthMode.real;

  /// The conditions a build that reaches users has to meet.
  void assertSafeForRelease() {
    if (usesFakeAuth) {
      throw StateError('AUTH_MODE=fake is not allowed in a release build');
    }
    if (apiUrl.scheme != 'https') {
      throw StateError('API_URL must be https in a release build: $apiUrl');
    }
  }
}

/// The configuration of this build. Tests override it with
/// `envProvider.overrideWithValue(...)`.
final envProvider = Provider<Env>((ref) => Env.fromEnvironment());
