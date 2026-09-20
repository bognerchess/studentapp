// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/api/api_client.dart';
import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';

import '../../tool/mock_server/fixture_store.dart';

export '../../tool/mock_server/fixture_store.dart'
    show FixtureNotFound, FixtureStore;

/// A request a [FixtureLink] has answered.
typedef FixtureRequest = ({
  String operationName,
  Map<String, dynamic> variables,
});

/// Builds the body of a GraphQL response (`{"data": ...}`) for a request.
typedef FixtureResponder = FutureOr<Map<String, dynamic>> Function(
  Map<String, dynamic> variables,
);

/// A terminating `gql` link that answers from
/// `test/fixtures/graphql/<Operation>/<scenario>.json`: the API layer without
/// a network, a token or a server, for widget and repository tests.
///
///     final api = FixtureLink({'RequestGameAnalysis': 'limit_reached'});
///     await pumpApp(tester, overrides: api.overrides);
///     ...
///     api.use('RequestGameAnalysis', 'accepted');       // change it later
///     expect(api.requestsOf('RequestGameAnalysis').single.variables, ...);
///
/// An operation without a chosen scenario is answered with its `default`
/// fixture; without one the request fails and names the scenarios that exist.
/// The same files feed the mock server (`tool/mock_server`).
class FixtureLink extends Link {
  FixtureLink([Map<String, String> scenarios = const {}, FixtureStore? store])
    : _scenarios = {...scenarios},
      store = store ?? FixtureStore();

  final FixtureStore store;
  final Map<String, String> _scenarios;
  final Map<String, FixtureResponder> _responders = {};
  final Map<String, Object> _failures = {};

  /// Every request so far, oldest first.
  final List<FixtureRequest> requests = [];

  /// Answers are delayed by this much; zero answers in a microtask.
  Duration delay = Duration.zero;

  /// `ProviderScope(overrides: link.overrides)`: every repository of
  /// `api_providers.dart` then talks to this link.
  List<Override> get overrides => [
    apiLinkProvider.overrideWithValue(this),
    // No request timeout: this link answers from memory, so the timer can
    // never fire, and a widget test that ends with one pending fails.
    apiExecutorProvider.overrideWith(
      (ref) => ApiExecutor(createGraphQLClient(this, requestTimeout: null)),
    ),
  ];

  /// Answers [operation] with `<operation>/<scenario>.json` from now on.
  void use(String operation, String scenario) {
    _responders.remove(operation);
    _failures.remove(operation);
    _scenarios[operation] = scenario;
  }

  /// Answers [operation] with whatever [responder] builds, for responses that
  /// depend on the variables or on how often they were asked for.
  void respond(String operation, FixtureResponder responder) {
    _failures.remove(operation);
    _responders[operation] = responder;
  }

  /// Lets [operation] fail below GraphQL. Throw what the transport throws: a
  /// `SocketException` for offline, a `TimeoutException`, or an `ApiError`.
  void fail(String operation, Object error) => _failures[operation] = error;

  List<FixtureRequest> requestsOf(String operation) => [
    for (final request in requests)
      if (request.operationName == operation) request,
  ];

  @override
  Stream<Response> request(Request request, [NextLink? forward]) async* {
    final operation = request.operation.operationName ?? '';
    requests.add((operationName: operation, variables: request.variables));
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final failure = _failures[operation];
    if (failure != null) {
      // Deliberately anything: the point is to feed the error mapping.
      // ignore: only_throw_errors
      throw failure;
    }
    final responder = _responders[operation];
    final body = responder != null
        ? await responder(request.variables)
        : store.response(operation, _scenarios[operation] ?? 'default');
    yield responseOf(body);
  }

  /// A `gql` response from the JSON body of a GraphQL response.
  static Response responseOf(Map<String, dynamic> body) => Response(
    data: body['data'] as Map<String, dynamic>?,
    errors: [
      for (final error in body['errors'] as List? ?? const <Object?>[])
        GraphQLError(
          message: (error as Map)['message'] as String? ?? '',
          extensions: (error['extensions'] as Map?)?.cast<String, dynamic>(),
        ),
    ].nonEmptyOrNull,
    response: body,
  );
}

extension<T> on List<T> {
  List<T>? get nonEmptyOrNull => isEmpty ? null : this;
}
