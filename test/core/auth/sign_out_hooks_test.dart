// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/auth/app_auth_repository.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/auth/fake_auth_repository.dart';
import 'package:bogner_chess/core/auth/install_marker.dart';
import 'package:bogner_chess/core/auth/sign_out_hooks.dart';
import 'package:bogner_chess/core/auth/token_store.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_oidc.dart';

void main() {
  setUp(() => Log.sink = (_) {});
  tearDown(Log.resetSink);

  group('BeforeSignOutHooks', () {
    test('runs the hooks in order, with the subject', () async {
      final calls = <String>[];
      final hooks = BeforeSignOutHooks()
        ..add((sub) async => calls.add('first:$sub'))
        ..add((sub) async => calls.add('second:$sub'));
      await hooks.run('sub-1');
      expect(calls, ['first:sub-1', 'second:sub-1']);
    });

    test(
      'a failing hook does not stop the others, and nothing is thrown',
      () async {
        final calls = <String>[];
        final hooks = BeforeSignOutHooks()
          ..add((_) async => throw StateError('offline'))
          ..add((_) async => calls.add('second'));
        await expectLater(hooks.run('sub-1'), completes);
        expect(calls, ['second']);
      },
    );

    test('a hook that hangs is given up on', () async {
      final calls = <String>[];
      final hooks =
          BeforeSignOutHooks(timeout: const Duration(milliseconds: 20))
            ..add((_) => Completer<void>().future)
            ..add((_) async => calls.add('second'));
      await hooks.run('sub-1');
      expect(calls, ['second']);
    });

    test('a removed hook is not called', () async {
      final calls = <String>[];
      final hooks = BeforeSignOutHooks();
      hooks.add((_) async => calls.add('removed'))();
      await hooks.run('sub-1');
      expect(calls, isEmpty);
    });
  });

  group('the repositories call the hook while the session still works', () {
    final clock = TestClock();

    test(
      'AppAuthRepository: before the tokens are cleared, then the wipe',
      () async {
        final store = InMemoryTokenStore();
        final order = <String>[];
        late AppAuthRepository repository;
        repository = AppAuthRepository(
          oidc: FakeOidcClient(clock),
          store: store,
          installMarker: InMemoryInstallMarker(isSet: true),
          onBeforeSignOut: (sub) async {
            final token = await repository.accessToken();
            order.add(
              'before:$sub:${token != null}:${store.tokens != null}:'
              '${repository.state is SignedIn}',
            );
          },
          onSignedOut: (sub) async =>
              order.add('after:$sub:${store.tokens != null}'),
        );
        addTearDown(repository.dispose);
        await repository.signIn();
        final sub = (repository.state as SignedIn).sub;

        await repository.signOut();

        expect(order, ['before:$sub:true:true:true', 'after:$sub:false']);
        expect(repository.state, const SignedOut());
      },
    );

    test('AppAuthRepository: a failing hook still signs out', () async {
      final repository = AppAuthRepository(
        oidc: FakeOidcClient(clock),
        store: InMemoryTokenStore(),
        installMarker: InMemoryInstallMarker(isSet: true),
        now: clock.call,
        onBeforeSignOut: (_) async => throw StateError('offline'),
      );
      addTearDown(repository.dispose);
      await repository.signIn();
      await repository.signOut();
      expect(repository.state, const SignedOut());
    });

    test(
      'AppAuthRepository: signed out already, the hook is not called',
      () async {
        var calls = 0;
        final repository = AppAuthRepository(
          oidc: FakeOidcClient(clock),
          store: InMemoryTokenStore(),
          installMarker: InMemoryInstallMarker(isSet: true),
          onBeforeSignOut: (_) async => calls++,
        );
        addTearDown(repository.dispose);
        await repository.signOut();
        expect(calls, 0);
      },
    );

    test('FakeAuthRepository: before the state changes', () async {
      final order = <String>[];
      late FakeAuthRepository repository;
      repository = FakeAuthRepository(
        onBeforeSignOut: (sub) async =>
            order.add('before:$sub:${repository.state is SignedIn}'),
        onSignedOut: (sub) async => order.add('after:$sub'),
      );
      addTearDown(repository.dispose);
      await repository.signOut();
      expect(order, ['before:$kFakeAuthSub:true', 'after:$kFakeAuthSub']);
    });
  });
}
