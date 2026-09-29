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

  // ------------------------------------------------------- staged analysis

  Future<Map<String, dynamic>> workflowOf(String gameId) async =>
      (await data('GameAnalysisWorkflow', {
            'gameId': gameId,
          }))['gameAnalysisWorkflow']
          as Map<String, dynamic>;

  List<Map<String, dynamic>> stagesOf(Map<String, dynamic> workflow) =>
      (workflow['stages'] as List).cast<Map<String, dynamic>>();

  Map<String, Object?> statesOf(Map<String, dynamic> workflow) => {
    for (final stage in stagesOf(workflow))
      stage['stage'] as String: stage['state'],
  };

  Map<String, dynamic> stageOf(Map<String, dynamic> workflow, String stage) =>
      stagesOf(workflow).firstWhere((entry) => entry['stage'] == stage);

  /// The payload of one `run*` mutation, errors and all.
  Future<Map<String, dynamic>> runStage(
    String operation,
    String gameId, [
    Map<String, dynamic> extra = const {},
  ]) async {
    final result = await data(operation, {
      'input': {'chessGameId': gameId, ...extra},
    });
    return result.values.single as Map<String, dynamic>;
  }

  /// The run of an accepted `run*` mutation.
  Future<Map<String, dynamic>> acceptStage(
    String operation,
    String gameId, [
    Map<String, dynamic> extra = const {},
  ]) async {
    final payload = await runStage(operation, gameId, extra);
    expect(payload['errors'], isNull, reason: jsonEncode(payload));
    return payload['engineStageRun'] as Map<String, dynamic>;
  }

  /// Starts [operation] and polls the workflow until [stage] is over.
  Future<Map<String, dynamic>> finishStage(
    String operation,
    String stage,
    String gameId,
  ) async {
    await acceptStage(operation, gameId);
    for (var i = 0; i < 10; i++) {
      final workflow = await workflowOf(gameId);
      final state = statesOf(workflow)[stage];
      if (state != 'QUEUED' && state != 'RUNNING') {
        return workflow;
      }
    }
    fail('$stage of $gameId never finished');
  }

  /// The three free stages of [gameId], up to DEEP_EVALUATION READY.
  Future<void> engineChain(String gameId) async {
    await finishStage('RunBaseEvaluation', 'BASE_EVALUATION', gameId);
    await finishStage('RunBaseClassification', 'BASE_CLASSIFICATION', gameId);
    await finishStage('RunDeepEvaluation', 'DEEP_EVALUATION', gameId);
  }

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

  group('staged analysis', () {
    test(
      'a game nothing has run: the derived fields of the workflow',
      () async {
        final id = await importGame('c-1');
        final workflow = await workflowOf(id);

        expect(workflow['chessGameId'], id);
        expect(statesOf(workflow), {
          'BASE_EVALUATION': 'NOT_RUN',
          'BASE_CLASSIFICATION': 'NOT_RUN',
          'DEEP_EVALUATION': 'NOT_RUN',
          'COACHING': 'NOT_RUN',
        });
        expect(stagesOf(workflow).map((stage) => stage['runnable']), [
          true,
          false,
          false,
          false,
        ], reason: 'only the first stage can start');
        expect(stagesOf(workflow).map((stage) => stage['blockedBy']), [
          null,
          'BASE_EVALUATION',
          'BASE_CLASSIFICATION',
          'DEEP_EVALUATION',
        ]);
        expect(stagesOf(workflow).map((stage) => stage['usesModel']), [
          false,
          false,
          false,
          true,
        ]);
        expect(
          stagesOf(workflow).map((stage) => stage['run']),
          everyElement(isNull),
        );
        expect(workflow['nextRunnableStage'], 'BASE_EVALUATION');
        expect(workflow['isComplete'], isFalse);
      },
    );

    test('a game that does not exist is a top-level error', () async {
      final response = await post(
        'GameAnalysisWorkflow',
        variables: {'gameId': 'nope'},
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['data'], isNull);
      expect(
        ((body['errors'] as List).single as Map)['message'],
        'web_api_errors.entity_not_found',
      );
    });

    test('the seeded analysed game already has a finished pipeline', () async {
      final workflow = await workflowOf('game-1');

      expect(statesOf(workflow).values, everyElement('READY'));
      expect(workflow['isComplete'], isTrue);
      expect(workflow['nextRunnableStage'], isNull);
      expect(
        stagesOf(workflow).map((stage) => (stage['run'] as Map)['hasArtifact']),
        everyElement(isTrue),
      );
      expect(
        (stageOf(workflow, 'COACHING')['run'] as Map)['language'],
        'en',
        reason: 'only the coaching run carries a language',
      );
      expect(
        (stageOf(workflow, 'DEEP_EVALUATION')['run'] as Map)['language'],
        isNull,
      );
    });

    test('stage 1: QUEUED, RUNNING with progress, READY, then its '
        'artifact', () async {
      final id = await importGame('c-1');
      final run = await acceptStage('RunBaseEvaluation', id);
      expect(run['status'], 'QUEUED');
      expect(run['stage'], 'BASE_EVALUATION');
      expect(run['artifact'], isNull, reason: 'nothing to show yet');

      final states = <Object?>[];
      final progress = <Object?>[];
      for (var i = 0; i < 4; i++) {
        final stage = stageOf(await workflowOf(id), 'BASE_EVALUATION');
        final polled = stage['run'] as Map;
        states.add(stage['state']);
        progress.add(
          polled['progressDone'] == null
              ? null
              : '${polled['progressStage']} '
                    '${polled['progressDone']}/${polled['progressTotal']}',
        );
      }
      expect(states, ['QUEUED', 'RUNNING', 'RUNNING', 'READY']);
      expect(progress, [
        null,
        'base-evaluation 1/5',
        'base-evaluation 3/5',
        null,
      ]);

      final ready =
          stageOf(await workflowOf(id), 'BASE_EVALUATION')['run'] as Map;
      expect(ready['hasArtifact'], isTrue);
      expect(ready['startedAt'], isNotNull);
      expect(ready['finishedAt'], isNotNull);

      final fetched =
          (await data('EngineStageRun', {'id': run['id']}))['engineStageRun']
              as Map;
      final artifact = fetched['artifact'] as Map;
      expect(fetched['status'], 'DONE');
      expect(artifact['stage'], 'base_evaluation');
      expect(artifact['nodes'] as List, hasLength(80));
      expect(
        ((artifact['nodes'] as List).first as Map)['is_critical'],
        isFalse,
        reason: 'stage 1 marks nothing critical',
      );
      expect(
        (await data('EngineStageRun', {'id': 'nope'}))['engineStageRun'],
        isNull,
      );
    });

    test('a stage before its prerequisite is refused with the key', () async {
      final id = await importGame('c-1');
      for (final operation in [
        'RunBaseClassification',
        'RunDeepEvaluation',
        'RunCoaching',
      ]) {
        final error =
            ((await runStage(operation, id))['errors'] as List).single as Map;
        expect(error['__typename'], 'BusinessError', reason: operation);
        expect(
          error['message'],
          'web_api_errors.stage_prerequisite_missing',
          reason: operation,
        );
      }
    });

    test('tapping a stage twice returns the run that is under way', () async {
      final id = await importGame('c-1');
      final first = await acceptStage('RunBaseEvaluation', id);
      expect((await acceptStage('RunBaseEvaluation', id))['id'], first['id']);

      // Once it is over the same tap starts a new run, and the old one
      // becomes history.
      await finishStage('RunBaseEvaluation', 'BASE_EVALUATION', id);
      final again = await acceptStage('RunBaseEvaluation', id);
      expect(again['id'], isNot(first['id']));
      await finishStage('RunBaseEvaluation', 'BASE_EVALUATION', id);
      final old =
          (await data('EngineStageRun', {'id': first['id']}))['engineStageRun']
              as Map;
      expect(old['supersededAt'], isNotNull);
    });

    test('the whole chain, and the coach writes the document that '
        'GameAnalysis serves', () async {
      await scenario({'name': 'consent_accepted'});
      final id = await importGame('c-1');
      await engineChain(id);

      var workflow = await workflowOf(id);
      expect(statesOf(workflow), {
        'BASE_EVALUATION': 'READY',
        'BASE_CLASSIFICATION': 'READY',
        'DEEP_EVALUATION': 'READY',
        'COACHING': 'NOT_RUN',
      });
      expect(workflow['nextRunnableStage'], 'COACHING');
      expect(stageOf(workflow, 'COACHING')['runnable'], isTrue);
      expect(workflow['isComplete'], isFalse);
      expect(
        (await data('GameAnalysis', {'gameId': id}))['gameAnalysis'],
        isNull,
        reason: 'the engine stages write no document',
      );

      final deep = stageOf(workflow, 'DEEP_EVALUATION')['run'] as Map;
      final artifact =
          ((await data('EngineStageRun', {'id': deep['id']}))['engineStageRun']
                  as Map)['artifact']
              as Map;
      expect(artifact['stage'], 'deep_evaluation');
      expect(
        (artifact['engine'] as Map).keys,
        contains('pass1_nodes'),
        reason: 'stage 3 writes engine flat; the assembler nests it',
      );
      expect(artifact['accuracy'], isA<Map<String, dynamic>>());

      final coaching = await acceptStage('RunCoaching', id, {
        'language': 'de',
        'persona': 'calm',
      });
      workflow = await finishStage('RunCoaching', 'COACHING', id);
      expect(workflow['isComplete'], isTrue);
      expect(workflow['nextRunnableStage'], isNull);
      final run = stageOf(workflow, 'COACHING')['run'] as Map;
      expect(run['persona'], 'calm');
      expect(run['language'], 'de');

      final analysis =
          (await data('GameAnalysis', {'gameId': id}))['gameAnalysis'] as Map;
      final document = analysis['document'] as Map;
      expect(document['language'], 'de');
      expect(document['nodes'] as List, hasLength(80));
      expect(document['comments'] as List, isNotEmpty);
      expect(
        ((await data('GameById', {'id': id}))['myChessGameById']
            as Map)['hasAnalysis'],
        isTrue,
      );
      expect(
        ((await data('MyAnalysisUsage'))['myAnalysisUsage']
            as Map)['dailyUsed'],
        1,
        reason: 'only the coaching stage is metered',
      );

      // The coaching artifact wraps the very document GameAnalysis serves.
      final wrapped =
          ((await data('EngineStageRun', {
                    'id': coaching['id'],
                  }))['engineStageRun']
                  as Map)['artifact']
              as Map;
      expect(wrapped['stage'], 'coaching');
      expect(
        (wrapped['document'] as Map)['analysis_id'],
        document['analysis_id'],
      );
      expect((wrapped['llm'] as Map).keys, contains('tokens_in'));
    });

    test('the coaching stage keeps every gate: the language, the game, the '
        'consent, the address and the quota', () async {
      final id = await importGame('c-1');
      await engineChain(id);

      expect(
        errorOf(
          await data('RunCoaching', {
            'input': {'chessGameId': id, 'language': 'fr'},
          }),
        )['propertyName'],
        'Language',
      );
      expect(
        errorOf(
          await data('RunCoaching', {
            'input': {'chessGameId': 'nope'},
          }),
        )['message'],
        'web_api_errors.entity_not_found',
      );
      var error =
          ((await runStage('RunCoaching', id))['errors'] as List).single as Map;
      expect(error['__typename'], 'AiConsentRequiredError');
      expect(error['requiredVersion'], 1);

      await scenario({'name': 'consent_accepted'});
      await scenario({'name': 'email_not_verified'});
      error =
          ((await runStage('RunCoaching', id))['errors'] as List).single as Map;
      expect(error['__typename'], 'EmailNotVerifiedError');

      await scenario({'name': 'default'});
      await scenario({'name': 'consent_accepted'});
      await scenario({'name': 'limit_reached'});
      error =
          ((await runStage('RunCoaching', id))['errors'] as List).single as Map;
      expect(error['__typename'], 'AnalysisLimitReachedError');
      expect(error['window'], 'DAY');
    });

    test('two coaching runs fill the queue', () async {
      // Without the seed, whose running job would occupy a worker of its own.
      await server.close();
      await start(MockOptions(now: () => now, seed: false));
      await scenario({'name': 'consent_accepted'});
      final ids = [for (var i = 1; i <= 3; i++) await importGame('c-$i')];
      for (final id in ids) {
        await engineChain(id);
      }
      await acceptStage('RunCoaching', ids[0]);
      await acceptStage('RunCoaching', ids[1]);
      final error =
          ((await runStage('RunCoaching', ids[2]))['errors'] as List).single
              as Map;
      expect(error['__typename'], 'AnalysisQueueFullError');
      expect(error['maxQueuedJobs'], 2);
    });

    test('scenario stage_fails: BASE_EVALUATION by default, any stage on '
        'request', () async {
      await scenario({'name': 'stage_fails'});
      final first = await importGame('c-1');
      var workflow = await finishStage(
        'RunBaseEvaluation',
        'BASE_EVALUATION',
        first,
      );
      expect(statesOf(workflow)['BASE_EVALUATION'], 'FAILED');
      final failed = stageOf(workflow, 'BASE_EVALUATION')['run'] as Map;
      expect(failed['failureCode'], 'stage_input_missing');
      expect(failed['failureMessage'], 'stage failed');
      expect(failed['hasArtifact'], isFalse);
      expect(
        stageOf(workflow, 'BASE_EVALUATION')['runnable'],
        isTrue,
        reason: 'running it again is the way forward',
      );
      expect(workflow['nextRunnableStage'], 'BASE_EVALUATION');

      await scenario({'name': 'stage_fails', 'stage': 'DEEP_EVALUATION'});
      final second = await importGame('c-2');
      await finishStage('RunBaseEvaluation', 'BASE_EVALUATION', second);
      await finishStage('RunBaseClassification', 'BASE_CLASSIFICATION', second);
      workflow = await finishStage(
        'RunDeepEvaluation',
        'DEEP_EVALUATION',
        second,
      );
      expect(statesOf(workflow), {
        'BASE_EVALUATION': 'READY',
        'BASE_CLASSIFICATION': 'READY',
        'DEEP_EVALUATION': 'FAILED',
        'COACHING': 'NOT_RUN',
      });
      expect(stageOf(workflow, 'COACHING')['blockedBy'], 'DEEP_EVALUATION');

      final unknown = await scenario({'name': 'stage_fails', 'stage': 'NOPE'});
      expect(unknown.statusCode, 400);
      expect(unknown.body, contains('BASE_EVALUATION'));
    });

    test('scenario rate_limited refuses all four commands', () async {
      await scenario({'name': 'consent_accepted'});
      await scenario({'name': 'rate_limited'});
      final id = await importGame('c-1');
      for (final operation in [
        'RunBaseEvaluation',
        'RunBaseClassification',
        'RunDeepEvaluation',
        'RunCoaching',
      ]) {
        final error =
            ((await runStage(operation, id))['errors'] as List).single as Map;
        expect(error['__typename'], 'RateLimitedError', reason: operation);
        expect(error['retryAfterSeconds'], 42, reason: operation);
      }

      await scenario({'name': 'rate_limited', 'retryAfterSeconds': 7});
      expect(
        (((await runStage('RunBaseEvaluation', id))['errors'] as List).single
            as Map)['retryAfterSeconds'],
        7,
      );

      await scenario({'name': 'default'});
      expect((await runStage('RunBaseEvaluation', id))['errors'], isNull);
    });

    test('scenario stale: what was ready reads STALE, and stage 1 can run '
        'again', () async {
      await scenario({'name': 'stale'});
      var workflow = await workflowOf('game-1');
      expect(statesOf(workflow).values, everyElement('STALE'));
      expect(workflow['isComplete'], isFalse);
      expect(workflow['nextRunnableStage'], 'BASE_EVALUATION');
      expect(stagesOf(workflow).map((stage) => stage['runnable']), [
        true,
        false,
        false,
        false,
      ]);
      expect(
        stageOf(workflow, 'BASE_CLASSIFICATION')['blockedBy'],
        'BASE_EVALUATION',
      );
      expect(
        (await data('GameAnalysis', {'gameId': 'game-1'}))['gameAnalysis'],
        isNotNull,
        reason: 'a stale document is still readable',
      );

      workflow = await finishStage(
        'RunBaseEvaluation',
        'BASE_EVALUATION',
        'game-1',
      );
      expect(statesOf(workflow)['BASE_EVALUATION'], 'READY');
      expect(statesOf(workflow)['BASE_CLASSIFICATION'], 'STALE');
      expect(workflow['nextRunnableStage'], 'BASE_CLASSIFICATION');
    });

    test('a stage run can go by the clock too', () async {
      await server.close();
      await start(
        MockOptions(now: () => now, jobDuration: const Duration(seconds: 30)),
      );
      final id = await importGame('c-1');
      await acceptStage('RunBaseEvaluation', id);
      expect(statesOf(await workflowOf(id))['BASE_EVALUATION'], 'QUEUED');
      now = now.add(const Duration(seconds: 11));
      expect(statesOf(await workflowOf(id))['BASE_EVALUATION'], 'RUNNING');
      now = now.add(const Duration(seconds: 20));
      expect(statesOf(await workflowOf(id))['BASE_EVALUATION'], 'READY');
    });

    test('the coach is metered: the fourth document of the day is '
        'refused', () async {
      await server.close();
      await start(MockOptions(now: () => now, queuedPolls: 0, runningPolls: 0));
      await scenario({'name': 'consent_accepted'});
      for (var i = 1; i <= 3; i++) {
        final id = await importGame('c-$i');
        await engineChain(id);
        await finishStage('RunCoaching', 'COACHING', id);
        final usage = (await data('MyAnalysisUsage'))['myAnalysisUsage'] as Map;
        expect(usage['dailyUsed'], i);
        expect(usage['dailyLimit'], 3);
        expect(usage['queuedJobs'], 0, reason: 'the run is over');
      }
      final fourth = await importGame('c-4');
      await engineChain(fourth);
      final refused =
          ((await runStage('RunCoaching', fourth))['errors'] as List).single
              as Map;
      expect(refused['__typename'], 'AnalysisLimitReachedError');
      expect(refused['window'], 'DAY');
      expect(refused['limit'], 3);
      expect(refused['used'], 3);
      expect(refused['resetAt'], '2026-09-20T00:00:00.000Z');
      expect(
        statesOf(await workflowOf(fourth))['COACHING'],
        'NOT_RUN',
        reason: 'a refused command starts no run',
      );
    });

    test('every coached game has comment ids of its own, and feedback is '
        'remembered per comment', () async {
      await server.close();
      await start(MockOptions(now: () => now, queuedPolls: 0, runningPolls: 0));
      await scenario({'name': 'consent_accepted'});

      Future<Map<String, dynamic>> coached(String clientGameId) async {
        final id = await importGame(clientGameId);
        await engineChain(id);
        await finishStage('RunCoaching', 'COACHING', id);
        return (await data('GameAnalysis', {'gameId': id}))['gameAnalysis']
            as Map<String, dynamic>;
      }

      Set<String> commentIds(Map<String, dynamic> analysis) => {
        for (final c in (analysis['document'] as Map)['comments'] as List)
          (c as Map)['id'] as String,
      };

      final first = await coached('c-1');
      final second = await coached('c-2');
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

    test('GET /__state lists the workflows, and reset forgets them', () async {
      final id = await importGame('c-1');
      await finishStage('RunBaseEvaluation', 'BASE_EVALUATION', id);

      final base = server.graphqlUri.resolve('/');
      var state =
          jsonDecode((await http.get(base.resolve('__state'))).body) as Map;
      expect(state['workflows'], {
        'game-1': {
          'BASE_EVALUATION': 'READY',
          'BASE_CLASSIFICATION': 'READY',
          'DEEP_EVALUATION': 'READY',
          'COACHING': 'READY',
        },
        id: {
          'BASE_EVALUATION': 'READY',
          'BASE_CLASSIFICATION': 'NOT_RUN',
          'DEEP_EVALUATION': 'NOT_RUN',
          'COACHING': 'NOT_RUN',
        },
      });
      expect((state['flags'] as Map)['stage_fails'], isNull);
      expect((state['flags'] as Map)['rate_limited'], isFalse);

      state = jsonDecode((await scenario({'name': 'reset'})).body) as Map;
      expect((state['workflows'] as Map).keys, ['game-1']);

      await data('DeleteChessGame', {
        'input': {'chessGameId': 'game-1'},
      });
      state = jsonDecode((await http.get(base.resolve('__state'))).body) as Map;
      expect(state['workflows'], isEmpty);
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

    test('the AI consent is recorded once and is then no longer '
        'required', () async {
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
      await scenario({'name': 'consent_required'});
      expect(
        ((await data('MyAiConsent'))['myAiConsent'] as Map)['required'],
        isTrue,
      );
    });

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
