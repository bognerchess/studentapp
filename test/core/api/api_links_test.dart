// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

import 'package:bogner_chess/core/api/config_api.dart';
import 'package:bogner_chess/core/auth/auth_repository.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'api_test_support.dart';

void main() {
  group('headers', () {
    test(
      'every request carries token, tenant, preflight, language, version',
      () async {
        final auth = ScriptedAuthRepository();
        final server = ScriptedHttp([ScriptedHttp.data(kConfigData)]);
        final api = ConfigApi(
          chainExecutor(auth: auth, httpClient: server.client),
        );

        await api.mobileConfig();

        final request = server.requests.single;
        expect(request.method, 'POST');
        expect(request.url, Uri.parse('https://api.example.test/graphql'));
        expect(request.headers['Authorization'], 'Bearer token-1');
        expect(request.headers['X-Tenant-Slug'], 'test-tenant');
        expect(request.headers['GraphQL-preflight'], '1');
        expect(request.headers['Accept-Language'], 'de-CH');
        expect(request.headers['User-Agent'], 'BognerChess-iOS/0.1.0+1');
        expect(request.headers['Content-type'], contains('application/json'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['operationName'], 'MobileConfig');
        expect(body['query'], contains('mobileConfig'));
      },
    );

    test('the language is read for every request', () async {
      var language = 'en-US';
      final server = ScriptedHttp([ScriptedHttp.data(kConfigData)]);
      final api = ConfigApi(
        chainExecutor(
          auth: ScriptedAuthRepository(),
          httpClient: server.client,
          languageTag: () => language,
        ),
      );

      await api.mobileConfig();
      language = 'de-DE';
      await api.mobileConfig();

      expect(
        [for (final r in server.requests) r.headers['Accept-Language']],
        ['en-US', 'de-DE'],
      );
    });
  });

  group('token', () {
    test('signed out: unauthenticated without a network call', () async {
      final auth = ScriptedAuthRepository(token: null);
      final server = ScriptedHttp([ScriptedHttp.data(kConfigData)]);
      final api = ConfigApi(
        chainExecutor(auth: auth, httpClient: server.client),
      );

      await expectLater(
        api.mobileConfig(),
        throwsA(const ApiUnauthenticated()),
      );

      expect(server.requests, isEmpty);
      expect(auth.refreshes, 0);
      expect(auth.signOuts, 0);
    });

    test('a refresh that cannot be made before the request is a network '
        'error, not a sign-out', () async {
      final auth = ScriptedAuthRepository()
        ..accessError = const AuthException(AuthErrorKind.network, 'offline');
      final server = ScriptedHttp([ScriptedHttp.data(kConfigData)]);
      final api = ConfigApi(
        chainExecutor(auth: auth, httpClient: server.client),
      );

      await expectLater(api.mobileConfig(), throwsA(const ApiNetworkError()));

      expect(server.requests, isEmpty);
      expect(auth.signOuts, 0);
      expect(auth.token, 'token-1');
    });

    test(
      'an identity provider error before the request is a server error',
      () async {
        final auth = ScriptedAuthRepository()
          ..accessError = const AuthException(AuthErrorKind.server, 'http_500');
        final api = ConfigApi(
          chainExecutor(auth: auth, httpClient: ScriptedHttp([]).client),
        );

        await expectLater(
          api.mobileConfig(),
          throwsA(
            isA<ApiServerError>().having(
              (e) => e.detail,
              'detail',
              contains('http_500'),
            ),
          ),
        );
        expect(auth.signOuts, 0);
      },
    );
  });

  group('401', () {
    test(
      'one forced refresh with the rejected token, one retry, success',
      () async {
        final auth = ScriptedAuthRepository();
        final server = ScriptedHttp([
          ScriptedHttp.unauthorized(),
          ScriptedHttp.data(kConfigData),
        ]);
        final api = ConfigApi(
          chainExecutor(auth: auth, httpClient: server.client),
        );

        final config = await api.mobileConfig();

        expect(config.minSupportedAppVersion, '0.1.0');
        expect(server.bearerTokens, ['token-1', 'token-2']);
        expect(auth.rejectedTokens, ['token-1']);
        expect(auth.refreshes, 1);
        expect(auth.signOuts, 0);
      },
    );

    test(
      'a second 401 is unauthenticated; no second refresh, no sign-out',
      () async {
        final auth = ScriptedAuthRepository();
        final server = ScriptedHttp([ScriptedHttp.unauthorized()]);
        final api = ConfigApi(
          chainExecutor(auth: auth, httpClient: server.client),
        );

        await expectLater(
          api.mobileConfig(),
          throwsA(const ApiUnauthenticated()),
        );

        expect(server.requests, hasLength(2));
        expect(auth.refreshes, 1);
        expect(auth.signOuts, 0);
      },
    );

    test(
      'the refresh finds the session ended: unauthenticated, no retry',
      () async {
        final auth = ScriptedAuthRepository(refreshed: [null]);
        final server = ScriptedHttp([ScriptedHttp.unauthorized()]);
        final api = ConfigApi(
          chainExecutor(auth: auth, httpClient: server.client),
        );

        await expectLater(
          api.mobileConfig(),
          throwsA(const ApiUnauthenticated()),
        );

        expect(server.requests, hasLength(1));
        expect(auth.refreshes, 1);
        // The repository signs out by itself when the grant is dead. The link
        // never does.
        expect(auth.signOuts, 0);
      },
    );

    test(
      'AuthException from the refresh is a network error, not a sign-out',
      () async {
        final auth = ScriptedAuthRepository()
          ..refreshError = const AuthException(
            AuthErrorKind.network,
            'timeout',
          );
        final server = ScriptedHttp([ScriptedHttp.unauthorized()]);
        final api = ConfigApi(
          chainExecutor(auth: auth, httpClient: server.client),
        );

        await expectLater(api.mobileConfig(), throwsA(const ApiNetworkError()));

        expect(server.requests, hasLength(1));
        expect(auth.signOuts, 0);
        expect(auth.token, 'token-1', reason: 'the user stays signed in');
      },
    );

    test(
      'a server-side AuthException from the refresh is a server error',
      () async {
        final auth = ScriptedAuthRepository()
          ..refreshError = const AuthException(
            AuthErrorKind.server,
            'http_503',
          );
        final server = ScriptedHttp([ScriptedHttp.unauthorized()]);
        final api = ConfigApi(
          chainExecutor(auth: auth, httpClient: server.client),
        );

        await expectLater(api.mobileConfig(), throwsA(isA<ApiServerError>()));
        expect(auth.signOuts, 0);
      },
    );

    test('parallel 401s cause one refresh', () async {
      final auth = ScriptedAuthRepository()
        ..refreshDelay = const Duration(milliseconds: 30);
      final server = ScriptedHttp.by(
        (request) => request.headers['Authorization'] == 'Bearer token-1'
            ? ScriptedHttp.unauthorized()
            : ScriptedHttp.data(kConfigData),
      );
      final api = ConfigApi(
        chainExecutor(auth: auth, httpClient: server.client),
      );

      final configs = await Future.wait([
        for (var i = 0; i < 5; i++) api.mobileConfig(),
      ]);

      expect(configs, hasLength(5));
      expect(auth.refreshes, 1);
      expect(server.requests, hasLength(10));
      expect(auth.rejectedTokens.toSet(), {'token-1'});
    });

    test('a late 401 for a token that was replaced meanwhile does not '
        'refresh again', () async {
      final auth = ScriptedAuthRepository();
      final server = ScriptedHttp([
        ScriptedHttp.unauthorized(),
        ScriptedHttp.data(kConfigData),
      ]);
      final api = ConfigApi(
        chainExecutor(auth: auth, httpClient: server.client),
      );
      await api.mobileConfig();
      expect(auth.refreshes, 1);

      // A request that was sent with token-1 before the refresh and answered
      // after it: the repository hands out token-2 without refreshing.
      final late = ScriptedHttp.by(
        (request) => request.headers['Authorization'] == 'Bearer token-2'
            ? ScriptedHttp.data(kConfigData)
            : ScriptedHttp.unauthorized(),
      );
      final lateApi = ConfigApi(
        chainExecutor(
          auth: _StaleFirst(auth, 'token-1'),
          httpClient: late.client,
        ),
      );
      await lateApi.mobileConfig();
      expect(late.bearerTokens, ['token-1', 'token-2']);
      expect(auth.refreshes, 1);
    });

    test(
      'a GraphQL UNAUTHENTICATED error with status 200 counts as a 401',
      () async {
        final auth = ScriptedAuthRepository();
        final server = ScriptedHttp([
          ScriptedHttp.json({
            'errors': [
              {
                'message': 'The current user is not authorized.',
                'extensions': {'code': 'AUTH_NOT_AUTHENTICATED'},
              },
            ],
          }),
          ScriptedHttp.data(kConfigData),
        ]);
        final api = ConfigApi(
          chainExecutor(auth: auth, httpClient: server.client),
        );

        await api.mobileConfig();

        expect(server.bearerTokens, ['token-1', 'token-2']);
        expect(auth.refreshes, 1);
      },
    );

    test('a 401 with a body that is not JSON is still a 401', () async {
      final auth = ScriptedAuthRepository();
      final server = ScriptedHttp([
        http.Response('<html>Unauthorized</html>', 401),
        ScriptedHttp.data(kConfigData),
      ]);
      final api = ConfigApi(
        chainExecutor(auth: auth, httpClient: server.client),
      );

      await api.mobileConfig();

      expect(auth.refreshes, 1);
      expect(server.requests, hasLength(2));
    });

    test('other statuses are not retried', () async {
      final auth = ScriptedAuthRepository();
      final server = ScriptedHttp([
        ScriptedHttp.json({'x': 1}, status: 403),
      ]);
      final api = ConfigApi(
        chainExecutor(auth: auth, httpClient: server.client),
      );

      await expectLater(
        api.mobileConfig(),
        throwsA(const ApiServerError(statusCode: 403)),
      );
      expect(server.requests, hasLength(1));
      expect(auth.refreshes, 0);
    });
  });
}

/// Hands out a stale token once, like a request that was already on its way
/// when another one refreshed.
class _StaleFirst implements AuthRepository {
  _StaleFirst(this._inner, this._stale);

  final ScriptedAuthRepository _inner;
  final String _stale;
  bool _used = false;

  @override
  Future<String?> accessToken() {
    if (!_used) {
      _used = true;
      return Future.value(_stale);
    }
    return _inner.accessToken();
  }

  @override
  Future<String?> forceRefresh({String? rejectedToken}) =>
      _inner.forceRefresh(rejectedToken: rejectedToken);

  @override
  AuthState get state => _inner.state;

  @override
  Stream<AuthState> get states => _inner.states;

  @override
  Future<void> restore() => _inner.restore();

  @override
  Future<void> signIn({bool register = false, String? idpHint}) =>
      _inner.signIn(register: register, idpHint: idpHint);

  @override
  Future<void> signOut() => _inner.signOut();
}
