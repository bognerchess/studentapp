// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// An identity provider that Keycloak brokers and the sign-in screen offers
/// as a button of its own.
enum SignInIdp {
  apple('apple'),
  google('google');

  const SignInIdp(this.alias);

  /// The alias of the identity provider in the Keycloak realm, sent as
  /// `kc_idp_hint`. Also the spelling used in `AUTH_IDPS`.
  final String alias;

  /// Parses a comma-separated list of aliases. Unknown names are ignored,
  /// duplicates too. The result is always in enum order, which puts Apple
  /// first, as Apple's guidelines ask for.
  static List<SignInIdp> parseList(String value) {
    final wanted = value.split(',').map((name) => name.trim()).toSet();
    return [
      for (final idp in SignInIdp.values)
        if (wanted.contains(idp.alias)) idp,
    ];
  }
}

/// The provider buttons of this build.
///
/// Default: Apple and Google. A configuration can narrow it with the optional
/// dart-define `AUTH_IDPS` (for example `"AUTH_IDPS": "google"` in
/// `config/<env>.json` while the Apple identity provider is not set up at the
/// server yet, human gate H6; `""` hides both).
const String _configuredIdps = String.fromEnvironment(
  'AUTH_IDPS',
  defaultValue: 'apple,google',
);

final signInIdpsProvider = Provider<List<SignInIdp>>(
  (ref) => SignInIdp.parseList(_configuredIdps),
);
