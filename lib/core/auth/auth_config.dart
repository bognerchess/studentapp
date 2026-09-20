// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// Compile-time switches of the auth layer. `docs/auth.md` explains each one.
abstract final class AuthConfig {
  /// The scopes of every authorization request. `offline_access` makes the
  /// refresh token an offline token, which survives the end of the browser
  /// session at the identity provider.
  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'offline_access',
  ];

  /// Whether the system browser sheet (`ASWebAuthenticationSession`) runs
  /// without access to Safari's cookies and keeps none itself.
  ///
  /// true: no "wants to use ... to sign in" alert, a sign-out is final (the
  /// next sign-in asks for credentials, so another person can sign in), but
  /// no single sign-on with Safari, and a Google or Apple session in Safari
  /// is not reused.
  ///
  /// false: the opposite on every count. See "Session mode" in docs/auth.md
  /// before changing it: the shared mode needs `prompt=login` after a
  /// sign-out, or the user cannot switch accounts.
  static const bool preferEphemeralSession = true;

  /// How "Create account" opens Keycloak's registration page.
  ///
  /// false: the standard `prompt=create` (Keycloak 26.1 and newer).
  /// true: Keycloak's older, deprecated `.../openid-connect/registrations`
  /// endpoint in place of the authorization endpoint, for a server that does
  /// not know `prompt=create` yet.
  static const bool useLegacyRegistrationEndpoint = false;

  /// An access token with less than this left is refreshed before use.
  static const Duration freshnessMargin = Duration(seconds: 30);

  /// A caller that waits longer for a refresh gets a transport error. The
  /// request itself is not cancelled.
  static const Duration refreshTimeout = Duration(seconds: 20);

  /// Sign-out does not wait longer than this for the revocation.
  static const Duration revokeTimeout = Duration(seconds: 8);
}
