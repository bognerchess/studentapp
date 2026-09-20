// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:io';

import 'package:bogner_chess/core/api/api_client.dart';
import 'package:bogner_chess/core/api/config_api.dart';
import 'package:bogner_chess/core/api/generated/operations/config.graphql.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/fixture_link.dart';
import 'api_test_support.dart';

void main() {
  ConfigApi apiOver(http.Client client) => ConfigApi(
    chainExecutor(auth: ScriptedAuthRepository(), httpClient: client),
  );

  Future<ApiError> errorOf(Future<Object?> call) async {
    try {
      await call;
    } on ApiError catch (e) {
      return e;
    }
    fail('expected an ApiError');
  }

  group('HTTP', () {
    test('5xx is a retryable server error with its status', () async {
      final server = ScriptedHttp([
        ScriptedHttp.json({'x': 1}, status: 503),
      ]);
      final error = await errorOf(apiOver(server.client).mobileConfig());
      expect(error, const ApiServerError(statusCode: 503));
      expect(error.isRetryable, isTrue);
    });

    test('a 5xx with an HTML body keeps its status', () async {
      final server = ScriptedHttp([http.Response('<h1>Bad gateway</h1>', 502)]);
      expect(
        await errorOf(apiOver(server.client).mobileConfig()),
        const ApiServerError(statusCode: 502),
      );
    });

    test('4xx is a server error that is not retried', () async {
      final server = ScriptedHttp([
        ScriptedHttp.json({'x': 1}, status: 400),
      ]);
      final error = await errorOf(apiOver(server.client).mobileConfig());
      expect(error, const ApiServerError(statusCode: 400));
      expect(error.isRetryable, isFalse);
    });

    test('429 and 408 are retryable', () {
      expect(const ApiServerError(statusCode: 429).isRetryable, isTrue);
      expect(const ApiServerError(statusCode: 408).isRetryable, isTrue);
    });

    test('200 with a body that is not JSON', () async {
      final server = ScriptedHttp([
        http.Response('<html>captive portal</html>', 200),
      ]);
      final error = await errorOf(apiOver(server.client).mobileConfig());
      expect(
        error,
        isA<ApiServerError>()
            .having((e) => e.statusCode, 'statusCode', 200)
            .having((e) => e.isRetryable, 'isRetryable', isFalse),
      );
    });

    test('200 with neither data nor errors', () async {
      final server = ScriptedHttp([
        ScriptedHttp.json({'data': null}),
      ]);
      expect(
        await errorOf(apiOver(server.client).mobileConfig()),
        isA<ApiServerError>(),
      );
    });
  });

  group('network', () {
    for (final (name, exception) in <(String, Exception)>[
      ('SocketException', const SocketException('Connection refused')),
      ('ClientException', http.ClientException('Connection closed')),
      ('HandshakeException', const HandshakeException('bad certificate')),
      (
        'HttpException',
        const HttpException('Connection closed before full header'),
      ),
    ]) {
      test('$name is a retryable network error', () async {
        final client = MockClient((_) => throw exception);
        final error = await errorOf(apiOver(client).mobileConfig());
        expect(error, const ApiNetworkError());
        expect(error.isRetryable, isTrue);
      });
    }

    test('no answer within the time limit is a time-out', () async {
      final client = MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return ScriptedHttp.data(kConfigData);
      });
      final executor = chainExecutor(
        auth: ScriptedAuthRepository(),
        httpClient: client,
      );

      final error = await errorOf(
        executor.query(
          document: documentNodeQueryMobileConfig,
          operationName: 'MobileConfig',
          parse: Query$MobileConfig.fromJson,
          timeout: const Duration(milliseconds: 20),
        ),
      );

      expect(error, const ApiNetworkError(ApiNetworkCause.timeout));
      expect(error.isRetryable, isTrue);
    });

    test('the default time limits', () {
      expect(kDefaultApiTimeout, const Duration(seconds: 15));
      expect(kAnalysisApiTimeout, const Duration(seconds: 30));
    });

    test(
      'a TimeoutException from the transport is a time-out as well',
      () async {
        final link = FixtureLink()
          ..fail('MobileConfig', TimeoutException('no answer'));
        expect(
          await errorOf(ConfigApi(linkExecutor(link)).mobileConfig()),
          const ApiNetworkError(ApiNetworkCause.timeout),
        );
      },
    );
  });

  group('GraphQL', () {
    test('top-level errors come out with messages and codes', () async {
      final link = FixtureLink()
        ..respond(
          'MobileConfig',
          (_) => {
            'errors': [
              {
                'message': 'The field `nope` does not exist.',
                'extensions': {'code': 'HC0044'},
              },
              {'message': 'Second'},
            ],
          },
        );
      final error = await errorOf(ConfigApi(linkExecutor(link)).mobileConfig());
      expect(
        error,
        const ApiGraphQLError(
          ['The field `nope` does not exist.', 'Second'],
          codes: ['HC0044'],
        ),
      );
      expect(error.isRetryable, isFalse);
    });

    test('partial data with errors is an error', () async {
      final link = FixtureLink()
        ..respond(
          'MobileConfig',
          (_) => {
            'data': kConfigData,
            'errors': [
              {'message': 'Unexpected Execution Error'},
            ],
          },
        );
      expect(
        await errorOf(ConfigApi(linkExecutor(link)).mobileConfig()),
        isA<ApiGraphQLError>(),
      );
    });

    test(
      'an UNAUTHENTICATED code without the reauth link is unauthenticated',
      () async {
        final link = FixtureLink()
          ..respond(
            'MobileConfig',
            (_) => {
              'errors': [
                {
                  'message': 'no',
                  'extensions': {'code': 'AUTH_NOT_AUTHENTICATED'},
                },
              ],
            },
          );
        expect(
          await errorOf(ConfigApi(linkExecutor(link)).mobileConfig()),
          const ApiUnauthenticated(),
        );
      },
    );

    test('data that does not have the shape of the schema', () async {
      final link = FixtureLink()
        ..respond(
          'MobileConfig',
          (_) => {
            'data': {
              'mobileConfig': {'minSupportedAppVersion': 7},
            },
          },
        );
      final error = await errorOf(ConfigApi(linkExecutor(link)).mobileConfig());
      expect(
        error,
        isA<ApiServerError>()
            .having((e) => e.statusCode, 'statusCode', isNull)
            .having((e) => e.detail, 'detail', contains('MobileConfig'))
            .having((e) => e.isRetryable, 'isRetryable', isFalse),
      );
    });

    test('an ApiError thrown inside a link comes out unchanged', () async {
      final link = FixtureLink()
        ..fail('MobileConfig', const ApiServerError(statusCode: 418));
      expect(
        await errorOf(ConfigApi(linkExecutor(link)).mobileConfig()),
        const ApiServerError(statusCode: 418),
      );
    });

    test('anything unexpected is a server error, never a crash', () async {
      final link = FixtureLink()..fail('MobileConfig', StateError('boom'));
      expect(
        await errorOf(ConfigApi(linkExecutor(link)).mobileConfig()),
        isA<ApiServerError>(),
      );
    });
  });

  group('ApiError', () {
    test('equality and descriptions carry no content', () {
      expect(const ApiUnauthenticated(), const ApiUnauthenticated());
      expect(
        const ApiNetworkError(),
        isNot(const ApiNetworkError(ApiNetworkCause.timeout)),
      );
      expect(
        const ApiRejected(typename: 'BusinessError', messageKey: 'k'),
        const ApiRejected(typename: 'BusinessError', messageKey: 'k'),
      );
      expect(
        const ApiRejected(
          typename: 'BusinessError',
          messageKey: 'k',
        ).toString(),
        'ApiError.rejected(BusinessError, k)',
      );
      expect(const ApiRejected(typename: 'TechnicalError').isRetryable, isTrue);
      expect(const ApiRejected(typename: 'BusinessError').isRetryable, isFalse);
    });
  });
}
