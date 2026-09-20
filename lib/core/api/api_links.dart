// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/api/api_error.dart';
import 'package:bogner_chess/core/auth/auth_repository.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:graphql/client.dart';

const _log = Log('api');

/// GraphQL error codes that mean "this token is not accepted" when they come
/// in a response with HTTP status 200.
const Set<String> kUnauthenticatedCodes = {
  'AUTH_NOT_AUTHENTICATED',
  'UNAUTHENTICATED',
};

/// The request with [headers] added to the ones a link further up has set.
Request _withHeaders(Request request, Map<String, String> headers) =>
    request.updateContextEntry<HttpLinkHeaders>(
      (entry) => HttpLinkHeaders(headers: {...?entry?.headers, ...headers}),
    );

String? _bearerOf(Request request) {
  final value = request.context.entry<HttpLinkHeaders>()?.headers[_kAuth];
  return value != null && value.startsWith(_kBearer)
      ? value.substring(_kBearer.length)
      : null;
}

const String _kAuth = 'Authorization';
const String _kBearer = 'Bearer ';

/// The headers every request carries apart from the token: the tenant, the
/// CSRF preflight marker the server requires, the language for server-side
/// texts and the app version.
class HeadersLink extends Link {
  HeadersLink({
    required this.tenantSlug,
    required this.languageTag,
    required this.userAgent,
  });

  final String tenantSlug;

  /// Read for every request, because the system language can change while the
  /// app runs. A BCP 47 tag such as `de-CH`.
  final String Function() languageTag;

  /// Read for every request, because the version is only known after the
  /// first platform call has answered.
  final String Function() userAgent;

  @override
  Stream<Response> request(Request request, [NextLink? forward]) => forward!(
    _withHeaders(request, {
      'X-Tenant-Slug': tenantSlug,
      'GraphQL-preflight': '1',
      'Accept-Language': languageTag(),
      'User-Agent': userAgent(),
    }),
  );
}

/// Puts the access token on the request.
///
/// Without a token (nobody is signed in) the request is not sent at all and
/// fails with [ApiUnauthenticated]. A refresh that could not be made is a
/// network or server error and leaves the session alone.
class TokenLink extends Link {
  TokenLink(this._auth);

  final AuthRepository _auth;

  @override
  Stream<Response> request(Request request, [NextLink? forward]) async* {
    final String? token;
    try {
      token = await _auth.accessToken();
    } on AuthException catch (e) {
      throw apiErrorOfAuth(e);
    }
    if (token == null) {
      throw const ApiUnauthenticated();
    }
    yield* forward!(_withHeaders(request, {_kAuth: '$_kBearer$token'}));
  }
}

/// After a 401 (or a GraphQL `UNAUTHENTICATED` error): one forced refresh, one
/// retry, then [ApiUnauthenticated].
///
/// The refresh is asked for with the token the server refused, so that
/// parallel requests which all got a 401 for the same token cause one refresh
/// between them. The repository guarantees that; this link also shares the
/// future per refused token, so that the guarantee does not depend on timing.
///
/// Never signs out: a 401 can be the backend's fault. When the grant is dead,
/// the repository has already moved to `SignedOut` during the refresh.
class ReauthLink extends Link {
  ReauthLink(this._auth);

  final AuthRepository _auth;
  final Map<String, Future<String?>> _refreshes = {};

  @override
  Stream<Response> request(Request request, [NextLink? forward]) async* {
    final first = await _attempt(request, forward!);
    if (first != null) {
      yield first;
      return;
    }

    final rejected = _bearerOf(request);
    _log.info('401 for ${request.operation.operationName}: forcing a refresh');
    final String? fresh;
    try {
      fresh = await _refresh(rejected);
    } on AuthException catch (e) {
      throw apiErrorOfAuth(e);
    }
    if (fresh == null) {
      throw const ApiUnauthenticated();
    }

    final second = await _attempt(
      _withHeaders(request, {_kAuth: '$_kBearer$fresh'}),
      forward,
    );
    if (second == null) {
      throw const ApiUnauthenticated();
    }
    yield second;
  }

  /// The response, or null when the server did not accept the token.
  Future<Response?> _attempt(Request request, NextLink forward) async {
    final Response response;
    try {
      response = await forward(request).first;
    } on HttpLinkServerException catch (e) {
      if (e.response.statusCode == 401) {
        return null;
      }
      rethrow;
    } on HttpLinkParserException catch (e) {
      // A 401 with an empty or an HTML body.
      if (e.response.statusCode == 401) {
        return null;
      }
      rethrow;
    }
    final unauthenticated =
        response.errors?.any(
          (error) => kUnauthenticatedCodes.contains(error.extensions?['code']),
        ) ??
        false;
    return unauthenticated ? null : response;
  }

  Future<String?> _refresh(String? rejected) =>
      _refreshes[rejected ?? ''] ??= _runRefresh(rejected);

  Future<String?> _runRefresh(String? rejected) async {
    try {
      return await _auth.forceRefresh(rejectedToken: rejected);
    } finally {
      // The removed value is this very future; its callers handle its error.
      _refreshes.remove(rejected ?? '')?.ignore();
    }
  }
}

/// A refresh that could not be made: the user stays signed in, the call
/// failed.
ApiError apiErrorOfAuth(AuthException e) => switch (e.kind) {
  AuthErrorKind.network => const ApiNetworkError(),
  AuthErrorKind.server => ApiServerError(detail: 'token refresh: ${e.code}'),
};
