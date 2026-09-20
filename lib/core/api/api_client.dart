// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:io';

import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/api/api_error.dart';
import 'package:bogner_chess/core/api/api_links.dart';
import 'package:bogner_chess/core/auth/auth_repository.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:gql/ast.dart';
import 'package:graphql/client.dart';
import 'package:http/http.dart' as http;

const _log = Log('api');

/// How long a call may take before it fails as a time-out.
const Duration kDefaultApiTimeout = Duration(seconds: 15);

/// An analysis document is a few hundred kilobytes; on a bad connection that
/// needs more patience.
const Duration kAnalysisApiTimeout = Duration(seconds: 30);

/// The link chain of the app, outermost first:
/// [HeadersLink] → [TokenLink] → [ReauthLink] → `HttpLink`.
Link buildApiLink({
  required Env env,
  required AuthRepository auth,
  required String Function() languageTag,
  required String Function() userAgent,
  http.Client? httpClient,
}) => Link.from([
  HeadersLink(
    tenantSlug: env.tenantSlug,
    languageTag: languageTag,
    userAgent: userAgent,
  ),
  TokenLink(auth),
  ReauthLink(auth),
  HttpLink(env.apiUrl.toString(), httpClient: httpClient),
]);

/// A client that never reads from or writes to its cache. What has to survive
/// lives in drift; a normalised GraphQL cache would be a second source of
/// truth. The store is in memory, so nothing touches the disk either way.
GraphQLClient createGraphQLClient(Link link) => GraphQLClient(
  link: link,
  cache: GraphQLCache(store: InMemoryStore()),
  queryRequestTimeout: kDefaultApiTimeout,
  defaultPolicies: DefaultPolicies(
    query: Policies(
      fetch: FetchPolicy.noCache,
      error: ErrorPolicy.all,
      cacheReread: CacheRereadPolicy.ignoreAll,
    ),
    mutate: Policies(
      fetch: FetchPolicy.noCache,
      error: ErrorPolicy.all,
      cacheReread: CacheRereadPolicy.ignoreAll,
    ),
  ),
);

/// Runs one generated document and turns whatever goes wrong into an
/// [ApiError]. The repositories use nothing else of the GraphQL client.
class ApiExecutor {
  ApiExecutor(this._client);

  final GraphQLClient _client;

  /// Throws an [ApiError]. [parse] is the generated `fromJson`; when it
  /// throws, the response did not have the shape of the schema.
  Future<T> query<T>({
    required DocumentNode document,
    required String operationName,
    required T Function(Map<String, dynamic> data) parse,
    Map<String, dynamic> variables = const {},
    Duration? timeout,
  }) async {
    final QueryResult<Object?> result;
    try {
      result = await _client.query<Object?>(
        QueryOptions<Object?>(
          document: document,
          operationName: operationName,
          variables: variables,
          queryRequestTimeout: timeout,
        ),
      );
    } on Object catch (e, stack) {
      throw _translate(operationName, e, stack);
    }
    return _unwrap(operationName, result, parse);
  }

  /// Like [query], for a mutation.
  Future<T> mutate<T>({
    required DocumentNode document,
    required String operationName,
    required T Function(Map<String, dynamic> data) parse,
    Map<String, dynamic> variables = const {},
    Duration? timeout,
  }) async {
    final QueryResult<Object?> result;
    try {
      result = await _client.mutate<Object?>(
        MutationOptions<Object?>(
          document: document,
          operationName: operationName,
          variables: variables,
          queryRequestTimeout: timeout,
        ),
      );
    } on Object catch (e, stack) {
      throw _translate(operationName, e, stack);
    }
    return _unwrap(operationName, result, parse);
  }

  T _unwrap<T>(
    String operationName,
    QueryResult<Object?> result,
    T Function(Map<String, dynamic> data) parse,
  ) {
    final exception = result.exception;
    if (exception != null) {
      throw _ofOperationException(operationName, exception);
    }
    final data = result.data;
    if (data == null) {
      throw const ApiServerError(detail: 'response without data');
    }
    try {
      return parse(data);
    } on Object catch (e, stack) {
      // A TypeError or FormatException from the generated fromJson. The type
      // is logged, the content is not: it may be user data.
      _log.error(
        '$operationName: unexpected response shape (${e.runtimeType})',
        stackTrace: stack,
      );
      throw ApiServerError(
        detail: 'unexpected response shape in $operationName',
      );
    }
  }

  ApiError _ofOperationException(String operationName, OperationException e) {
    final link = e.linkException;
    if (link != null) {
      return _translate(operationName, link, e.originalStackTrace);
    }
    final errors = e.graphqlErrors;
    final codes = [
      for (final error in errors)
        if (error.extensions?['code'] case final String code) code,
    ];
    // Only reachable without the ReauthLink in the chain (tests); with it the
    // retry has already happened.
    if (codes.any(kUnauthenticatedCodes.contains)) {
      return const ApiUnauthenticated();
    }
    _log.warning('$operationName: graphql errors, codes $codes');
    return ApiGraphQLError([
      for (final error in errors) error.message,
    ], codes: codes);
  }

  ApiError _translate(String operationName, Object error, StackTrace? stack) {
    final apiError = apiErrorOf(error);
    if (apiError is ApiServerError && apiError.statusCode == null) {
      _log.error(
        '$operationName: ${error.runtimeType}',
        error: apiError,
        stackTrace: stack,
      );
    } else {
      _log.info('$operationName failed: $apiError');
    }
    return apiError;
  }
}

/// The one place where transport failures are sorted into the taxonomy.
///
/// Unwraps the exceptions the GraphQL client and the links wrap around the
/// original one, so an [ApiError] thrown by a link comes out unchanged.
ApiError apiErrorOf(Object error) {
  Object? current = error;
  // Wrappers are at most a few levels deep; the bound only guards a cycle.
  for (var depth = 0; depth < 8 && current != null; depth++) {
    switch (current) {
      case ApiError():
        return current;
      case TimeoutException():
        return const ApiNetworkError(ApiNetworkCause.timeout);
      case SocketException() ||
          HandshakeException() ||
          TlsException() ||
          HttpException() ||
          http.ClientException():
        return const ApiNetworkError();
      case HttpLinkServerException(:final response):
        return _ofStatus(response.statusCode);
      case HttpLinkParserException(:final response):
        return response.statusCode >= 200 && response.statusCode < 300
            ? ApiServerError(
                statusCode: response.statusCode,
                detail: 'response is not GraphQL JSON',
              )
            : _ofStatus(response.statusCode);
      case OperationException(:final linkException?):
        current = linkException;
      case LinkException(:final originalException?):
        current = originalException;
      default:
        current = null;
    }
  }
  return ApiServerError(detail: 'unexpected ${error.runtimeType}');
}

ApiError _ofStatus(int statusCode) => statusCode == 401
    ? const ApiUnauthenticated()
    : ApiServerError(statusCode: statusCode);
