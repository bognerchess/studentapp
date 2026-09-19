// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/auth/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_oidc.dart';

void main() {
  group('IdTokenClaims.tryParse', () {
    test('reads sub, email, email_verified and name', () {
      final claims = IdTokenClaims.tryParse(
        makeJwt({
          'iss': 'https://id.example.test/realms/test',
          'sub': 'f3a1',
          'email': 'someone@example.test',
          'email_verified': false,
          'name': 'Some One',
          'preferred_username': 'someone',
          'unknown_claim': [1, 2, 3],
        }),
      )!;
      expect(claims.sub, 'f3a1');
      expect(claims.email, 'someone@example.test');
      expect(claims.emailVerified, isFalse);
      expect(claims.name, 'Some One');
    });

    test('only sub is required', () {
      final claims = IdTokenClaims.tryParse(makeJwt({'sub': 'f3a1'}))!;
      expect(claims.email, isNull);
      expect(claims.emailVerified, isNull);
      expect(claims.name, isNull);
    });

    test('falls back to preferred_username, ignores blank values', () {
      final claims = IdTokenClaims.tryParse(
        makeJwt({'sub': 's', 'name': '  ', 'preferred_username': 'magnus'}),
      )!;
      expect(claims.name, 'magnus');
    });

    test('accepts email_verified as a string', () {
      expect(
        IdTokenClaims.tryParse(makeJwt({'sub': 's', 'email_verified': 'true'}))!
            .emailVerified,
        isTrue,
      );
    });

    test('decodes UTF-8 and unpadded base64url', () {
      // Four lengths, so that every padding case (a JWT leaves the padding
      // out) occurs.
      for (final name in ['Jürgen', 'Jürgen M', 'Jürgen Mü', 'Jürgen Müñ']) {
        final claims = IdTokenClaims.tryParse(
          makeJwt({'sub': 's', 'name': name}),
        )!;
        expect(claims.name, name);
      }
    });

    test('returns null for anything that is not a JWT with a subject', () {
      final noSub = makeJwt({'email': 'x@example.test'});
      final emptySub = makeJwt({'sub': ''});
      final numberSub = makeJwt({'sub': 42});
      final arrayPayload = 'e30.${base64Url.encode(utf8.encode('[1]'))}.x';
      for (final jwt in [
        '',
        'abc',
        'a.b',
        'a.b.c.d',
        'a.!!!.c',
        'e30.bm90LWpzb24.x',
        arrayPayload,
        noSub,
        emptySub,
        numberSub,
      ]) {
        expect(IdTokenClaims.tryParse(jwt), isNull, reason: jwt);
      }
    });
  });

  group('Tokens', () {
    final obtained = DateTime.utc(2026, 9, 19, 12);
    final tokens = Tokens(
      accessToken: 'a',
      refreshToken: 'r',
      idToken: 'i',
      expiresAt: obtained.add(const Duration(minutes: 5)),
      obtainedAt: obtained,
    );

    test('is fresh while more than the margin is left', () {
      expect(tokens.isFreshAt(obtained), isTrue);
      expect(
        tokens.isFreshAt(obtained.add(const Duration(seconds: 269))),
        isTrue,
      );
      expect(
        tokens.isFreshAt(obtained.add(const Duration(seconds: 270))),
        isFalse,
      );
      expect(tokens.isFreshAt(obtained.add(const Duration(hours: 1))), isFalse);
    });

    test('tolerates a clock that is a little behind, not one set back', () {
      expect(
        tokens.isFreshAt(obtained.subtract(const Duration(seconds: 59))),
        isTrue,
      );
      expect(
        tokens.isFreshAt(obtained.subtract(const Duration(minutes: 2))),
        isFalse,
      );
    });

    test('round-trips through JSON', () {
      final copy = Tokens.fromJson(
        jsonDecode(jsonEncode(tokens.toJson())) as Map<String, Object?>,
      );
      expect(copy.accessToken, 'a');
      expect(copy.refreshToken, 'r');
      expect(copy.idToken, 'i');
      expect(copy.expiresAt, tokens.expiresAt);
      expect(copy.obtainedAt, tokens.obtainedAt);
    });

    test('a missing refresh token round-trips as null', () {
      final json = tokens.toJson()..['refresh_token'] = null;
      expect(Tokens.fromJson(json).refreshToken, isNull);
    });

    test('rejects an unknown shape', () {
      expect(() => Tokens.fromJson({}), throwsFormatException);
      expect(
        () => Tokens.fromJson(tokens.toJson()..['expires_at'] = 'soon'),
        throwsFormatException,
      );
    });

    test('toString never shows a token', () {
      expect(tokens.toString(), 'Tokens(***)');
      expect(
        const OidcTokenResult(accessToken: 'secret').toString(),
        isNot(contains('secret')),
      );
    });
  });

  group('AuthState', () {
    test('SignedIn compares all claims and hides them', () {
      const a = SignedIn('s', email: 'e@example.test', emailVerified: false);
      expect(
        a,
        const SignedIn('s', email: 'e@example.test', emailVerified: false),
      );
      expect(
        a,
        isNot(
          const SignedIn('s', email: 'e@example.test', emailVerified: true),
        ),
      );
      expect(a, isNot(const SignedIn('s')));
      expect(a.toString(), 'SignedIn');
    });
  });
}
