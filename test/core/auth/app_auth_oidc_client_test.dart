// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';
import 'dart:io';

import 'package:bogner_chess/core/auth/app_auth_oidc_client.dart';
import 'package:bogner_chess/core/auth/oidc_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAppAuth implements FlutterAppAuth {
  AuthorizationTokenRequest? authorizeRequest;
  TokenRequest? tokenRequest;
  Exception? error;

  final DateTime expiry = DateTime.utc(2026, 9, 19, 12, 5);

  @override
  Future<AuthorizationTokenResponse> authorizeAndExchangeCode(
    AuthorizationTokenRequest request,
  ) async {
    authorizeRequest = request;
    if (error case final Exception error) {
      throw error;
    }
    return AuthorizationTokenResponse(
      'access',
      'refresh',
      expiry,
      'id',
      'Bearer',
      const ['openid'],
      null,
      null,
    );
  }

  @override
  Future<TokenResponse> token(TokenRequest request) async {
    tokenRequest = request;
    if (error case final Exception error) {
      throw error;
    }
    return TokenResponse('access-2', null, expiry, null, 'Bearer', null, null);
  }

  @override
  Future<AuthorizationResponse> authorize(AuthorizationRequest request) =>
      throw UnimplementedError();

  @override
  Future<EndSessionResponse> endSession(EndSessionRequest request) =>
      throw UnimplementedError();
}

FlutterAppAuthPlatformException _platformError({
  String code = 'token_failed',
  String? type,
  String? nativeCode,
  String? error,
  String? domain,
}) => FlutterAppAuthPlatformException(
  code: code,
  platformErrorDetails: FlutterAppAuthPlatformErrorDetails(
    type: type,
    code: nativeCode,
    error: error,
    domain: domain,
    errorDescription: 'Session not active for user someone@example.test',
  ),
);

void main() {
  const issuer = 'https://id.example.test/realms/test';
  late _FakeAppAuth appAuth;

  AppAuthOidcClient client({
    bool ephemeral = true,
    bool legacyRegistration = false,
    String issuerUrl = issuer,
  }) => AppAuthOidcClient(
    issuer: Uri.parse(issuerUrl),
    clientId: 'bognerchess-mobile',
    redirectUrl: 'com.bognerchess.mobile:/oauthredirect',
    appAuth: appAuth,
    preferEphemeralSession: ephemeral,
    useLegacyRegistrationEndpoint: legacyRegistration,
  );

  setUp(() => appAuth = _FakeAppAuth());

  group('authorize', () {
    test(
      'code flow with discovery, the four scopes, ephemeral sheet',
      () async {
        final result = await client().authorize();

        final request = appAuth.authorizeRequest!;
        expect(request.clientId, 'bognerchess-mobile');
        expect(request.redirectUrl, 'com.bognerchess.mobile:/oauthredirect');
        expect(request.issuer, issuer);
        expect(request.serviceConfiguration, isNull);
        expect(request.scopes, [
          'openid',
          'profile',
          'email',
          'offline_access',
        ]);
        expect(request.promptValues, isNull);
        expect(request.additionalParameters, isNull);
        expect(request.clientSecret, isNull);
        expect(
          request.externalUserAgent,
          ExternalUserAgent.ephemeralAsWebAuthenticationSession,
        );

        expect(result.accessToken, 'access');
        expect(result.refreshToken, 'refresh');
        expect(result.idToken, 'id');
        expect(result.accessTokenExpiry, appAuth.expiry);
      },
    );

    test('register sends prompt=create', () async {
      await client().authorize(register: true);
      expect(appAuth.authorizeRequest!.promptValues, ['create']);
      expect(appAuth.authorizeRequest!.issuer, issuer);
    });

    test('register can use the legacy registrations endpoint', () async {
      await client(legacyRegistration: true).authorize(register: true);
      final request = appAuth.authorizeRequest!;
      expect(request.promptValues, isNull);
      expect(request.issuer, isNull);
      expect(
        request.serviceConfiguration!.authorizationEndpoint,
        '$issuer/protocol/openid-connect/registrations',
      );
      expect(
        request.serviceConfiguration!.tokenEndpoint,
        '$issuer/protocol/openid-connect/token',
      );

      // A plain sign-in is unaffected by the switch.
      await client(legacyRegistration: true).authorize();
      expect(appAuth.authorizeRequest!.issuer, issuer);
    });

    test('idpHint becomes kc_idp_hint', () async {
      await client().authorize(idpHint: 'apple');
      expect(appAuth.authorizeRequest!.additionalParameters, {
        'kc_idp_hint': 'apple',
      });
    });

    test('the shared session is a switch', () async {
      await client(ephemeral: false).authorize();
      expect(
        appAuth.authorizeRequest!.externalUserAgent,
        ExternalUserAgent.asWebAuthenticationSession,
      );
    });

    test('an answer without an access token is an error', () async {
      final noToken = _NoTokenAppAuth();
      final oidc = AppAuthOidcClient(
        issuer: Uri.parse(issuer),
        clientId: 'c',
        redirectUrl: 'r:/x',
        appAuth: noToken,
      );
      await expectLater(oidc.authorize(), throwsA(isA<OidcException>()));
    });
  });

  group('refresh', () {
    test('goes to the token endpoint without discovery', () async {
      final result = await client(issuerUrl: '$issuer/').refresh('refresh-1');

      final request = appAuth.tokenRequest!;
      expect(request.refreshToken, 'refresh-1');
      expect(request.issuer, isNull);
      expect(request.discoveryUrl, isNull);
      expect(
        request.serviceConfiguration!.tokenEndpoint,
        '$issuer/protocol/openid-connect/token',
      );
      expect(request.clientSecret, isNull);
      expect(result.accessToken, 'access-2');
      expect(result.refreshToken, isNull);
      expect(result.idToken, isNull);
    });
  });

  group('error mapping', () {
    Future<Object> refreshError(Exception thrown) async {
      appAuth.error = thrown;
      try {
        await client().refresh('r');
      } on Object catch (e) {
        return e;
      }
      fail('expected an exception');
    }

    test('closing the sheet is OidcCancelled', () async {
      appAuth.error = FlutterAppAuthUserCancelledException(
        code: 'authorize_and_exchange_code_failed',
        platformErrorDetails: FlutterAppAuthPlatformErrorDetails(),
      );
      await expectLater(client().authorize(), throwsA(isA<OidcCancelled>()));

      appAuth.error = _platformError(
        type: 'org.openid.appauth.general',
        nativeCode: '-4',
      );
      await expectLater(client().authorize(), throwsA(isA<OidcCancelled>()));
    });

    test('invalid_grant and invalid_token reject the grant', () async {
      for (final code in ['invalid_grant', 'invalid_token']) {
        final e = await refreshError(
          _platformError(
            type: 'org.openid.appauth.oauth_token',
            nativeCode: '-10',
            error: code,
          ),
        );
        expect(
          e,
          isA<OidcException>()
              .having((e) => e.failure, 'failure', OidcFailure.grantRejected)
              .having((e) => e.code, 'code', code),
        );
      }
    });

    test('a network error is transport', () async {
      final general = await refreshError(
        _platformError(type: 'org.openid.appauth.general', nativeCode: '-5'),
      );
      final urlDomain = await refreshError(
        _platformError(
          code: 'discovery_failed',
          type: 'org.openid.appauth.general',
          nativeCode: '-6',
          domain: 'NSURLErrorDomain',
        ),
      );
      for (final e in [general, urlDomain]) {
        expect(
          e,
          isA<OidcException>().having(
            (e) => e.failure,
            'failure',
            OidcFailure.transport,
          ),
        );
      }
    });

    test('everything else is other and keeps the OAuth code', () async {
      final invalidClient = await refreshError(
        _platformError(
          type: 'org.openid.appauth.oauth_token',
          error: 'invalid_client',
        ),
      );
      final serverError = await refreshError(
        _platformError(type: 'org.openid.appauth.general', nativeCode: '-6'),
      );
      final plain = await refreshError(PlatformException(code: 'boom'));
      expect(
        invalidClient,
        isA<OidcException>()
            .having((e) => e.failure, 'failure', OidcFailure.other)
            .having((e) => e.code, 'code', 'invalid_client'),
      );
      expect(
        serverError,
        isA<OidcException>()
            .having((e) => e.failure, 'failure', OidcFailure.other)
            .having((e) => e.code, 'code', 'token_failed'),
      );
      expect(plain, isA<OidcException>().having((e) => e.code, 'code', 'boom'));
    });

    test('the description, which may name the user, is dropped', () async {
      final e = await refreshError(_platformError(error: 'invalid_grant'));
      expect(e.toString(), isNot(contains('example.test')));
    });
  });

  group('revoke', () {
    late HttpServer server;
    late List<({String path, String? contentType, Map<String, String> form})>
    requests;
    var status = HttpStatus.ok;

    setUp(() async {
      requests = [];
      status = HttpStatus.ok;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final body = await utf8.decodeStream(request);
        requests.add((
          path: request.uri.path,
          contentType: request.headers.contentType?.mimeType,
          form: Uri.splitQueryString(body),
        ));
        request.response.statusCode = status;
        await request.response.close();
      });
    });

    tearDown(() => server.close(force: true));

    AppAuthOidcClient local() =>
        client(issuerUrl: 'http://127.0.0.1:${server.port}/realms/test');

    test('posts the refresh token as a public client', () async {
      await local().revoke('refresh+token/with=chars');
      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.path, '/realms/test/protocol/openid-connect/revoke');
      expect(request.contentType, 'application/x-www-form-urlencoded');
      expect(request.form, {
        'client_id': 'bognerchess-mobile',
        'token': 'refresh+token/with=chars',
        'token_type_hint': 'refresh_token',
      });
    });

    test('a status other than 200 is an error', () async {
      status = HttpStatus.badRequest;
      await expectLater(
        local().revoke('r'),
        throwsA(isA<OidcException>().having((e) => e.code, 'code', 'http_400')),
      );
    });

    test('an unreachable server is a transport error', () async {
      final port = server.port;
      await server.close(force: true);
      await expectLater(
        client(issuerUrl: 'http://127.0.0.1:$port/realms/test').revoke('r'),
        throwsA(
          isA<OidcException>().having(
            (e) => e.failure,
            'failure',
            OidcFailure.transport,
          ),
        ),
      );
    });
  });
}

class _NoTokenAppAuth extends _FakeAppAuth {
  @override
  Future<AuthorizationTokenResponse> authorizeAndExchangeCode(
    AuthorizationTokenRequest request,
  ) async => AuthorizationTokenResponse(
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
  );
}
