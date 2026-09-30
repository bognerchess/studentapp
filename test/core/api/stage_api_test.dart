// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';
import 'dart:io';

import 'package:bogner_chess/core/api/stage_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixture_link.dart';
import 'api_test_support.dart';

void main() {
  late FixtureLink link;

  setUp(() => link = FixtureLink());

  StageApi api() => StageApi(linkExecutor(link));

  group('workflow', () {
    test('reads the four stages, their states and what comes next', () async {
      link.use('GameAnalysisWorkflow', 'running');
      final workflow = (await api().workflow('game-1'))!;

      expect(workflow.gameId, 'game-1');
      expect(workflow.stages.map((s) => s.stage), [
        AnalysisStage.baseEvaluation,
        AnalysisStage.baseClassification,
        AnalysisStage.deepEvaluation,
        AnalysisStage.coaching,
      ]);
      expect(
        workflow.stateOf(AnalysisStage.baseEvaluation),
        AnalysisStageState.ready,
      );
      expect(
        workflow.stateOf(AnalysisStage.baseClassification),
        AnalysisStageState.running,
      );
      expect(workflow.activeStage, AnalysisStage.baseClassification);
      expect(workflow.anyActive, isTrue);
      expect(workflow.isComplete, isFalse);
      // Nothing is runnable while a stage is in flight.
      expect(workflow.nextRunnableStage, isNull);
      expect(
        workflow.stageOf(AnalysisStage.deepEvaluation)!.blockedBy,
        AnalysisStage.baseClassification,
      );
      expect(workflow.stageOf(AnalysisStage.coaching)!.usesModel, isTrue);
      expect(
        workflow.stageOf(AnalysisStage.baseEvaluation)!.usesModel,
        isFalse,
      );
      expect(link.requestsOf('GameAnalysisWorkflow').single.variables, {
        'gameId': 'game-1',
      });
    });

    test('nothing run: the first stage is the one to start', () async {
      link.use('GameAnalysisWorkflow', 'not_run');
      final workflow = (await api().workflow('game-1'))!;

      expect(workflow.nextRunnableStage, AnalysisStage.baseEvaluation);
      expect(workflow.anyActive, isFalse);
      expect(workflow.newestReadyEngineStage, isNull);
      expect(workflow.readyRunIds, isEmpty);
      expect(workflow.stageOf(AnalysisStage.baseEvaluation)!.run, isNull);
    });

    test('engine ready: the coach is next and the run ids are there', () async {
      link.use('GameAnalysisWorkflow', 'engine_ready');
      final workflow = (await api().workflow('game-1'))!;

      expect(workflow.engineReady, isTrue);
      expect(workflow.coachReady, isFalse);
      expect(workflow.newestReadyEngineStage, AnalysisStage.deepEvaluation);
      expect(workflow.nextRunnableStage, AnalysisStage.coaching);
      expect(workflow.readyRunIds, {
        AnalysisStage.baseEvaluation: 'run-be',
        AnalysisStage.baseClassification: 'run-bc',
        AnalysisStage.deepEvaluation: 'run-de',
      });
    });

    test('all ready: complete, nothing left to run', () async {
      link.use('GameAnalysisWorkflow', 'all_ready');
      final workflow = (await api().workflow('game-1'))!;

      expect(workflow.isComplete, isTrue);
      expect(workflow.coachReady, isTrue);
      expect(workflow.nextRunnableStage, isNull);
      expect(workflow.failedStage, isNull);
    });

    test('a failed stage names itself and carries its code', () async {
      link.use('GameAnalysisWorkflow', 'stage_failed');
      final workflow = (await api().workflow('game-1'))!;

      expect(workflow.failedStage, AnalysisStage.deepEvaluation);
      final run = workflow.stageOf(AnalysisStage.deepEvaluation)!.run!;
      expect(run.status, JobStatus.failed);
      expect(run.failureCode, 'stage_input_missing');
      expect(run.hasArtifact, isFalse);
      expect(workflow.anyActive, isFalse);
    });

    test('stale: everything was computed for moves that changed', () async {
      link.use('GameAnalysisWorkflow', 'stale');
      final workflow = (await api().workflow('game-1'))!;

      for (final stage in AnalysisStage.pipeline) {
        expect(workflow.stateOf(stage), AnalysisStageState.stale);
      }
      expect(workflow.engineReady, isFalse);
      expect(workflow.readyRunIds, isEmpty);
      expect(workflow.nextRunnableStage, AnalysisStage.baseEvaluation);
    });

    test('progress comes through while a stage runs', () async {
      link.use('GameAnalysisWorkflow', 'default');
      final workflow = (await api().workflow('game-1'))!;

      final run = workflow.stageOf(AnalysisStage.baseEvaluation)!.run!;
      expect(run.status, JobStatus.running);
      expect(run.progressStage, 'scan');
      expect(run.progressDone, 8);
      expect(run.progressTotal, 21);
      expect(run.progress, closeTo(8 / 21, 1e-9));
    });

    test('a stage and a state of the future read as unknown, and an '
        'unknown stage is never the one to start', () async {
      link.use('GameAnalysisWorkflow', 'unknown_stage');
      final workflow = (await api().workflow('game-1'))!;

      final unknown = workflow.stages[1];
      expect(unknown.stage, AnalysisStage.unknown);
      expect(unknown.state, AnalysisStageState.unknown);
      // Unknown counts as active, so the tracker keeps polling instead of
      // declaring the pipeline finished.
      expect(unknown.state.isActive, isTrue);
      expect(workflow.nextRunnableStage, AnalysisStage.unknown);
      expect(
        workflow.stateOf(AnalysisStage.baseClassification),
        AnalysisStageState.notRun,
      );
    });

    test('a foreign or deleted game is null, not an error', () async {
      link.use('GameAnalysisWorkflow', 'not_found');
      expect(await api().workflow('game-9'), isNull);
    });

    test('any other top-level error is thrown', () async {
      link.respond(
        'GameAnalysisWorkflow',
        (_) => {
          'errors': [
            {
              'message': 'The request exceeds the maximum operation cost.',
              'extensions': {'code': 'HC0047'},
            },
          ],
        },
      );
      await expectLater(
        api().workflow('game-1'),
        throwsA(isA<ApiGraphQLError>()),
      );
    });

    test('offline throws, so the tracker backs off instead of '
        'forgetting the game', () async {
      link.fail('GameAnalysisWorkflow', const SocketException('offline'));
      await expectLater(
        api().workflow('game-1'),
        throwsA(isA<ApiNetworkError>()),
      );
    });
  });

  group('artifact', () {
    test('a base evaluation comes back with its nodes', () async {
      final run = (await api().artifact('run-be'))!;

      expect(run.id, 'run-be');
      expect(run.gameId, 'game-1');
      expect(run.stage, AnalysisStage.baseEvaluation);
      expect(run.status, JobStatus.done);
      expect(run.isSuperseded, isFalse);
      final json = run.artifact!.json;
      expect(json['stage'], 'base_evaluation');
      expect(json['nodes'], isA<List<dynamic>>());
      expect((json['nodes'] as List).first, isA<Map<String, dynamic>>());
      expect(link.requestsOf('EngineStageRun').single.variables, {
        'id': 'run-be',
      });
    });

    test('a classification carries the selected plies', () async {
      link.use('EngineStageRun', 'base_classification');
      final run = (await api().artifact('run-bc'))!;

      expect(run.stage, AnalysisStage.baseClassification);
      final selections = run.artifact!.json['selections'] as List;
      expect(selections.map((s) => (s as Map)['ply']), [10, 16]);
    });

    test('a deep evaluation carries accuracy and the flat engine', () async {
      link.use('EngineStageRun', 'deep_evaluation');
      final run = (await api().artifact('run-de'))!;

      expect(run.stage, AnalysisStage.deepEvaluation);
      final json = run.artifact!.json;
      expect(json['accuracy'], isA<Map<String, dynamic>>());
      expect((json['engine'] as Map)['pass1_nodes'], 400000);
    });

    test('a coaching run carries the document', () async {
      link.use('EngineStageRun', 'coaching');
      final run = (await api().artifact('run-co'))!;

      expect(run.stage, AnalysisStage.coaching);
      final document = run.artifact!.json['document'] as Map;
      expect(document['schema'], 'bognerchess.game-analysis');
    });

    test('a superseded run says so', () async {
      link.use('EngineStageRun', 'superseded');
      final run = (await api().artifact('run-be-old'))!;

      expect(run.isSuperseded, isTrue);
      expect(run.supersededAt, DateTime.utc(2026, 9, 19, 11));
    });

    test('a run that is still going has no artifact', () async {
      link.use('EngineStageRun', 'running');
      final run = (await api().artifact('run-de'))!;

      expect(run.status, JobStatus.running);
      expect(run.artifact, isNull);
      expect(run.finishedAt, isNull);
    });

    test('a failed run carries its code', () async {
      link.use('EngineStageRun', 'failed');
      final run = (await api().artifact('run-de'))!;

      expect(run.status, JobStatus.failed);
      expect(run.failureCode, 'stage_input_missing');
    });

    test('a stage and a status of the future read as unknown', () async {
      link.use('EngineStageRun', 'unknown_stage');
      final run = (await api().artifact('run-x'))!;

      expect(run.stage, AnalysisStage.unknown);
      expect(run.status, JobStatus.unknown);
    });

    test('a foreign or deleted run is null', () async {
      link.use('EngineStageRun', 'not_found');
      expect(await api().artifact('run-9'), isNull);
    });
  });

  group('GameWorkflowSummary', () {
    test('survives the round trip through the library cache', () async {
      link.use('GameAnalysisWorkflow', 'engine_ready');
      final workflow = (await api().workflow('game-1'))!;
      final summary = GameWorkflowSummary.of(workflow);

      // It is stored as JSON next to the cached game, so this has to be a map
      // a codec can write — not, say, a set of entries.
      final json = jsonDecode(jsonEncode(summary.toJson()));
      expect(json, {
        'states': {
          'BASE_EVALUATION': 'READY',
          'BASE_CLASSIFICATION': 'READY',
          'DEEP_EVALUATION': 'READY',
          'COACHING': 'NOT_RUN',
        },
        'isComplete': false,
      });
      expect(
        GameWorkflowSummary.fromJson(json! as Map<String, dynamic>),
        summary,
      );
      expect(summary.engineReady, isTrue);
      expect(summary.coachReady, isFalse);
      expect(summary.anyActive, isFalse);
      expect(summary.failedStage, isNull);
    });

    test('a row an older build wrote reads as nothing known', () {
      expect(GameWorkflowSummary.fromJson(const {}).states, isEmpty);
      // A stage or a state of the future: the stage is dropped, the state
      // reads as unknown.
      final summary = GameWorkflowSummary.fromJson(const {
        'states': {'SHINY_NEW_STAGE': 'READY', 'DEEP_EVALUATION': 'PAUSED'},
        'isComplete': false,
      });
      expect(summary.states.keys, [AnalysisStage.deepEvaluation]);
      expect(
        summary.stateOf(AnalysisStage.deepEvaluation),
        AnalysisStageState.unknown,
      );
      expect(summary.anyActive, isTrue);
    });

    test('a failed stage is named, earliest first', () async {
      link.use('GameAnalysisWorkflow', 'stage_failed');
      final summary = GameWorkflowSummary.of((await api().workflow('game-1'))!);

      expect(summary.failedStage, AnalysisStage.deepEvaluation);
      expect(summary.engineReady, isFalse);
    });
  });

  group('the engine commands', () {
    // Each of the three takes the same answers; the table keeps them honest
    // against one another.
    final commands =
        <String, Future<RequestAnalysisOutcome> Function(StageApi)>{
          'RunBaseEvaluation': (a) => a.runBaseEvaluation('game-1'),
          'RunBaseClassification': (a) => a.runBaseClassification('game-1'),
          'RunDeepEvaluation': (a) => a.runDeepEvaluation('game-1'),
        };

    for (final MapEntry(key: operation, value: call) in commands.entries) {
      group(operation, () {
        test('accepted: the queued run comes back', () async {
          final outcome = await call(api());

          expect(outcome, isA<AnalysisAccepted>());
          final run = (outcome as AnalysisAccepted).run;
          expect(run.id, 'run-new');
          expect(run.status, JobStatus.queued);
          expect(run.artifact, isNull);
          expect(outcome.stage, run.stage);
          expect(link.requestsOf(operation).single.variables['input'], {
            'chessGameId': 'game-1',
          });
        });

        test('a missing prerequisite is its own outcome', () async {
          link.use(operation, 'prerequisite_missing');
          expect(await call(api()), isA<AnalysisPrerequisiteMissing>());
        });

        test('any other business error is a plain failure', () async {
          link.use(operation, 'business_error');
          final outcome = await call(api());

          expect(outcome, isA<AnalysisRequestFailed>());
          final error = (outcome as AnalysisRequestFailed).error;
          expect(error, isA<ApiRejected>());
          expect(
            (error as ApiRejected).messageKey,
            'api_errors.entity_not_found',
          );
        });

        test('rate limited, with the seconds the server asked for', () async {
          link.use(operation, 'rate_limited');
          final outcome = await call(api());

          expect(outcome, isA<AnalysisRateLimited>());
          expect(
            (outcome as AnalysisRateLimited).retryAfter,
            const Duration(seconds: 42),
          );
        });

        test('an invalid input is a failure with the property', () async {
          link.use(operation, 'input_invalid');
          final outcome = await call(api());

          final error = (outcome as AnalysisRequestFailed).error as ApiRejected;
          expect(error.propertyName, 'ChessGameId');
        });

        test('a member this build does not know is a failure', () async {
          link.use(operation, 'unknown_error');
          final outcome = await call(api());

          expect(
            ((outcome as AnalysisRequestFailed).error as ApiRejected).typename,
            'SomethingNewError',
          );
        });

        test('offline is an outcome, never a throw', () async {
          link.fail(operation, const SocketException('offline'));
          final outcome = await call(api());

          expect(
            (outcome as AnalysisRequestFailed).error,
            isA<ApiNetworkError>(),
          );
        });

        test('a payload with neither run nor error is a failure', () async {
          link.respond(operation, (_) {
            final field = operation[0].toLowerCase() + operation.substring(1);
            return {
              'data': {
                field: {'engineStageRun': null, 'errors': null},
              },
            };
          });
          expect(await call(api()), isA<AnalysisRequestFailed>());
        });
      });
    }
  });

  group('runCoaching', () {
    test(
      'accepted: the coaching run, with language and persona sent',
      () async {
        final outcome = await api().runCoaching(
          'game-1',
          language: 'DE',
          persona: 'house',
        );

        expect(outcome, isA<AnalysisAccepted>());
        expect(link.requestsOf('RunCoaching').single.variables['input'], {
          'chessGameId': 'game-1',
          'persona': 'house',
          'language': 'de',
        });
      },
    );

    test('the house voice sends no persona', () async {
      await api().runCoaching('game-1');
      expect(
        (link.requestsOf('RunCoaching').single.variables['input']! as Map)
            .containsKey('persona'),
        isFalse,
      );
    });

    test('the day limit', () async {
      link.use('RunCoaching', 'limit_reached');
      final outcome = await api().runCoaching('game-1');

      expect(outcome, isA<AnalysisLimitReached>());
      final limit = outcome as AnalysisLimitReached;
      expect(limit.window, LimitWindow.day);
      expect(limit.limit, 3);
      expect(limit.used, 3);
      expect(limit.resetAt, DateTime.utc(2026, 9, 19, 22));
    });

    test('a window this build does not know still shows the numbers', () async {
      link.use('RunCoaching', 'limit_reached_unknown_window');
      final outcome = await api().runCoaching('game-1') as AnalysisLimitReached;

      expect(outcome.window, LimitWindow.unknown);
      expect(outcome.limit, 10);
    });

    test('the queue cap', () async {
      link.use('RunCoaching', 'queue_full');
      final outcome = await api().runCoaching('game-1');

      expect((outcome as AnalysisQueueFull).maxQueuedJobs, 2);
    });

    test('rate limited, with the seconds the server asked for', () async {
      link.use('RunCoaching', 'rate_limited');
      final outcome = await api().runCoaching('game-1');

      expect(
        (outcome as AnalysisRateLimited).retryAfter,
        const Duration(seconds: 42),
      );
    });

    test('an unverified e-mail address', () async {
      link.use('RunCoaching', 'email_not_verified');
      expect(
        await api().runCoaching('game-1'),
        isA<AnalysisEmailNotVerified>(),
      );
    });

    test('missing AI consent names the version', () async {
      link.use('RunCoaching', 'ai_consent_required');
      final outcome = await api().runCoaching('game-1');

      expect((outcome as AnalysisAiConsentRequired).requiredVersion, 1);
    });

    test('a missing deep evaluation is the prerequisite outcome', () async {
      link.use('RunCoaching', 'prerequisite_missing');
      expect(
        await api().runCoaching('game-1'),
        isA<AnalysisPrerequisiteMissing>(),
      );
    });

    test('a typed error without its fields degrades to a failure', () async {
      link.respond(
        'RunCoaching',
        (_) => {
          'data': {
            'runCoaching': {
              'engineStageRun': null,
              'errors': [
                {'__typename': 'AnalysisLimitReachedError'},
              ],
            },
          },
        },
      );
      // The generated fromJson insists on the fields the schema promises, so
      // this is a malformed response rather than a limit.
      final outcome = await api().runCoaching('game-1');
      expect((outcome as AnalysisRequestFailed).error, isA<ApiServerError>());
    });
  });
}
