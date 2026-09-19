// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/auth/app_auth_repository.dart';
import 'package:bogner_chess/core/auth/auth_providers.dart';
import 'package:bogner_chess/core/auth/auth_repository.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/auth/fake_auth_repository.dart';
import 'package:bogner_chess/core/auth/install_marker.dart';
import 'package:bogner_chess/core/auth/token_store.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_oidc.dart';
import '../../helpers/pump_app.dart';
import '../storage/test_database.dart';

void main() {
  setUp(() => Log.sink = (_) {});
  tearDown(Log.resetSink);

  ProviderContainer container(Env env, [List<Override> overrides = const []]) {
    final container = ProviderContainer(
      overrides: [envProvider.overrideWithValue(env), ...overrides],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('FakeAuthRepository', () {
    test('starts signed in as the fake user with the fake token', () async {
      final repository = FakeAuthRepository();
      expect(repository.state, FakeAuthRepository.fakeUser);
      expect((repository.state as SignedIn).sub, kFakeAuthSub);
      expect(await repository.accessToken(), kFakeAccessToken);
      expect(await repository.forceRefresh(), kFakeAccessToken);
      await repository.restore();
      expect(repository.state, isA<SignedIn>());
    });

    test('signOut and signIn toggle the state', () async {
      final wiped = <String>[];
      final repository = FakeAuthRepository(
        onSignedOut: (sub) async => wiped.add(sub),
      );
      final states = <AuthState>[];
      repository.states.listen(states.add);

      await repository.signOut();
      expect(await repository.accessToken(), isNull);
      await repository.signIn(register: true, idpHint: 'google');

      expect(states, [const SignedOut(), FakeAuthRepository.fakeUser]);
      expect(wiped, [kFakeAuthSub]);
      expect(repository.signInCalls, [(register: true, idpHint: 'google')]);
    });

    test('can start signed out and can be told to fail', () async {
      final repository = FakeAuthRepository(
        signedIn: false,
        signInError: const AuthException(AuthErrorKind.network),
      );
      expect(repository.state, const SignedOut());
      await expectLater(repository.signIn(), throwsA(isA<AuthException>()));
      expect(repository.state, const SignedOut());
    });
  });

  group('authRepositoryProvider', () {
    test('fake auth gives the fake repository, signed in', () {
      final c = container(testEnv());
      expect(c.read(authRepositoryProvider), isA<FakeAuthRepository>());
      expect(c.read(authStateProvider), FakeAuthRepository.fakeUser);
    });

    test('real auth gives the AppAuth repository, signed out', () {
      final c = container(testEnv(envName: 'dev', authMode: AuthMode.real));
      expect(c.read(authRepositoryProvider), isA<AppAuthRepository>());
      expect(c.read(authStateProvider), const SignedOut());
    });

    test('fake auth with the prod configuration is refused', () {
      final c = container(testEnv(envName: 'prod'));
      expect(() => c.read(authRepositoryProvider), throwsA(anything));
    });
  });

  group('authStateProvider', () {
    test('follows the real repository through sign-in and sign-out', () async {
      final clock = TestClock();
      final oidc = FakeOidcClient(clock);
      final c = container(testEnv(envName: 'dev', authMode: AuthMode.real), [
        oidcClientProvider.overrideWithValue(oidc),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        installMarkerProvider.overrideWithValue(
          InMemoryInstallMarker(isSet: true),
        ),
        appDatabaseProvider.overrideWithValue(_db(clock)),
      ]);
      final seen = <AuthState>[];
      c.listen(authStateProvider, (_, next) => seen.add(next));

      await c.read(authRepositoryProvider).signIn();
      expect(c.read(authStateProvider), isA<SignedIn>());
      expect((c.read(authStateProvider) as SignedIn).sub, 'sub-alice');

      await c.read(authRepositoryProvider).signOut();
      expect(c.read(authStateProvider), const SignedOut());
      expect(seen, [isA<SignedIn>(), const SignedOut()]);
    });

    test('sign-out wipes the cached data of that user, keeps the drafts and '
        'other users', () async {
      final clock = TestClock();
      final db = _db(clock);
      final c = container(testEnv(), [
        appDatabaseProvider.overrideWithValue(db),
      ]);

      for (final owner in [kFakeAuthSub, 'somebody-else']) {
        await db.draftsDao.create(owner, pgn: '1. e4');
        await db.analysisCacheDao.put(
          owner,
          'game-$owner',
          schemaVersion: 1,
          schemaMinor: 0,
          payload: '{}',
        );
      }

      await c.read(authRepositoryProvider).signOut();

      expect(c.read(authStateProvider), const SignedOut());
      expect(await db.draftsDao.watchAll(kFakeAuthSub).first, hasLength(1));
      expect(
        await db.analysisCacheDao.get(kFakeAuthSub, 'game-$kFakeAuthSub'),
        isNull,
      );
      expect(
        await db.analysisCacheDao.get('somebody-else', 'game-somebody-else'),
        isNotNull,
      );
    });
  });
}

AppDatabase _db(TestClock clock) {
  final db = openTestDatabase(FakeClock(clock()));
  addTearDown(db.close);
  return db;
}
