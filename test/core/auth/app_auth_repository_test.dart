// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/auth/app_auth_repository.dart';
import 'package:bogner_chess/core/auth/auth_repository.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/auth/install_marker.dart';
import 'package:bogner_chess/core/auth/oidc_client.dart';
import 'package:bogner_chess/core/auth/token_store.dart';
import 'package:bogner_chess/core/auth/tokens.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_oidc.dart';

void main() {
  late TestClock clock;
  late FakeOidcClient oidc;
  late InMemoryTokenStore store;
  late InMemoryInstallMarker marker;
  late List<String> signedOutSubs;
  late List<LogRecord> logs;

  AppAuthRepository build({Duration? refreshTimeout, Duration? revokeTimeout}) {
    final repository = AppAuthRepository(
      oidc: oidc,
      store: store,
      installMarker: marker,
      onSignedOut: (sub) async => signedOutSubs.add(sub),
      now: clock.call,
      refreshTimeout: refreshTimeout ?? const Duration(seconds: 20),
      revokeTimeout: revokeTimeout ?? const Duration(seconds: 8),
    );
    addTearDown(repository.dispose);
    return repository;
  }

  Tokens storedTokens({
    Duration lifetime = const Duration(minutes: 5),
    String? idToken,
    String? refreshToken = 'refresh-0',
  }) => Tokens(
    accessToken: 'access-0',
    refreshToken: refreshToken,
    idToken: idToken ?? aliceIdToken(),
    expiresAt: clock().add(lifetime),
    obtainedAt: clock(),
  );

  /// A repository that is signed in as Alice with `access-1`/`refresh-1`,
  /// valid for five minutes.
  Future<AppAuthRepository> signedIn({Duration? refreshTimeout}) async {
    final repository = build(refreshTimeout: refreshTimeout);
    await repository.signIn();
    expect(repository.state, isA<SignedIn>());
    return repository;
  }

  setUp(() {
    clock = TestClock();
    oidc = FakeOidcClient(clock);
    store = InMemoryTokenStore();
    marker = InMemoryInstallMarker(isSet: true);
    signedOutSubs = [];
    logs = [];
    Log.sink = logs.add;
  });

  tearDown(Log.resetSink);

  group('signIn', () {
    test('stores the tokens and publishes the claims', () async {
      final repository = build();
      final states = <AuthState>[];
      repository.states.listen(states.add);

      await repository.signIn();

      const expected = SignedIn(
        'sub-alice',
        email: 'alice@example.test',
        emailVerified: true,
        name: 'Alice A.',
      );
      expect(repository.state, expected);
      expect(states, [expected]);
      expect(store.tokens?.accessToken, 'access-1');
      expect(store.tokens?.refreshToken, 'refresh-1');
      expect(await repository.accessToken(), 'access-1');
      expect(oidc.authorizeCalls, [(register: false, idpHint: null)]);
    });

    test('passes register and idpHint on', () async {
      final repository = build();
      await repository.signIn(register: true);
      await repository.signIn(idpHint: 'apple');
      expect(oidc.authorizeCalls, [
        (register: true, idpHint: null),
        (register: false, idpHint: 'apple'),
      ]);
    });

    test('a cancelled sheet is not an error and changes nothing', () async {
      oidc.onAuthorize = (_) async => throw const OidcCancelled();
      final repository = build();
      final states = <AuthState>[];
      repository.states.listen(states.add);

      await repository.signIn();

      expect(repository.state, const SignedOut());
      expect(states, isEmpty);
      expect(store.tokens, isNull);
      expect(
        logs.where((r) => r.level.index >= LogLevel.warning.index),
        isEmpty,
      );
    });

    test('a transport error surfaces as network', () async {
      oidc.onAuthorize = (_) async =>
          throw const OidcException(OidcFailure.transport, 'x');
      final repository = build();
      await expectLater(
        repository.signIn(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.kind,
            'kind',
            AuthErrorKind.network,
          ),
        ),
      );
      expect(repository.state, const SignedOut());
    });

    test('any other failure surfaces as server', () async {
      oidc.onAuthorize = (_) async =>
          throw const OidcException(OidcFailure.grantRejected, 'invalid_grant');
      final repository = build();
      await expectLater(
        repository.signIn(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.kind,
            'kind',
            AuthErrorKind.server,
          ),
        ),
      );
    });

    test('an answer without a usable id token is refused', () async {
      oidc.onAuthorize = (_) async => oidc.tokens(1, idToken: 'not-a-jwt');
      final repository = build();
      await expectLater(repository.signIn(), throwsA(isA<AuthException>()));
      expect(repository.state, const SignedOut());
      expect(store.tokens, isNull);
    });

    test('a second tap joins the sheet that is already open', () async {
      final gate = Completer<void>();
      oidc.onAuthorize = (_) async {
        await gate.future;
        return oidc.tokens(1, idToken: aliceIdToken());
      };
      final repository = build();
      final first = repository.signIn();
      final second = repository.signIn(idpHint: 'google');
      gate.complete();
      await Future.wait([first, second]);
      expect(oidc.authorizeCalls, hasLength(1));
    });
  });

  group('accessToken', () {
    test('is null when signed out', () async {
      final repository = build();
      expect(await repository.accessToken(), isNull);
      expect(await repository.forceRefresh(), isNull);
      expect(oidc.refreshCalls, isEmpty);
    });

    test('uses the cached token while it has more than 30 s left', () async {
      final repository = await signedIn();
      clock.advance(const Duration(minutes: 4, seconds: 29));
      expect(await repository.accessToken(), 'access-1');
      expect(oidc.refreshCalls, isEmpty);
    });

    test('refreshes once 30 s or less are left', () async {
      final repository = await signedIn();
      clock.advance(const Duration(minutes: 4, seconds: 30));
      expect(await repository.accessToken(), 'access-2');
      expect(oidc.refreshCalls, ['refresh-1']);
      // The rotated refresh token is the one stored and used next.
      expect(store.tokens?.refreshToken, 'refresh-2');
      clock.advance(const Duration(minutes: 5));
      expect(await repository.accessToken(), 'access-3');
      expect(oidc.refreshCalls, ['refresh-1', 'refresh-2']);
    });

    test('refreshes when the device clock was set back', () async {
      final repository = await signedIn();
      clock.advance(const Duration(hours: -2));
      expect(await repository.accessToken(), 'access-2');
    });

    test('a token without an expiry is refreshed before every use', () async {
      oidc.onAuthorize = (_) async => OidcTokenResult(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        idToken: aliceIdToken(),
      );
      final repository = await signedIn();
      expect(await repository.accessToken(), 'access-2');
    });

    test('10 concurrent calls make exactly one refresh', () async {
      final repository = await signedIn();
      clock.advance(const Duration(minutes: 10));
      final gate = Completer<void>();
      oidc.onRefresh = (_) async {
        await gate.future;
        return oidc.tokens(2);
      };

      final calls = [for (var i = 0; i < 10; i++) repository.accessToken()];
      // Let every caller reach the refresh before it answers.
      await pumpEventQueue();
      expect(oidc.refreshCalls, hasLength(1));
      gate.complete();

      expect(await Future.wait(calls), List.filled(10, 'access-2'));
      expect(oidc.refreshCalls, ['refresh-1']);
      expect(store.writes, 2, reason: 'sign-in and one refresh');
    });

    test('accessToken and forceRefresh share the one refresh', () async {
      final repository = await signedIn();
      clock.advance(const Duration(minutes: 10));
      final gate = Completer<void>();
      oidc.onRefresh = (_) async {
        await gate.future;
        return oidc.tokens(2);
      };
      final calls = [
        repository.accessToken(),
        repository.forceRefresh(),
        repository.forceRefresh(rejectedToken: 'access-1'),
      ];
      await pumpEventQueue();
      gate.complete();
      expect(await Future.wait(calls), List.filled(3, 'access-2'));
      expect(oidc.refreshCalls, hasLength(1));
    });

    test('after a refresh has finished, the next one can start', () async {
      final repository = await signedIn();
      await repository.forceRefresh();
      await repository.forceRefresh();
      expect(oidc.refreshCalls, ['refresh-1', 'refresh-2']);
    });

    test('keeps refresh and id token when the answer omits them', () async {
      final repository = await signedIn();
      oidc.onRefresh = (_) async => oidc.tokens(2, withRefreshToken: false);
      await repository.forceRefresh();
      expect(store.tokens?.accessToken, 'access-2');
      expect(store.tokens?.refreshToken, 'refresh-1');
      expect(store.tokens?.idToken, aliceIdToken());
    });

    test('a new id token updates the claims (e-mail verified)', () async {
      oidc.onAuthorize = (_) async =>
          oidc.tokens(1, idToken: aliceIdToken(emailVerified: false));
      final repository = await signedIn();
      expect((repository.state as SignedIn).emailVerified, isFalse);

      oidc.onRefresh = (_) async => oidc.tokens(2, idToken: aliceIdToken());
      await repository.forceRefresh();

      expect((repository.state as SignedIn).emailVerified, isTrue);
    });
  });

  group('forceRefresh', () {
    test('refreshes although the cached token looks valid', () async {
      final repository = await signedIn();
      expect(await repository.forceRefresh(), 'access-2');
      expect(oidc.refreshCalls, ['refresh-1']);
    });

    test(
      'does not refresh again for a token that is already replaced',
      () async {
        final repository = await signedIn();
        await repository.forceRefresh(rejectedToken: 'access-1');
        // Four more requests that were sent with access-1 come back with 401.
        for (var i = 0; i < 4; i++) {
          expect(
            await repository.forceRefresh(rejectedToken: 'access-1'),
            'access-2',
          );
        }
        expect(oidc.refreshCalls, hasLength(1));
      },
    );
  });

  group('refresh failures', () {
    for (final code in ['invalid_grant', 'invalid_token']) {
      test('$code ends the session and keeps the local data', () async {
        final repository = await signedIn();
        final states = <AuthState>[];
        repository.states.listen(states.add);
        oidc.onRefresh = (_) async =>
            throw OidcException(OidcFailure.grantRejected, code);

        expect(await repository.forceRefresh(), isNull);

        expect(repository.state, const SignedOut());
        expect(states, [const SignedOut()]);
        expect(store.tokens, isNull);
        expect(await repository.accessToken(), isNull);
        // Not an explicit sign-out: nothing is wiped, nothing is revoked.
        expect(signedOutSubs, isEmpty);
        expect(oidc.revokeCalls, isEmpty);
      });
    }

    test('every concurrent caller sees the ended session as null', () async {
      final repository = await signedIn();
      clock.advance(const Duration(minutes: 10));
      oidc.onRefresh = (_) async =>
          throw const OidcException(OidcFailure.grantRejected, 'invalid_grant');
      final calls = [for (var i = 0; i < 5; i++) repository.accessToken()];
      expect(await Future.wait(calls), List.filled(5, null));
      expect(oidc.refreshCalls, hasLength(1));
    });

    test('a transport error keeps the tokens and surfaces', () async {
      final repository = await signedIn();
      clock.advance(const Duration(minutes: 10));
      oidc.onRefresh = (_) async =>
          throw const OidcException(OidcFailure.transport, 'x');

      await expectLater(
        repository.accessToken(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.kind,
            'kind',
            AuthErrorKind.network,
          ),
        ),
      );

      expect(repository.state, isA<SignedIn>());
      expect(store.tokens?.refreshToken, 'refresh-1');

      // Back online: the same refresh token still works.
      oidc.onRefresh = null;
      expect(await repository.accessToken(), 'access-3');
      expect(oidc.refreshCalls, ['refresh-1', 'refresh-1']);
    });

    test('a server error keeps the tokens and surfaces', () async {
      final repository = await signedIn();
      oidc.onRefresh = (_) async =>
          throw const OidcException(OidcFailure.other, 'token_failed');
      await expectLater(
        repository.forceRefresh(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.kind,
            'kind',
            AuthErrorKind.server,
          ),
        ),
      );
      expect(repository.state, isA<SignedIn>());
      expect(store.tokens, isNotNull);
    });

    test('a caller times out, the late answer is still stored', () async {
      final repository = await signedIn(
        refreshTimeout: const Duration(milliseconds: 20),
      );
      final gate = Completer<void>();
      oidc.onRefresh = (_) async {
        await gate.future;
        return oidc.tokens(2);
      };

      await expectLater(
        repository.forceRefresh(),
        throwsA(
          isA<AuthException>()
              .having((e) => e.kind, 'kind', AuthErrorKind.network)
              .having((e) => e.code, 'code', 'timeout'),
        ),
      );
      expect(repository.state, isA<SignedIn>());
      expect(store.tokens?.refreshToken, 'refresh-1');

      // The request was not cancelled. Its answer rotates the tokens; losing
      // it would end the session at the next refresh.
      gate.complete();
      await pumpEventQueue();
      expect(store.tokens?.refreshToken, 'refresh-2');
      expect(await repository.accessToken(), 'access-2');
      expect(oidc.refreshCalls, hasLength(1));
    });

    test('an expired token without a refresh token ends the session', () async {
      oidc.onAuthorize = (_) async =>
          oidc.tokens(1, idToken: aliceIdToken(), withRefreshToken: false);
      final repository = await signedIn();
      clock.advance(const Duration(minutes: 10));
      expect(await repository.accessToken(), isNull);
      expect(repository.state, const SignedOut());
      expect(oidc.refreshCalls, isEmpty);
    });
  });

  group('restore', () {
    test('first launch of an installation wipes the Keychain', () async {
      marker = InMemoryInstallMarker();
      store = InMemoryTokenStore(storedTokens());
      final repository = build();

      await repository.restore();

      expect(repository.state, const SignedOut());
      expect(store.tokens, isNull);
      expect(await marker.isSet(), isTrue);
    });

    test('a later launch keeps the tokens', () async {
      store = InMemoryTokenStore(storedTokens());
      final repository = build();

      await repository.restore();

      expect(
        repository.state,
        const SignedIn(
          'sub-alice',
          email: 'alice@example.test',
          emailVerified: true,
          name: 'Alice A.',
        ),
      );
      expect(store.clears, 0);
      expect(await repository.accessToken(), 'access-0');
    });

    test('without stored tokens the state is signed out', () async {
      final repository = build();
      await repository.restore();
      expect(repository.state, const SignedOut());
    });

    test(
      'makes no request, even with an expired token (offline start)',
      () async {
        store = InMemoryTokenStore(
          storedTokens(lifetime: const Duration(minutes: -30)),
        );
        final repository = build();

        await repository.restore();

        expect(repository.state, isA<SignedIn>());
        expect(oidc.refreshCalls, isEmpty);
        // The first request renews it.
        expect(await repository.accessToken(), 'access-2');
        expect(oidc.refreshCalls, ['refresh-0']);
      },
    );

    test('an unreadable id token signs out and clears the store', () async {
      store = InMemoryTokenStore(storedTokens(idToken: 'garbage'));
      final repository = build();
      await repository.restore();
      expect(repository.state, const SignedOut());
      expect(store.tokens, isNull);
    });

    test('never throws: a failing store means signed out', () async {
      final repository = AppAuthRepository(
        oidc: oidc,
        store: _ThrowingStore(),
        installMarker: marker,
        now: clock.call,
      );
      addTearDown(repository.dispose);
      await repository.restore();
      expect(repository.state, const SignedOut());
    });
  });

  group('signOut', () {
    test('clears, publishes, wipes the owner and revokes', () async {
      final repository = await signedIn();
      final states = <AuthState>[];
      repository.states.listen(states.add);

      await repository.signOut();

      expect(states, [const SignedOut()]);
      expect(store.tokens, isNull);
      expect(signedOutSubs, ['sub-alice']);
      expect(oidc.revokeCalls, ['refresh-1']);
      expect(await repository.accessToken(), isNull);
    });

    test('a failing revocation still signs out locally', () async {
      final repository = await signedIn();
      oidc.onRevoke = (_) async =>
          throw const OidcException(OidcFailure.transport, 'io');

      await repository.signOut();

      expect(repository.state, const SignedOut());
      expect(store.tokens, isNull);
      expect(signedOutSubs, ['sub-alice']);
    });

    test('a hanging revocation does not hold the sign-out for ever', () async {
      final repository = build(revokeTimeout: const Duration(milliseconds: 20));
      await repository.signIn();
      oidc.onRevoke = (_) => Completer<void>().future;

      await repository.signOut();

      expect(repository.state, const SignedOut());
    });

    test('a failing wipe hook still signs out and revokes', () async {
      final repository = AppAuthRepository(
        oidc: oidc,
        store: store,
        installMarker: marker,
        onSignedOut: (_) async => throw StateError('database is gone'),
        now: clock.call,
      );
      addTearDown(repository.dispose);
      await repository.signIn();

      await repository.signOut();

      expect(repository.state, const SignedOut());
      expect(oidc.revokeCalls, ['refresh-1']);
    });

    test('when signed out already it does nothing', () async {
      final repository = build();
      await repository.signOut();
      expect(signedOutSubs, isEmpty);
      expect(oidc.revokeCalls, isEmpty);
    });

    test('a refresh that finishes after the sign-out is discarded', () async {
      final repository = await signedIn();
      final gate = Completer<void>();
      oidc.onRefresh = (_) async {
        await gate.future;
        return oidc.tokens(2);
      };
      final pending = repository.forceRefresh();
      await pumpEventQueue();

      await repository.signOut();
      gate.complete();

      expect(await pending, isNull);
      expect(repository.state, const SignedOut());
      expect(store.tokens, isNull);
      // Both the old token and the one the late answer brought are revoked.
      await pumpEventQueue();
      expect(oidc.revokeCalls, unorderedEquals(['refresh-1', 'refresh-2']));
    });
  });

  test('nothing that is logged contains a token, subject or e-mail', () async {
    final repository = await signedIn();
    await repository.forceRefresh();
    oidc.onRefresh = (_) async =>
        throw const OidcException(OidcFailure.transport, 'x');
    await expectLater(repository.forceRefresh(), throwsA(anything));
    await repository.signOut();

    expect(logs, isNotEmpty);
    for (final record in logs) {
      final text = '${record.message} ${record.error}';
      for (final secret in ['access-', 'refresh-', 'alice', 'eyJ']) {
        expect(text, isNot(contains(secret)));
      }
    }
  });
}

class _ThrowingStore implements TokenStore {
  @override
  Future<Tokens?> read() async => throw StateError('keychain unavailable');

  @override
  Future<void> write(Tokens tokens) async => throw StateError('keychain');

  @override
  Future<void> clear() async => throw StateError('keychain');
}
