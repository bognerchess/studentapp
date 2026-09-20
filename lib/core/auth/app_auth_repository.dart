// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/auth/auth_config.dart';
import 'package:bogner_chess/core/auth/auth_repository.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/auth/install_marker.dart';
import 'package:bogner_chess/core/auth/oidc_client.dart';
import 'package:bogner_chess/core/auth/token_store.dart';
import 'package:bogner_chess/core/auth/tokens.dart';
import 'package:bogner_chess/core/log.dart';

/// The real [AuthRepository]: OIDC through an [OidcClient], tokens in a
/// [TokenStore]. `docs/auth.md` describes the rules implemented here.
///
/// Nothing in this class logs a token, a subject or an e-mail address.
class AppAuthRepository implements AuthRepository {
  AppAuthRepository({
    required this._oidc,
    required this._store,
    required this._installMarker,
    this._onSignedOut,
    this._onBeforeSignOut,
    DateTime Function()? now,
    this.refreshTimeout = AuthConfig.refreshTimeout,
    this.revokeTimeout = AuthConfig.revokeTimeout,
  }) : _now = now ?? DateTime.now;

  /// A caller that waits longer for a refresh gets a transport error.
  final Duration refreshTimeout;

  /// Sign-out does not wait longer than this for the revocation.
  final Duration revokeTimeout;

  static const _log = Log('auth');

  final OidcClient _oidc;
  final TokenStore _store;
  final InstallMarker _installMarker;
  final SignedOutHook? _onSignedOut;
  final SignedOutHook? _onBeforeSignOut;
  final DateTime Function() _now;

  // Synchronous, so that `await signIn()` returns with `authStateProvider`
  // already updated.
  final StreamController<AuthState> _states =
      StreamController<AuthState>.broadcast(sync: true);

  AuthState _state = const SignedOut();
  Tokens? _tokens;

  /// The one refresh in flight. Refresh tokens rotate: of two concurrent
  /// refreshes with the same token the second gets `invalid_grant`, and the
  /// user would be signed out for no reason. Every caller that needs a fresh
  /// token awaits this future instead of starting its own.
  Future<Tokens?>? _inFlight;

  Future<void>? _signInInFlight;

  /// Raised whenever the identity changes (sign-in, sign-out, session end).
  /// A refresh that was started before and finishes after must not write its
  /// result over the new situation.
  int _epoch = 0;

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get states => _states.stream;

  @override
  Future<void> restore() async {
    try {
      if (!await _installMarker.isSet()) {
        // First start of this installation: whatever the Keychain holds is
        // from before the app was deleted.
        await _store.clear();
        await _installMarker.set();
        _log.info('first launch: token store cleared');
        return;
      }
      final tokens = await _store.read();
      if (tokens == null) {
        return;
      }
      final claims = IdTokenClaims.tryParse(tokens.idToken);
      if (claims == null) {
        _log.warning('stored id token is unreadable; signing out');
        await _store.clear();
        return;
      }
      // No refresh here: an expired access token is renewed by the first
      // accessToken() call, and an offline start stays signed in.
      _tokens = tokens;
      _setState(_signedIn(claims));
    } on Object catch (e, stack) {
      // A Keychain or preferences failure must not keep the app from
      // starting. Signed out is the safe state.
      _log.error('restore failed', error: e, stackTrace: stack);
    }
  }

  @override
  Future<void> signIn({bool register = false, String? idpHint}) {
    // The system shows one browser sheet at a time; a second tap joins the
    // first attempt.
    return _signInInFlight ??= _doSignIn(
      register: register,
      idpHint: idpHint,
    ).whenComplete(() => _signInInFlight = null);
  }

  Future<void> _doSignIn({required bool register, String? idpHint}) async {
    final OidcTokenResult result;
    try {
      result = await _oidc.authorize(register: register, idpHint: idpHint);
    } on OidcCancelled {
      _log.info('sign-in cancelled by the user');
      return;
    } on OidcException catch (e) {
      _log.warning('sign-in failed: $e');
      throw _toAuthException(e);
    }
    final idToken = result.idToken;
    final claims = idToken == null ? null : IdTokenClaims.tryParse(idToken);
    if (idToken == null || claims == null) {
      _log.warning('sign-in failed: no usable id token');
      throw const AuthException(AuthErrorKind.server, 'no_id_token');
    }
    if (result.refreshToken == null) {
      _log.warning('no refresh token granted; the session will be short');
    }
    final tokens = _merge(result, idToken: idToken, refreshToken: null);
    _epoch++;
    await _store.write(tokens);
    _tokens = tokens;
    _setState(_signedIn(claims));
    _log.info('signed in');
  }

  @override
  Future<String?> accessToken() async {
    final tokens = _tokens;
    if (tokens == null) {
      return null;
    }
    if (tokens.isFreshAt(_now(), margin: AuthConfig.freshnessMargin)) {
      return tokens.accessToken;
    }
    return _refreshedAccessToken();
  }

  @override
  Future<String?> forceRefresh({String? rejectedToken}) async {
    final tokens = _tokens;
    if (tokens == null) {
      return null;
    }
    if (rejectedToken != null &&
        rejectedToken != tokens.accessToken &&
        _inFlight == null) {
      // Somebody else has refreshed since that request was sent.
      return tokens.accessToken;
    }
    return _refreshedAccessToken();
  }

  /// Waits for the one refresh, but not for ever. A caller that gives up
  /// does not cancel the request: if the answer still arrives, the rotated
  /// tokens are stored. Dropping them would end the session, because the old
  /// refresh token is already used up by then.
  Future<String?> _refreshedAccessToken() async {
    try {
      return (await _refresh().timeout(refreshTimeout))?.accessToken;
    } on TimeoutException {
      _log.warning('refresh timed out; keeping the tokens');
      throw const AuthException(AuthErrorKind.network, 'timeout');
    }
  }

  Future<Tokens?> _refresh() {
    return _inFlight ??= _doRefresh().whenComplete(() => _inFlight = null);
  }

  Future<Tokens?> _doRefresh() async {
    final current = _tokens;
    if (current == null) {
      return null;
    }
    final epoch = _epoch;
    final refreshToken = current.refreshToken;
    if (refreshToken == null) {
      _log.info('access token expired and there is no refresh token');
      await _endSession(epoch);
      return null;
    }
    final OidcTokenResult result;
    try {
      result = await _oidc.refresh(refreshToken);
    } on OidcException catch (e) {
      if (e.failure == OidcFailure.grantRejected) {
        _log.info('refresh token rejected (${e.code}); session ended');
        await _endSession(epoch);
        return null;
      }
      // Offline is not signed out.
      _log.warning('refresh failed: $e; keeping the tokens');
      throw _toAuthException(e);
    }
    if (epoch != _epoch) {
      // Signed out (or in again) while the request was under way. The result
      // belongs to a session that is over; make sure it is over at the
      // server too.
      final orphan = result.refreshToken;
      if (orphan != null) {
        unawaited(_revokeQuietly(orphan));
      }
      return _tokens;
    }
    final tokens = _merge(
      result,
      idToken: current.idToken,
      refreshToken: refreshToken,
    );
    // Store first: the old refresh token is already useless at the server.
    await _store.write(tokens);
    _tokens = tokens;
    // A fresh id token may carry changed claims (e-mail verified, new name).
    final claims = IdTokenClaims.tryParse(tokens.idToken);
    if (claims != null && claims.sub == _currentSub) {
      _setState(_signedIn(claims));
    }
    return tokens;
  }

  @override
  Future<void> signOut() async {
    final subBefore = _currentSub;
    if (subBefore != null && _onBeforeSignOut != null) {
      // While the access token still works: unregister push, send analytics.
      // The hook is bounded in time and must not be able to stop a sign-out.
      try {
        await _onBeforeSignOut(subBefore);
      } on Object catch (e) {
        _log.error('before-sign-out hook failed (${e.runtimeType})');
      }
    }
    final tokens = _tokens;
    final sub = _currentSub;
    _epoch++;
    _tokens = null;
    try {
      await _store.clear();
    } on Object catch (e) {
      _log.error('clearing the token store failed (${e.runtimeType})');
    }
    _setState(const SignedOut());
    _log.info('signed out');

    if (sub != null && _onSignedOut != null) {
      try {
        await _onSignedOut(sub);
      } on Object catch (e) {
        _log.error('signed-out hook failed (${e.runtimeType})');
      }
    }
    final refreshToken = tokens?.refreshToken;
    if (refreshToken != null) {
      await _revokeQuietly(refreshToken);
    }
  }

  /// Closes the state stream. The repository lives as long as the app; this
  /// is for tests and provider disposal.
  Future<void> dispose() => _states.close();

  /// The session is over at the server. Cached data and drafts stay: the same
  /// person will most likely sign in again, and all of it is scoped by
  /// subject anyway.
  Future<void> _endSession(int epoch) async {
    if (epoch != _epoch) {
      return;
    }
    _epoch++;
    _tokens = null;
    await _store.clear();
    _setState(const SignedOut());
  }

  Future<void> _revokeQuietly(String refreshToken) async {
    try {
      await _oidc.revoke(refreshToken).timeout(revokeTimeout);
    } on Object catch (e) {
      // The local sign-out stands. The token is gone from the device; its
      // server-side session ends when it times out, or from the account
      // console.
      _log.warning('revocation failed (${e.runtimeType})');
    }
  }

  Tokens _merge(
    OidcTokenResult result, {
    required String idToken,
    required String? refreshToken,
  }) {
    final now = _now().toUtc();
    return Tokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken ?? refreshToken,
      idToken: result.idToken ?? idToken,
      // Without an expiry the token counts as expired at once, which costs a
      // refresh per request but never sends a dead token on purpose.
      expiresAt: result.accessTokenExpiry?.toUtc() ?? now,
      obtainedAt: now,
    );
  }

  String? get _currentSub => switch (_state) {
    SignedIn(:final sub) => sub,
    SignedOut() => null,
  };

  void _setState(AuthState next) {
    if (next == _state) {
      return;
    }
    _state = next;
    if (!_states.isClosed) {
      _states.add(next);
    }
  }

  static SignedIn _signedIn(IdTokenClaims claims) => SignedIn(
    claims.sub,
    email: claims.email,
    emailVerified: claims.emailVerified,
    name: claims.name,
  );

  static AuthException _toAuthException(OidcException e) => AuthException(
    e.failure == OidcFailure.transport
        ? AuthErrorKind.network
        : AuthErrorKind.server,
    e.code,
  );
}
