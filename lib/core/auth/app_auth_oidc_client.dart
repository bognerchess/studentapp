// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:io';

import 'package:bogner_chess/core/auth/auth_config.dart';
import 'package:bogner_chess/core/auth/oidc_client.dart';
import 'package:bogner_chess/core/auth/tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

/// The endpoints of a Keycloak realm, derived from the issuer.
///
/// The interactive sign-in uses OIDC discovery (and with it the native
/// library's full id-token validation). Refresh and revocation use these
/// fixed paths instead: `flutter_appauth` would otherwise fetch the discovery
/// document again before every single refresh. The layout is stable across
/// Keycloak versions and was checked against the discovery document of the
/// production realm.
class KeycloakEndpoints {
  KeycloakEndpoints(Uri issuer)
    : _base = issuer.toString().replaceFirst(RegExp(r'/+$'), '');

  final String _base;

  String get authorization => '$_base/protocol/openid-connect/auth';
  String get token => '$_base/protocol/openid-connect/token';
  String get revocation => '$_base/protocol/openid-connect/revoke';

  /// Deprecated by Keycloak in favour of `prompt=create`; see
  /// [AuthConfig.useLegacyRegistrationEndpoint].
  String get legacyRegistration =>
      '$_base/protocol/openid-connect/registrations';
}

/// [OidcClient] on `flutter_appauth` (AppAuth-iOS, `ASWebAuthenticationSession`)
/// plus one plain HTTPS call for the revocation, which AppAuth does not offer.
class AppAuthOidcClient implements OidcClient {
  AppAuthOidcClient({
    required this.issuer,
    required this.clientId,
    required this.redirectUrl,
    this._appAuth = const FlutterAppAuth(),
    HttpClient Function()? httpClientFactory,
    this.preferEphemeralSession = AuthConfig.preferEphemeralSession,
    this.useLegacyRegistrationEndpoint =
        AuthConfig.useLegacyRegistrationEndpoint,
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new,
       _endpoints = KeycloakEndpoints(issuer);

  final Uri issuer;
  final String clientId;
  final String redirectUrl;
  final bool preferEphemeralSession;
  final bool useLegacyRegistrationEndpoint;

  final FlutterAppAuth _appAuth;
  final HttpClient Function() _httpClientFactory;
  final KeycloakEndpoints _endpoints;

  @override
  Future<OidcTokenResult> authorize({
    bool register = false,
    String? idpHint,
  }) async {
    final legacyRegistration = register && useLegacyRegistrationEndpoint;
    final request = AuthorizationTokenRequest(
      clientId,
      redirectUrl,
      // PKCE (S256), state and nonce are added by the native library.
      issuer: legacyRegistration ? null : issuer.toString(),
      serviceConfiguration: legacyRegistration
          ? AuthorizationServiceConfiguration(
              authorizationEndpoint: _endpoints.legacyRegistration,
              tokenEndpoint: _endpoints.token,
            )
          : null,
      scopes: AuthConfig.scopes,
      promptValues: register && !legacyRegistration ? const ['create'] : null,
      additionalParameters: idpHint == null ? null : {'kc_idp_hint': idpHint},
      externalUserAgent: preferEphemeralSession
          ? ExternalUserAgent.ephemeralAsWebAuthenticationSession
          : ExternalUserAgent.asWebAuthenticationSession,
    );
    try {
      return _result(await _appAuth.authorizeAndExchangeCode(request));
    } on PlatformException catch (e) {
      throw mapPlatformException(e);
    }
  }

  @override
  Future<OidcTokenResult> refresh(String refreshToken) async {
    final request = TokenRequest(
      clientId,
      redirectUrl,
      refreshToken: refreshToken,
      serviceConfiguration: AuthorizationServiceConfiguration(
        authorizationEndpoint: _endpoints.authorization,
        tokenEndpoint: _endpoints.token,
      ),
      // No scopes: the server keeps the ones that were granted.
    );
    try {
      return _result(await _appAuth.token(request));
    } on PlatformException catch (e) {
      throw mapPlatformException(e);
    }
  }

  @override
  Future<void> revoke(String refreshToken) async {
    final client = _httpClientFactory();
    try {
      final request = await client.postUrl(Uri.parse(_endpoints.revocation));
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      // A public client identifies itself with client_id only.
      request.write(
        Uri(
          queryParameters: {
            'client_id': clientId,
            'token': refreshToken,
            'token_type_hint': 'refresh_token',
          },
        ).query,
      );
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode != HttpStatus.ok) {
        throw OidcException(OidcFailure.other, 'http_${response.statusCode}');
      }
    } on IOException {
      // SocketException, TlsException, HttpException.
      throw const OidcException(OidcFailure.transport, 'io');
    } finally {
      client.close(force: true);
    }
  }

  static OidcTokenResult _result(TokenResponse response) {
    final accessToken = response.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const OidcException(OidcFailure.other, 'no_access_token');
    }
    return OidcTokenResult(
      accessToken: accessToken,
      refreshToken: response.refreshToken,
      idToken: response.idToken,
      accessTokenExpiry: response.accessTokenExpirationDateTime,
    );
  }

  /// AppAuth-iOS error domain and codes (`OIDError.h`).
  static const String _generalDomain = 'org.openid.appauth.general';
  static const String _userCancelled = '-3';
  static const String _programCancelled = '-4';
  static const String _networkError = '-5';

  /// OAuth errors that mean "this grant is dead". `invalid_token` is not a
  /// token-endpoint error in RFC 6749, but servers and proxies answer with it.
  static const Set<String> _grantRejected = {'invalid_grant', 'invalid_token'};

  /// Turns what `flutter_appauth` throws into this layer's exceptions. Only
  /// codes leave this function, never descriptions: those may quote request
  /// parameters.
  static Exception mapPlatformException(PlatformException e) {
    if (e is FlutterAppAuthUserCancelledException) {
      return const OidcCancelled();
    }
    if (e is! FlutterAppAuthPlatformException) {
      return OidcException(OidcFailure.other, e.code);
    }
    final details = e.platformErrorDetails;
    final isGeneral = details.type == _generalDomain;
    if (isGeneral &&
        (details.code == _userCancelled || details.code == _programCancelled)) {
      return const OidcCancelled();
    }
    final oauthError = details.error;
    if (oauthError != null && _grantRejected.contains(oauthError)) {
      return OidcException(OidcFailure.grantRejected, oauthError);
    }
    if ((isGeneral && details.code == _networkError) ||
        details.domain == 'NSURLErrorDomain') {
      return OidcException(OidcFailure.transport, e.code);
    }
    return OidcException(OidcFailure.other, oauthError ?? e.code);
  }
}
