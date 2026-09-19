// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/auth/auth_state.dart';

/// Called after an explicit sign-out with the subject that was signed in, to
/// remove that user's cached data (drafts stay).
typedef SignedOutHook = Future<void> Function(String sub);

/// Everything the rest of the app may know about authentication.
///
/// The API layer uses [accessToken] before a request and [forceRefresh] after
/// a 401. UI uses [signIn] and [signOut]. State is read through
/// `authStateProvider`, which mirrors [state].
abstract interface class AuthRepository {
  /// The current state, synchronously.
  AuthState get state;

  /// Every change of [state]. A broadcast stream without replay: read [state]
  /// first, then listen.
  Stream<AuthState> get states;

  /// Once at app start, before the first frame: applies the reinstall rule
  /// and loads stored tokens. Makes no network request, so an offline start
  /// is a signed-in start. Never throws.
  Future<void> restore();

  /// Opens the system browser sheet and completes when it is gone.
  ///
  /// [register] opens the registration page. [idpHint] goes straight to an
  /// identity provider (`apple`, `google`).
  ///
  /// When the user closes the sheet, this completes normally and [state] is
  /// unchanged: cancelling is not an error. Throws [AuthException] otherwise.
  Future<void> signIn({bool register = false, String? idpHint});

  /// A token for the `Authorization` header: the cached one while it has more
  /// than 30 s left, otherwise the result of the one refresh in flight.
  ///
  /// Returns null when nobody is signed in, including when this very call
  /// found that the session has ended (then [state] is already `SignedOut`).
  /// Throws [AuthException] when the refresh could not be made (offline, time
  /// out, server trouble); the user stays signed in.
  Future<String?> accessToken();

  /// After a 401: refreshes even though the cached token looks valid.
  ///
  /// Pass the token the server refused as [rejectedToken]: if another caller
  /// has refreshed in the meantime, the newer token is returned without a
  /// second refresh. Same results and errors as [accessToken].
  Future<String?> forceRefresh({String? rejectedToken});

  /// Forgets the tokens, moves to `SignedOut`, removes the user's cached data
  /// (drafts stay) and revokes the refresh token at the server, without a
  /// browser. Never throws: a failed revocation still signs out locally.
  Future<void> signOut();
}

enum AuthErrorKind {
  /// No connection, or no answer in time. Worth retrying.
  network,

  /// The identity provider answered with an error, or with something
  /// unusable.
  server,
}

class AuthException implements Exception {
  const AuthException(this.kind, [this.code]);

  final AuthErrorKind kind;

  /// A short machine-readable code for logs. Never a token or a description.
  final String? code;

  @override
  String toString() => 'AuthException(${kind.name}, $code)';
}
