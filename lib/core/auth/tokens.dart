// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// What the token endpoint returned, before it is merged with what the app
/// already holds. A refresh response may leave out the refresh token (no
/// rotation) or the id token.
@immutable
class OidcTokenResult {
  const OidcTokenResult({
    required this.accessToken,
    this.refreshToken,
    this.idToken,
    this.accessTokenExpiry,
  });

  final String accessToken;
  final String? refreshToken;
  final String? idToken;

  /// Computed by the native AppAuth library from `expires_in` and the
  /// *device* clock at the time of the response. A difference between the
  /// server's clock and the device's therefore does not matter.
  final DateTime? accessTokenExpiry;

  // Never print a token.
  @override
  String toString() => 'OidcTokenResult(***)';
}

/// The token set the app holds for the signed-in user.
@immutable
class Tokens {
  const Tokens({
    required this.accessToken,
    required this.refreshToken,
    required this.idToken,
    required this.expiresAt,
    required this.obtainedAt,
  });

  /// Reads what [toJson] wrote. Throws a [FormatException] on anything else.
  factory Tokens.fromJson(Map<String, Object?> json) {
    final accessToken = json['access_token'];
    final idToken = json['id_token'];
    final refreshToken = json['refresh_token'];
    final expiresAt = json['expires_at'];
    final obtainedAt = json['obtained_at'];
    if (accessToken is! String ||
        idToken is! String ||
        refreshToken is! String? ||
        expiresAt is! int ||
        obtainedAt is! int) {
      throw const FormatException('stored tokens have an unknown shape');
    }
    return Tokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      idToken: idToken,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt, isUtc: true),
      obtainedAt: DateTime.fromMillisecondsSinceEpoch(obtainedAt, isUtc: true),
    );
  }

  final String accessToken;

  /// Null only if the server granted no `offline_access`; the session then
  /// ends with the access token.
  final String? refreshToken;

  /// Kept for its claims (subject, e-mail, name). Never sent anywhere.
  final String idToken;

  /// Device time at which the access token expires.
  final DateTime expiresAt;

  /// Device time at which these tokens arrived.
  final DateTime obtainedAt;

  /// Whether the access token can be used for a request started at [now].
  ///
  /// [margin] covers the request's travel time and small clock drift. If the
  /// device clock was set back to well before [obtainedAt], [expiresAt] says
  /// nothing any more, and the token counts as expired. The other direction
  /// (the server thinks the token has expired, the device does not) shows up
  /// as a 401, which the API layer answers with a forced refresh.
  bool isFreshAt(
    DateTime now, {
    Duration margin = const Duration(seconds: 30),
    Duration backwardsTolerance = const Duration(minutes: 1),
  }) {
    if (now.isBefore(obtainedAt.subtract(backwardsTolerance))) {
      return false;
    }
    return expiresAt.difference(now) > margin;
  }

  Map<String, Object?> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'id_token': idToken,
    'expires_at': expiresAt.toUtc().millisecondsSinceEpoch,
    'obtained_at': obtainedAt.toUtc().millisecondsSinceEpoch,
  };

  // Never print a token.
  @override
  String toString() => 'Tokens(***)';
}

/// The claims the app reads from the id token.
///
/// The signature is **not** verified here. The app never makes a security
/// decision on these values: they label local data (`sub`) and are shown to
/// the user. Every request is authorised by the backend, which verifies the
/// access token. The native AppAuth library has checked issuer, audience,
/// expiry and nonce of the id token when it arrived.
@immutable
class IdTokenClaims {
  const IdTokenClaims({
    required this.sub,
    this.email,
    this.emailVerified,
    this.name,
  });

  /// Decodes the payload of a JWT. Returns null when [jwt] is not a JWT or
  /// has no subject.
  static IdTokenClaims? tryParse(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) {
      return null;
    }
    final Object? payload;
    try {
      payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
    } on FormatException {
      return null;
    }
    if (payload is! Map<String, Object?>) {
      return null;
    }
    final claims = payload;
    final sub = claims['sub'];
    if (sub is! String || sub.isEmpty) {
      return null;
    }
    String? text(String key) => switch (claims[key]) {
      final String value when value.trim().isNotEmpty => value.trim(),
      _ => null,
    };
    return IdTokenClaims(
      sub: sub,
      email: text('email'),
      emailVerified: switch (claims['email_verified']) {
        final bool value => value,
        'true' => true,
        'false' => false,
        _ => null,
      },
      name: text('name') ?? text('preferred_username'),
    );
  }

  final String sub;
  final String? email;
  final bool? emailVerified;
  final String? name;

  // Identifies a person: keep it out of logs.
  @override
  String toString() => 'IdTokenClaims(***)';
}
