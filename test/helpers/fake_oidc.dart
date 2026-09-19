// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:convert';

import 'package:bogner_chess/core/auth/oidc_client.dart';
import 'package:bogner_chess/core/auth/tokens.dart';

/// An unsigned JWT with [claims] as payload. The app never verifies the
/// signature, so the third part is filler.
String makeJwt(Map<String, Object?> claims) {
  String part(Object? json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part(claims)}.c2ln';
}

String aliceIdToken({bool emailVerified = true, String name = 'Alice A.'}) =>
    makeJwt({
      'sub': 'sub-alice',
      'email': 'alice@example.test',
      'email_verified': emailVerified,
      'name': name,
    });

/// A clock that only moves when the test says so.
class TestClock {
  TestClock([DateTime? start]) : _now = start ?? DateTime.utc(2026, 9, 19, 12);

  DateTime _now;

  DateTime call() => _now;

  void advance(Duration by) => _now = _now.add(by);
}

typedef AuthorizeCall = ({bool register, String? idpHint});

/// A scriptable [OidcClient]. Each handler defaults to a plausible success;
/// a test replaces the one it cares about.
class FakeOidcClient implements OidcClient {
  FakeOidcClient(this.clock);

  final TestClock clock;

  final List<AuthorizeCall> authorizeCalls = [];
  final List<String> refreshCalls = [];
  final List<String> revokeCalls = [];

  Future<OidcTokenResult> Function(AuthorizeCall call)? onAuthorize;
  Future<OidcTokenResult> Function(String refreshToken)? onRefresh;
  Future<void> Function(String refreshToken)? onRevoke;

  OidcTokenResult tokens(
    int n, {
    String? idToken,
    Duration lifetime = const Duration(minutes: 5),
    bool withRefreshToken = true,
  }) => OidcTokenResult(
    accessToken: 'access-$n',
    refreshToken: withRefreshToken ? 'refresh-$n' : null,
    idToken: idToken,
    accessTokenExpiry: clock().add(lifetime),
  );

  @override
  Future<OidcTokenResult> authorize({bool register = false, String? idpHint}) {
    final call = (register: register, idpHint: idpHint);
    authorizeCalls.add(call);
    return onAuthorize?.call(call) ??
        Future.value(tokens(1, idToken: aliceIdToken()));
  }

  @override
  Future<OidcTokenResult> refresh(String refreshToken) {
    refreshCalls.add(refreshToken);
    return onRefresh?.call(refreshToken) ??
        Future.value(tokens(refreshCalls.length + 1));
  }

  @override
  Future<void> revoke(String refreshToken) {
    revokeCalls.add(refreshToken);
    return onRevoke?.call(refreshToken) ?? Future.value();
  }
}
