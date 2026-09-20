// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/auth/auth_providers.dart';
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
  const SignedIn(this.sub, {this.email, this.emailVerified, this.name});

  /// The OIDC subject of the signed-in user. Local data is scoped by it.
  final String sub;

  /// From the id token; null when the token did not carry the claim.
  final String? email;

  /// From the id token. False right after registering, until the link in the
  /// verification mail was opened and the tokens were refreshed.
  final bool? emailVerified;

  /// Display name (`name`, else `preferred_username`).
  final String? name;

  @override
  bool operator ==(Object other) =>
      other is SignedIn &&
      other.sub == sub &&
      other.email == email &&
      other.emailVerified == emailVerified &&
      other.name == name;

  @override
  int get hashCode => Object.hash(SignedIn, sub, email, emailVerified, name);

  // Subject, e-mail and name identify a person: keep them out of logs.
  @override
  String toString() => 'SignedIn';
}

/// The subject used with `AUTH_MODE=fake`. The mock server knows the same id.
const String kFakeAuthSub = 'fake-user-1';

/// The state of [authRepositoryProvider]'s repository, as a provider. The
/// router redirects on it, and everything that scopes data to a user reads
/// the subject from it.
class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final repository = ref.watch(authRepositoryProvider);
    final subscription = repository.states.listen((next) => state = next);
    ref.onDispose(subscription.cancel);
    return repository.state;
  }
}

final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);
