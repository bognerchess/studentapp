// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'fixture_store.dart';
import 'mock_backend.dart';

export 'fixture_store.dart';
export 'mock_backend.dart';

/// The mock of the GraphQL API for simulator sessions, integration tests and
/// the tests of the API layer. Development tooling: it lives in `tool/`, is
/// not part of the app and imports nothing but `dart:io` and `shelf`.
///
///     POST /graphql      one GraphQL request, answered by operationName
///     POST /__scenario   {"name": "limit_reached"}, see [kScenarioNames]
///     GET  /__state      what the server remembers
///     GET  /healthz      "ok"
///
/// `/graphql` wants what the real API wants: an `Authorization: Bearer` header
/// (any token; 401 without one) and `X-Tenant-Slug` (400 without it).
class MockServer {
  MockServer._(this.backend, this._servers, this._log);

  /// Binds to the loopback interface. Port 0 picks a free port, see [port].
  static Future<MockServer> start({
    int port = 0,
    MockBackend? backend,
    void Function(String line)? log,
  }) async {
    final state = backend ?? MockBackend();
    final servers = <HttpServer>[];
    final server = MockServer._(state, servers, log);
    final first = await shelf_io.serve(
      server._handle,
      InternetAddress.loopbackIPv4,
      port,
    );
    servers.add(first);
    // The iOS simulator may resolve "localhost" to ::1 first.
    try {
      servers.add(
        await shelf_io.serve(
          server._handle,
          InternetAddress.loopbackIPv6,
          first.port,
        ),
      );
    } on SocketException {
      // No IPv6 loopback, or the port is taken there: IPv4 is enough.
    }
    return server;
  }

  final MockBackend backend;
  final List<HttpServer> _servers;
  final void Function(String line)? _log;

  /// What the server was asked, oldest first: for assertions in tests.
  final List<RecordedRequest> requests = [];

  int get port => _servers.first.port;

  /// The value for `API_URL`.
  Uri get graphqlUri => Uri.parse('http://127.0.0.1:$port/graphql');

  Uri get scenarioUri => Uri.parse('http://127.0.0.1:$port/__scenario');

  Future<void> close() async {
    await Future.wait([
      for (final server in _servers) server.close(force: true),
    ]);
  }

  static const Map<String, String> _json = {
    'content-type': 'application/json; charset=utf-8',
  };

  static Response _reply(int status, Object? body) =>
      Response(status, body: jsonEncode(body), headers: _json);

  static Response _graphqlError(int status, String message, String code) =>
      _reply(status, {
        'errors': [
          {
            'message': message,
            'extensions': {'code': code},
          },
        ],
      });

  Future<Response> _handle(Request request) async {
    final path = request.url.path;
    try {
      return switch ((request.method, path)) {
        ('GET', 'healthz') => Response.ok('ok'),
        ('GET', '__state') => _reply(200, backend.describe()),
        ('POST', '__scenario') => await _scenario(request),
        ('POST', 'graphql') => await _graphql(request),
        _ => _reply(404, {'error': 'no route ${request.method} /$path'}),
      };
    } on FormatException catch (e) {
      return _reply(400, {'error': e.message});
    } on FixtureNotFound catch (e) {
      return _reply(400, {'error': e.toString()});
    } on Object catch (e, stack) {
      _log?.call('error: $e\n$stack');
      return _reply(500, {'error': e.toString()});
    }
  }

  static Future<Map<String, dynamic>> _bodyOf(Request request) async {
    final text = await request.readAsString();
    final body = text.trim().isEmpty ? <String, dynamic>{} : jsonDecode(text);
    if (body is! Map<String, dynamic>) {
      throw const FormatException('the body has to be a JSON object');
    }
    return body;
  }

  Future<Response> _scenario(Request request) async {
    final body = await _bodyOf(request);
    final name = body['name'];
    if (name is! String) {
      throw FormatException(
        'expected {"name": "<scenario>"}; there are: '
        '${kScenarioNames.join(', ')}',
      );
    }
    final state = backend.applyScenario(name, body);
    _log?.call('scenario $name');
    return _reply(200, state);
  }

  Future<Response> _graphql(Request request) async {
    final body = await _bodyOf(request);
    final operationName =
        body['operationName'] as String? ??
        RegExp(r'\b(?:query|mutation)\s+(\w+)')
            .firstMatch(body['query'] as String? ?? '')
            ?.group(1) ??
        '';
    final variables = switch (body['variables']) {
      final Map<String, dynamic> map => map,
      _ => <String, dynamic>{},
    };
    final recorded = RecordedRequest(
      operationName,
      variables,
      Map.unmodifiable(request.headers),
    );
    requests.add(recorded);

    final delay = backend.responseDelay;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    final authorization = request.headers['authorization'] ?? '';
    if (!authorization.startsWith('Bearer ') || authorization.length < 8) {
      recorded.status = 401;
      _log?.call('$operationName -> 401 (no bearer token)');
      return _graphqlError(
        401,
        'The current user is not authorized to access this resource.',
        'AUTH_NOT_AUTHENTICATED',
      );
    }
    if (backend.takeUnauthenticatedOnce()) {
      recorded.status = 401;
      _log?.call('$operationName -> 401 (scenario unauthenticated_once)');
      return _graphqlError(
        401,
        'The current user is not authorized to access this resource.',
        'AUTH_NOT_AUTHENTICATED',
      );
    }
    if ((request.headers['x-tenant-slug'] ?? '').isEmpty) {
      recorded.status = 400;
      _log?.call('$operationName -> 400 (no X-Tenant-Slug)');
      return _graphqlError(400, 'X-Tenant-Slug is missing.', 'TENANT_MISSING');
    }

    final response = backend.execute(operationName, variables);
    _log?.call('$operationName -> ${_summaryOf(response)}');
    return _reply(200, response);
  }

  static String _summaryOf(Map<String, dynamic> response) {
    if (response['errors'] != null) {
      return 'graphql errors';
    }
    final data = response['data'];
    if (data is Map && data.length == 1) {
      final payload = data.values.single;
      if (payload is Map && payload['errors'] is List) {
        final errors = payload['errors'] as List;
        final first = errors.isEmpty ? null : errors.first;
        return first is Map ? '${first['__typename']}' : 'ok';
      }
    }
    return 'ok';
  }
}

class RecordedRequest {
  RecordedRequest(this.operationName, this.variables, this.headers);

  final String operationName;
  final Map<String, dynamic> variables;

  /// Lower-case header names, as shelf delivers them.
  final Map<String, String> headers;

  /// 200 unless the server refused the request.
  int status = 200;
}
