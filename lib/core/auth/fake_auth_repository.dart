// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/auth/auth_repository.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:flutter/foundation.dart';

/// The token `FakeAuthRepository` hands out. The mock server accepts it.
const String kFakeAccessToken = 'fake-access-token';

/// `AUTH_MODE=fake`: no identity provider, no Keychain, no browser. Signed in
/// as [kFakeAuthSub] from the start; [signOut] and [signIn] toggle the state,
/// so that UI tests and simulator runs can walk through the sign-in screen.
///
/// Never part of a release: `Env.fromEnvironment` refuses fake auth in a
/// release build, `authRepositoryProvider` refuses it for the prod
/// configuration, and the constructor asserts it once more.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    bool signedIn = true,
    this.signInError,
    this.signInDelay = Duration.zero,
    this._onSignedOut,
    this._onBeforeSignOut,
  }) : assert(!kReleaseMode, 'fake auth must never run in a release build'),
       _state = signedIn ? fakeUser : const SignedOut();

  static const SignedIn fakeUser = SignedIn(
    kFakeAuthSub,
    email: 'fake.user@example.test',
    emailVerified: true,
    name: 'Fake User',
  );

  /// When set, [signIn] throws it (after [signInDelay]) instead of signing
  /// in: for the error states of the sign-in screen.
  AuthException? signInError;

  /// Stands in for the time the browser sheet is open.
  Duration signInDelay;

  /// What [signIn] was called with, newest last.
  final List<({bool register, String? idpHint})> signInCalls = [];

  final SignedOutHook? _onSignedOut;
  final SignedOutHook? _onBeforeSignOut;
  final StreamController<AuthState> _states =
      StreamController<AuthState>.broadcast(sync: true);
  AuthState _state;

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get states => _states.stream;

  @override
  Future<void> restore() async {}

  @override
  Future<void> signIn({bool register = false, String? idpHint}) async {
    signInCalls.add((register: register, idpHint: idpHint));
    if (signInDelay > Duration.zero) {
      await Future<void>.delayed(signInDelay);
    }
    final error = signInError;
    if (error != null) {
      throw error;
    }
    _setState(fakeUser);
  }

  @override
  Future<String?> accessToken() async =>
      _state is SignedIn ? kFakeAccessToken : null;

  @override
  Future<String?> forceRefresh({String? rejectedToken}) => accessToken();

  @override
  Future<void> signOut() async {
    final wasSignedIn = _state is SignedIn;
    if (wasSignedIn) {
      try {
        await _onBeforeSignOut?.call(kFakeAuthSub);
      } on Object {
        // As in the real repository: a hook cannot stop a sign-out.
      }
    }
    _setState(const SignedOut());
    if (wasSignedIn) {
      await _onSignedOut?.call(kFakeAuthSub);
    }
  }

  Future<void> dispose() => _states.close();

  void _setState(AuthState next) {
    if (next == _state) {
      return;
    }
    _state = next;
    if (!_states.isClosed) {
      _states.add(next);
    }
  }
}
