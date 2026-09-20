// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/auth/tokens.dart';

/// The three conversations the app has with the identity provider. A small
/// interface in front of `flutter_appauth`, so that every branch of
/// `AppAuthRepository` can be tested with a fake.
abstract interface class OidcClient {
  /// Authorization code flow with PKCE in the system browser sheet.
  ///
  /// [register] opens the registration page instead of the login page.
  /// [idpHint] is Keycloak's `kc_idp_hint`: skip Keycloak's own page and go
  /// straight to that identity provider (`apple`, `google`).
  ///
  /// Throws [OidcCancelled] when the user closed the sheet, [OidcException]
  /// otherwise.
  Future<OidcTokenResult> authorize({bool register = false, String? idpHint});

  /// Refresh token grant. Throws [OidcException].
  Future<OidcTokenResult> refresh(String refreshToken);

  /// RFC 7009 revocation of a refresh token, without a browser. Throws
  /// [OidcException].
  Future<void> revoke(String refreshToken);
}

/// The user closed the browser sheet. Not an error.
class OidcCancelled implements Exception {
  const OidcCancelled();

  @override
  String toString() => 'OidcCancelled';
}

enum OidcFailure {
  /// The server refused the grant for good (`invalid_grant`, or a member of
  /// the `invalid_token` family): the refresh token was used before (rotation
  /// race), revoked, or its session ended. Retrying cannot help.
  grantRejected,

  /// The server was not reached, or did not answer in time. Says nothing
  /// about the tokens.
  transport,

  /// Anything else: a 5xx, an unreadable answer, a misconfigured client.
  /// Says nothing about the tokens either.
  other,
}

class OidcException implements Exception {
  const OidcException(this.failure, [this.code]);

  final OidcFailure failure;

  /// The OAuth `error` value or a platform error code. Safe to log; never a
  /// description, which may quote request parameters.
  final String? code;

  @override
  String toString() => 'OidcException(${failure.name}, $code)';
}
