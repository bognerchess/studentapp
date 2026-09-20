// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:convert';

import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/api/api_client.dart';
import 'package:bogner_chess/core/auth/auth_repository.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:gql_link/gql_link.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// An [AuthRepository] whose tokens and failures a test scripts, and which
/// counts what the API layer asks of it.
class ScriptedAuthRepository implements AuthRepository {
  ScriptedAuthRepository({this.token = 'token-1', List<String?>? refreshed})
    : refreshed = refreshed ?? ['token-2'];

  /// What [accessToken] returns; null means signed out.
  String? token;

  /// What successive refreshes produce, first to last; the last one repeats.
  final List<String?> refreshed;

  /// When set, [accessToken] throws it.
  AuthException? accessError;

  /// When set, [forceRefresh] throws it.
  AuthException? refreshError;

  /// How long a refresh takes, so that parallel callers overlap.
  Duration refreshDelay = Duration.zero;

  int accessTokenCalls = 0;
  int refreshes = 0;
  int signOuts = 0;
  final List<String?> rejectedTokens = [];

  Future<String?>? _inFlight;

  @override
  AuthState get state =>
      token == null ? const SignedOut() : const SignedIn('sub-1');

  @override
  Stream<AuthState> get states => const Stream.empty();

  @override
  Future<void> restore() async {}

  @override
  Future<void> signIn({bool register = false, String? idpHint}) async {}

  @override
  Future<String?> accessToken() async {
    accessTokenCalls++;
    final error = accessError;
    if (error != null) {
      throw error;
    }
    return token;
  }

  /// Single-flight and aware of [rejectedToken], like the real repository.
  @override
  Future<String?> forceRefresh({String? rejectedToken}) {
    rejectedTokens.add(rejectedToken);
    if (rejectedToken != null && token != null && rejectedToken != token) {
      return Future.value(token);
    }
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  Future<String?> _refresh() async {
    refreshes++;
    if (refreshDelay > Duration.zero) {
      await Future<void>.delayed(refreshDelay);
    }
    final error = refreshError;
    if (error != null) {
      throw error;
    }
    final next = refreshed.length > 1 ? refreshed.removeAt(0) : refreshed.first;
    return token = next;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    token = null;
  }
}

Env apiTestEnv({Uri? apiUrl}) => Env(
  envName: 'fake',
  apiUrl: apiUrl ?? Uri.parse('https://api.example.test/graphql'),
  tenantSlug: 'test-tenant',
  oidcIssuer: Uri.parse('https://id.example.test/realms/test'),
  oidcClientId: 'test-client',
  oidcRedirect: 'com.bognerchess.mobile:/oauthredirect',
  sentryDsn: '',
  authMode: AuthMode.fake,
);

/// The real link chain of the app over [httpClient] (or the real network).
ApiExecutor chainExecutor({
  required AuthRepository auth,
  http.Client? httpClient,
  Uri? apiUrl,
  String Function()? languageTag,
}) => ApiExecutor(
  createGraphQLClient(
    buildApiLink(
      env: apiTestEnv(apiUrl: apiUrl),
      auth: auth,
      languageTag: languageTag ?? () => 'de-CH',
      userAgent: () => 'BognerChess-iOS/0.1.0+1',
      httpClient: httpClient,
    ),
  ),
);

/// An executor straight over [link], without headers, token or HTTP.
ApiExecutor linkExecutor(Link link) => ApiExecutor(createGraphQLClient(link));

/// A scripted HTTP server: answers requests with [responses] in order (the
/// last one repeats) and records what it was sent.
class ScriptedHttp {
  ScriptedHttp(List<http.Response> responses)
    : _responses = [...responses],
      _respond = null;

  /// Answers by looking at the request.
  ScriptedHttp.by(http.Response Function(http.Request request) respond)
    : _responses = [],
      _respond = respond;

  final List<http.Response> _responses;
  final http.Response Function(http.Request request)? _respond;
  final List<http.Request> requests = [];

  late final http.Client client = MockClient((request) async {
    requests.add(request);
    final respond = _respond;
    if (respond != null) {
      return respond(request);
    }
    return _responses.length > 1 ? _responses.removeAt(0) : _responses.first;
  });

  List<String?> get bearerTokens => [
    for (final request in requests)
      request.headers['Authorization']?.replaceFirst('Bearer ', ''),
  ];

  static http.Response json(Object? body, {int status = 200}) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  static http.Response data(Map<String, dynamic> data) => json({'data': data});

  static http.Response unauthorized() => json({
    'errors': [
      {
        'message': 'not authorized',
        'extensions': {'code': 'AUTH_NOT_AUTHENTICATED'},
      },
    ],
  }, status: 401);
}

/// `data` of a MobileConfig response: the smallest complete query there is.
const Map<String, dynamic> kConfigData = {
  'mobileConfig': {
    'minSupportedAppVersion': '0.1.0',
    'maxAnalysisSchemaVersion': 1,
    'supportedCoachLanguages': ['en', 'de'],
    'jobPollIntervalSeconds': 3,
    'featureFlags': <Object?>[],
    'currentAiConsentVersion': 1,
  },
};
