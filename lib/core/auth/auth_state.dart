// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/config/env.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether somebody is signed in. The router and everything that scopes data
/// to a user (drafts are owned by a token subject) depend on this, and on
/// nothing else from the auth layer.
@immutable
sealed class AuthState {
  const AuthState();
}

final class SignedOut extends AuthState {
  const SignedOut();

  @override
  bool operator ==(Object other) => other is SignedOut;

  @override
  int get hashCode => (SignedOut).hashCode;

  @override
  String toString() => 'SignedOut';
}

final class SignedIn extends AuthState {
  const SignedIn(this.sub);

  /// The OIDC subject of the signed-in user.
  final String sub;

  @override
  bool operator ==(Object other) => other is SignedIn && other.sub == sub;

  @override
  int get hashCode => Object.hash(SignedIn, sub);

  // The subject is an identifier of a person: keep it out of logs.
  @override
  String toString() => 'SignedIn';
}

/// The subject used with `AUTH_MODE=fake`. The mock server knows the same id.
const String kFakeAuthSub = 'fake-user-1';

/// Seam for WP-25, which replaces [build] with the state of the real
/// `AuthRepository`. Until then: signed in with fake auth, signed out
/// otherwise.
class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final env = ref.watch(envProvider);
    return env.usesFakeAuth ? const SignedIn(kFakeAuthSub) : const SignedOut();
  }
}

final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);
