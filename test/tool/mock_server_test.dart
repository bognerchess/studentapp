// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../tool/mock_server/mock_server.dart';

/// The mock server's own test: plain HTTP, the way curl talks to it.
void main() {
  late MockServer server;
  late DateTime now;

  const headers = {
    'Authorization': 'Bearer anything',
    'X-Tenant-Slug': 'test-tenant',
    'Content-Type': 'application/json',
  };

  Future<MockServer> start(MockOptions options) async =>
      server = await MockServer.start(backend: MockBackend(options: options));

  setUp(() async {
    now = DateTime.utc(2026, 9, 19, 10);
    await start(MockOptions(now: () => now));
  });

  tearDown(() => server.close());

  Future<http.Response> post(
    String operationName, {
    Map<String, dynamic> variables = const {},
    Map<String, String> withHeaders = headers,
  }) => http.post(
    server.graphqlUri,
    headers: withHeaders,
    body: jsonEncode({'operationName': operationName, 'variables': variables}),
  );

  Future<Map<String, dynamic>> data(
    String operationName, [
    Map<String, dynamic> variables = const {},
  ]) async {
    final response = await post(operationName, variables: variables);
    expect(response.statusCode, 200, reason: response.body);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    expect(body['errors'], isNull, reason: response.body);
    return body['data'] as Map<String, dynamic>;
  }

  Future<http.Response> scenario(Map<String, dynamic> body) =>
      http.post(server.scenarioUri, body: jsonEncode(body));

  Map<String, dynamic> importInput(String clientGameId, {String? pgn}) => {
    'input': {
      'clientGameId': clientGameId,
      'pgn':
          pgn ??
          '[White "Fake User"]\n[Black "Ada Lovelace"]\n[Date "2026.09.18"]\n'
              '[Result "1-0"]\n\n1. e4 e5 2. Nf3 {a comment} Nc6 (2... d6) 3. Bb5 1-0',
      'playerColor': 'WHITE',
      'source': 'MOBILE_BOARD',
    },
  };

  Future<String> importGame(String clientGameId) async {
    final result = await data('ImportMobileGame', importInput(clientGameId));
    return ((result['importMobileGame'] as Map)['chessGame'] as Map)['id']
        as String;
  }

  Map<String, dynamic> errorOf(Map<String, dynamic> data) =>
      ((data.values.single as Map)['errors'] as List).single
          as Map<String, dynamic>;

  group('HTTP', () {
    test('health, state and unknown routes', () async {
      final base = server.graphqlUri.resolve('/');
      expect((await http.get(base.resolve('healthz'))).body, 'ok');
      final state =
          jsonDecode((await http.get(base.resolve('__state'))).body) as Map;
      expect(state['games'], 3);
      expect(state['aiConsentAccepted'], isFalse);
      expect((await http.get(base.resolve('nope'))).statusCode, 404);
    });

    test('401 without a bearer token', () async {
      for (final bad in [
        {'X-Tenant-Slug': 't'},
        {'X-Tenant-Slug': 't', 'Authorization': 'Basic abc'},
        {'X-Tenant-Slug': 't', 'Authorization': 'Bearer '},
      ]) {
        final response = await post('MobileConfig', withHeaders: bad);
        expect(response.statusCode, 401);
        expect(response.body, contains('AUTH_NOT_AUTHENTICATED'));
      }
      expect(server.requests.map((r) => r.status), everyElement(401));
    });

    test('400 without the tenant', () async {
      final response = await post(
        'MobileConfig',
        withHeaders: {'Authorization': 'Bearer x'},
      );
      expect(response.statusCode, 400);
    });

    test('any bearer token is accepted; the operation name may come from the '
        'query text', () async {
      final response = await http.post(
        server.graphqlUri,
        headers: headers,
        body: jsonEncode({
          'query': 'query MobileConfig { mobileConfig { x } }',
        }),
      );
      expect(response.statusCode, 200);
      expect(response.body, contains('minSupportedAppVersion'));
    });

    test('an unknown operation is a GraphQL error; junk is a 400', () async {
      final unknown = await post('Nope');
      expect(unknown.body, contains('MOCK_UNKNOWN_OPERATION'));
      final junk = await http.post(
        server.graphqlUri,
        headers: headers,
        body: '[1]',
      );
      expect(junk.statusCode, 400);
    });
  });

  group('scenarios', () {
    test('unknown names and missing names are refused with the list', () async {
      final unknown = await scenario({'name': 'nope'});
      expect(unknown.statusCode, 400);
      expect(unknown.body, contains('limit_reached'));
      expect((await scenario({})).statusCode, 400);
    });

    test('every documented scenario is accepted', () async {
      for (final name in kScenarioNames.where((name) => name != 'fixture')) {
        expect((await scenario({'name': name})).statusCode, 200, reason: name);
      }
    });

    test('unauthenticated_once: one 401, then business as usual', () async {
      await scenario({'name': 'unauthenticated_once'});
      expect((await post('MobileConfig')).statusCode, 401);
      expect((await post('MobileConfig')).statusCode, 200);
    });

    test('slow delays every answer', () async {
      await scenario({'name': 'slow', 'delayMs': 150});
      final watch = Stopwatch()..start();
      await post('MobileConfig');
      expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(140));
      await scenario({'name': 'default'});
      watch.reset();
      await post('MobileConfig');
      expect(watch.elapsedMilliseconds, lessThan(140));
    });

    test('fixture pins an operation to any fixture', () async {
      final pinned = await scenario({
        'name': 'fixture',
        'operation': 'MyAnalysisUsage',
        'scenario': 'unlimited',
      });
      expect(pinned.statusCode, 200);
      final usage = (await data('MyAnalysisUsage'))['myAnalysisUsage'] as Map;
      expect(usage['policy'], 'UNLIMITED');

      final missing = await scenario({
        'name': 'fixture',
        'operation': 'MyAnalysisUsage',
        'scenario': 'nope',
      });
      expect(missing.statusCode, 400);
      expect(missing.body, contains('unlimited'));

      await scenario({'name': 'default'});
      expect(
        ((await data('MyAnalysisUsage'))['myAnalysisUsage'] as Map)['policy'],
        'DEFAULT',
      );
    });

    test('reset forgets everything, default only the flags', () async {
      await importGame('c-1');
      await scenario({'name': 'email_not_verified'});
      await scenario({'name': 'default'});
      var state = jsonDecode((await scenario({'name': 'default'})).body) as Map;
      expect(state['games'], 4);
      expect((state['flags'] as Map)['email_not_verified'], isFalse);
      state = jsonDecode((await scenario({'name': 'reset'})).body) as Map;
      expect(state['games'], 3);
    });
  });

  group('games', () {
    test('seeded library: sorted, searchable, paged', () async {
      final all = (await data('MyMobileGames'))['myMobileGames'] as Map;
      expect(all['totalCount'], 3);
      expect((all['nodes'] as List).map((g) => (g as Map)['id']), [
        'game-1',
        'game-2',
        'game-3',
      ]);
      expect(
        ((all['nodes'] as List).first as Map).containsKey('rawPgn'),
        isFalse,
      );

      final first =
          (await data('MyMobileGames', {'first': 2}))['myMobileGames'] as Map;
      expect((first['pageInfo'] as Map)['hasNextPage'], isTrue);
      final cursor = (first['pageInfo'] as Map)['endCursor'];
      final rest =
          (await data('MyMobileGames', {
                'first': 2,
                'after': cursor,
              }))['myMobileGames']
              as Map;
      expect((rest['nodes'] as List).map((g) => (g as Map)['id']), ['game-3']);
      expect((rest['pageInfo'] as Map)['hasNextPage'], isFalse);

      final search =
          (await data('MyMobileGames', {'search': 'ØSTER'}))['myMobileGames']
              as Map;
      expect((search['nodes'] as List).map((g) => (g as Map)['id']), [
        'game-2',
      ]);

      final dated =
          (await data('MyMobileGames', {
                'playedFrom': '2026-09-06',
                'playedTo': '2026-09-30',
              }))['myMobileGames']
              as Map;
      expect((dated['nodes'] as List).map((g) => (g as Map)['id']), ['game-1']);
    });

    test('the analysed seed game has the moves of its analysis', () async {
      final game =
          (await data('GameById', {'id': 'game-1'}))['myChessGameById'] as Map;
      expect(game['rawPgn'], contains('1. e4 c5 2. Nf3 g6'));
      expect(game['hasAnalysis'], isTrue);
      expect(
        (await data('GameById', {'id': 'nope'}))['myChessGameById'],
        isNull,
      );
    });

    test('import is remembered, idempotent, and reads the PGN tags', () async {
      final id = await importGame('c-1');
      expect(await importGame('c-1'), id);
      expect(await importGame('c-2'), isNot(id));

      final list = (await data('MyMobileGames'))['myMobileGames'] as Map;
      expect(list['totalCount'], 5);
      final game =
          (await data('GameById', {'id': id}))['myChessGameById'] as Map;
      expect(game['blackPlayerName'], 'Ada Lovelace');
      expect(game['opponentName'], 'Ada Lovelace');
      expect(game['playedDate'], '2026-09-18');
      expect(game['result'], 'WHITE_WINS');
      expect(game['hasAnalysis'], isFalse);
      expect(game['latestAnalysisJob'], isNull);
    });

    test('import errors', () async {
      final invalid = errorOf(
        await data(
          'ImportMobileGame',
          importInput('c', pgn: '1. e4 e5 2. Qxz9 Nc6'),
        ),
      );
      expect(invalid['__typename'], 'PgnInvalidError');
      expect(invalid['moveNumber'], 2);
      expect(invalid['san'], 'Qxz9');

      final empty = errorOf(
        await data('ImportMobileGame', importInput('c', pgn: '*')),
      );
      expect(empty['__typename'], 'PgnInvalidError');

      final tooLong = errorOf(
        await data('ImportMobileGame', importInput('c', pgn: '1. e4 ' * 20000)),
      );
      expect(tooLong['propertyName'], 'Pgn');

      final web = importInput('c');
      (web['input'] as Map)['source'] = 'WEB';
      expect(
        errorOf(await data('ImportMobileGame', web))['propertyName'],
        'Source',
      );
    });

    test('delete', () async {
      final id = await importGame('c-1');
      final deleted = await data('DeleteChessGame', {
        'input': {'chessGameId': id},
      });
      expect(
        ((deleted['deleteChessGame'] as Map)['chessGame'] as Map)['id'],
        id,
      );
      expect((await data('GameById', {'id': id}))['myChessGameById'], isNull);
      final again = await data('DeleteChessGame', {
        'input': {'chessGameId': id},
      });
      expect(errorOf(again)['__typename'], 'BusinessError');
    });
  });

  group('analysis', () {
    Future<Map<String, dynamic>> request(
      String gameId, {
      String language = 'en',
    }) => data('RequestGameAnalysis', {
      'input': {'chessGameId': gameId, 'language': language},
    });

    Future<Map<String, dynamic>> accepted(String gameId) async {
      final payload = (await request(gameId))['requestGameAnalysis'] as Map;
      expect(payload['errors'], isNull);
      return payload['analysisJob'] as Map<String, dynamic>;
    }

    Future<String> statusOf(String jobId) async =>
        ((await data('AnalysisJob', {'id': jobId}))['analysisJob']
                as Map)['status']
            as String;

    test('AI consent is required until it is recorded', () async {
      final id = await importGame('c-1');
      final refused = errorOf(await request(id));
      expect(refused['__typename'], 'AiConsentRequiredError');
      expect(refused['requiredVersion'], 1);
      expect(
        ((await data('MyAiConsent'))['myAiConsent'] as Map)['required'],
        isTrue,
      );

      final wrong = await data('RecordAiConsent', {
        'input': {'version': 7},
      });
      expect(errorOf(wrong)['propertyName'], 'Version');

      final recorded = await data('RecordAiConsent', {
        'input': {'version': 1},
      });
      expect(
        ((recorded['recordAiConsent'] as Map)['aiConsentStatus']
            as Map)['required'],
        isFalse,
      );
      await accepted(id);

      await scenario({'name': 'consent_required'});
      final other = await importGame('c-2');
      expect(
        errorOf(await request(other))['__typename'],
        'AiConsentRequiredError',
      );
    });

    test('a job goes QUEUED, RUNNING, DONE across polls; then the analysis '
        'is there', () async {
      await scenario({'name': 'consent_accepted'});
      final id = await importGame('c-1');
      final job = await accepted(id);
      expect(job['status'], 'QUEUED');
      expect(job['queuePosition'], 0);

      expect(
        (await data('GameAnalysis', {'gameId': id}))['gameAnalysis'],
        isNull,
      );
      expect(
        [for (var i = 0; i < 4; i++) await statusOf(job['id'] as String)],
        ['QUEUED', 'RUNNING', 'RUNNING', 'DONE'],
      );

      final game =
          (await data('GameById', {'id': id}))['myChessGameById'] as Map;
      expect(game['hasAnalysis'], isTrue);
      expect((game['latestAnalysisJob'] as Map)['status'], 'DONE');
      final analysis =
          (await data('GameAnalysis', {'gameId': id}))['gameAnalysis'] as Map;
      expect(analysis['schemaVersion'], 1);
      expect(((analysis['document'] as Map)['nodes'] as List), hasLength(80));
    });

    test('asking again while a job is under way returns that job', () async {
      await scenario({'name': 'consent_accepted'});
      final id = await importGame('c-1');
      final first = await accepted(id);
      final second = await accepted(id);
      expect(second['id'], first['id']);
      final usage = (await data('MyAnalysisUsage'))['myAnalysisUsage'] as Map;
      expect(usage['dailyUsed'], 1);
    });

    test('active jobs are polled together and disappear when done', () async {
      await scenario({'name': 'consent_accepted'});
      final job = await accepted(await importGame('c-1'));
      Future<List<Object?>> active() async => [
        for (final j
            in (await data('MyActiveAnalysisJobs'))['myActiveAnalysisJobs']
                as List)
          if ((j as Map)['id'] == job['id']) j['status'],
      ];
      expect(await active(), ['QUEUED']);
      expect(await active(), ['RUNNING']);
      expect(await active(), ['RUNNING']);
      expect(await active(), isEmpty);
      expect(await statusOf(job['id'] as String), 'DONE');
    });

    test('jobs can go by the clock instead', () async {
      await server.close();
      await start(
        MockOptions(now: () => now, jobDuration: const Duration(seconds: 30)),
      );
      await scenario({'name': 'consent_accepted'});
      final job = await accepted(await importGame('c-1'));
      final jobId = job['id'] as String;
      expect(await statusOf(jobId), 'QUEUED');
      now = now.add(const Duration(seconds: 11));
      expect(await statusOf(jobId), 'RUNNING');
      now = now.add(const Duration(seconds: 20));
      expect(await statusOf(jobId), 'DONE');
    });

    test(
      'usage counts up and the fourth analysis of the day is refused',
      () async {
        await server.close();
        await start(
          MockOptions(now: () => now, queuedPolls: 0, runningPolls: 0),
        );
        await scenario({'name': 'consent_accepted'});
        for (var i = 1; i <= 3; i++) {
          final job = await accepted(await importGame('c-$i'));
          expect(await statusOf(job['id'] as String), 'DONE');
          final usage =
              (await data('MyAnalysisUsage'))['myAnalysisUsage'] as Map;
          expect(usage['dailyUsed'], i);
          expect(usage['dailyLimit'], 3);
        }
        final refused = errorOf(await request(await importGame('c-4')));
        expect(refused['__typename'], 'AnalysisLimitReachedError');
        expect(refused['window'], 'DAY');
        expect(refused['limit'], 3);
        expect(refused['used'], 3);
        expect(refused['resetAt'], '2026-09-20T00:00:00.000Z');
      },
    );

    test('scenario limit_reached refuses right away', () async {
      await scenario({'name': 'consent_accepted'});
      await scenario({'name': 'limit_reached'});
      final refused = errorOf(await request(await importGame('c-1')));
      expect(refused['__typename'], 'AnalysisLimitReachedError');
    });

    test('the queue is full after two active jobs', () async {
      await server.close();
      await start(MockOptions(now: () => now, seed: false));
      await scenario({'name': 'consent_accepted'});
      await accepted(await importGame('c-1'));
      final second = await accepted(await importGame('c-2'));
      expect(
        second['queuePosition'],
        0,
        reason: 'same instant: nobody is ahead',
      );
      final refused = errorOf(await request(await importGame('c-3')));
      expect(refused['__typename'], 'AnalysisQueueFullError');
      expect(refused['maxQueuedJobs'], 2);
    });

    test('email_not_verified, job_fails, a language the coach does not speak, '
        'a game that does not exist', () async {
      await scenario({'name': 'consent_accepted'});
      final id = await importGame('c-1');
      expect(
        errorOf(await request(id, language: 'fr'))['propertyName'],
        'Language',
      );
      expect(errorOf(await request('nope'))['__typename'], 'BusinessError');

      await scenario({'name': 'email_not_verified'});
      expect(errorOf(await request(id))['__typename'], 'EmailNotVerifiedError');

      await scenario({'name': 'default'});
      await scenario({'name': 'job_fails'});
      final job = await accepted(id);
      for (var i = 0; i < 3; i++) {
        await statusOf(job['id'] as String);
      }
      final failed =
          (await data('AnalysisJob', {'id': job['id']}))['analysisJob'] as Map;
      expect(failed['status'], 'FAILED');
      expect(failed['failureCode'], 'engine_timeout');
      expect(
        (await data('GameAnalysis', {'gameId': id}))['gameAnalysis'],
        isNull,
      );
    });

    test('every analysis has comment ids of its own, and feedback is '
        'remembered per comment', () async {
      await server.close();
      await start(MockOptions(now: () => now, queuedPolls: 0, runningPolls: 0));
      await scenario({'name': 'consent_accepted'});

      Future<Map<String, dynamic>> analysed(String clientGameId) async {
        final id = await importGame(clientGameId);
        final job = await accepted(id);
        await statusOf(job['id'] as String);
        return (await data('GameAnalysis', {'gameId': id}))['gameAnalysis']
            as Map<String, dynamic>;
      }

      Set<String> commentIds(Map<String, dynamic> analysis) => {
        for (final c in (analysis['document'] as Map)['comments'] as List)
          (c as Map)['id'] as String,
      };

      final first = await analysed('c-1');
      final second = await analysed('c-2');
      final seeded =
          (await data('GameAnalysis', {'gameId': 'game-1'}))['gameAnalysis']
              as Map<String, dynamic>;
      expect(commentIds(first), hasLength(8));
      expect(commentIds(first).intersection(commentIds(second)), isEmpty);
      expect(commentIds(first).intersection(commentIds(seeded)), isEmpty);
      // The references inside the document moved along.
      final referenced = {
        for (final node in (first['document'] as Map)['nodes'] as List)
          ...((node as Map)['comment_ids'] as List? ?? const <Object?>[])
              .cast<String>(),
      };
      expect(referenced, commentIds(first));

      final commentId = commentIds(first).first;
      final up = await data('SubmitCoachCommentFeedback', {
        'input': {'commentId': commentId, 'rating': 'UP'},
      });
      expect(
        ((up['submitCoachCommentFeedback'] as Map)['coachCommentFeedback']
            as Map)['rating'],
        'UP',
      );
      final gameId = first['chessGameId'];
      var feedback =
          ((await data('GameAnalysis', {'gameId': gameId}))['gameAnalysis']
                  as Map)['commentFeedback']
              as List;
      expect(feedback.single, containsPair('commentId', commentId));
      expect(
        ((await data('GameAnalysis', {
              'gameId': second['chessGameId'],
            }))['gameAnalysis']
            as Map)['commentFeedback'],
        isEmpty,
      );

      final cleared = await data('SubmitCoachCommentFeedback', {
        'input': {'commentId': commentId, 'rating': null},
      });
      expect(
        (cleared['submitCoachCommentFeedback'] as Map)['coachCommentFeedback'],
        isNull,
      );
      feedback =
          ((await data('GameAnalysis', {'gameId': gameId}))['gameAnalysis']
                  as Map)['commentFeedback']
              as List;
      expect(feedback, isEmpty);

      final unknown = await data('SubmitCoachCommentFeedback', {
        'input': {'commentId': 'nope', 'rating': 'UP'},
      });
      expect(errorOf(unknown)['message'], 'web_api_errors.comment_not_found');
    });
  });

  group('legal, devices, events, account', () {
    test(
      'legal documents by key and language, English as the fallback',
      () async {
        final german =
            (await data('LegalDocument', {
                  'key': 'PRIVACY_POLICY',
                  'language': 'de',
                }))['legalDocument']
                as Map;
        expect(german['title'], 'Datenschutzerklärung');
        final fallback =
            (await data('LegalDocument', {
                  'key': 'TERMS',
                  'language': 'fr',
                }))['legalDocument']
                as Map;
        expect(fallback['language'], 'en');
        expect(
          (await data('LegalDocument', {
            'key': 'NOPE',
            'language': 'en',
          }))['legalDocument'],
          isNull,
        );
      },
    );

    test(
      'analytics consent: accept, withdraw, and events are then rejected',
      () async {
        Map<String, dynamic> events(int count) => {
          'input': {
            'deviceId': 'd',
            'sessionId': 's',
            'events': [
              for (var i = 0; i < count; i++)
                {'name': 'app_opened', 'occurredAt': '2026-09-19T10:00:00Z'},
            ],
          },
        };

        var status =
            (await data('MyConsent', {'key': 'ANALYTICS_CONSENT'}))['myConsent']
                as Map;
        expect(status['required'], isTrue);
        expect(status['withdrawnAt'], isNull);

        var batch =
            ((await data('TrackMobileEvents', events(3)))['trackMobileEvents']
                    as Map)['eventBatch']
                as Map;
        expect(batch, {'accepted': 3, 'rejected': 0});

        await data('RecordConsent', {
          'input': {
            'key': 'ANALYTICS_CONSENT',
            'version': 1,
            'accepted': false,
          },
        });
        status =
            (await data('MyConsent', {'key': 'ANALYTICS_CONSENT'}))['myConsent']
                as Map;
        expect(status['withdrawnAt'], '2026-09-19T10:00:00.000Z');
        batch =
            ((await data('TrackMobileEvents', events(2)))['trackMobileEvents']
                    as Map)['eventBatch']
                as Map;
        expect(batch, {'accepted': 0, 'rejected': 2});

        expect(
          errorOf(await data('TrackMobileEvents', events(51)))['propertyName'],
          'Events',
        );
      },
    );

    test('devices', () async {
      final registered = await data('RegisterMobileDevice', {
        'input': {'deviceId': 'installation-1', 'environment': 'SANDBOX'},
      });
      final device =
          (registered['registerMobileDevice'] as Map)['mobileDevice'] as Map;
      expect(device['deviceId'], 'installation-1');
      expect(device['revokedAt'], isNull);

      final gone = await data('UnregisterMobileDevice', {
        'input': {'deviceId': 'installation-1'},
      });
      expect(
        ((gone['unregisterMobileDevice'] as Map)['mobileDevice']
            as Map)['revokedAt'],
        isNotNull,
      );
      final unknown = await data('UnregisterMobileDevice', {
        'input': {'deviceId': 'never-seen'},
      });
      expect(
        (unknown['unregisterMobileDevice'] as Map)['mobileDevice'],
        isNull,
      );
      expect((unknown['unregisterMobileDevice'] as Map)['errors'], isNull);
    });

    test('account deletion', () async {
      final wrong = await data('DeleteMyAccount', {
        'input': {'confirmation': 'yes please'},
      });
      expect(errorOf(wrong)['propertyName'], 'Confirmation');

      await scenario({'name': 'deletion_blocked'});
      final blocked = await data('DeleteMyAccount', {
        'input': {'confirmation': 'DELETE'},
      });
      expect(errorOf(blocked)['__typename'], 'AccountDeletionBlockedError');

      await scenario({'name': 'default'});
      final deleted = await data('DeleteMyAccount', {
        'input': {'confirmation': ' delete '},
      });
      expect(
        ((deleted['deleteMyAccount'] as Map)['accountDeletion']
            as Map)['status'],
        'PENDING',
      );
      expect(
        ((await data('MyMobileGames'))['myMobileGames'] as Map)['totalCount'],
        0,
      );
    });
  });
}
