// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bogner_chess/core/api/analysis_api.dart' show AnalysisApi;
import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/api/stage_api.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/features/analysis_status/domain/workflow_tracker.dart';
import 'package:bogner_chess/features/library/data/cached_games_repository.dart';
import 'package:bogner_chess/features/library/domain/game_summary_codec.dart';
import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/api/api_test_support.dart';
import '../../core/storage/test_database.dart';
import '../../helpers/fixture_link.dart';

const _be = 'BASE_EVALUATION';
const _bc = 'BASE_CLASSIFICATION';
const _de = 'DEEP_EVALUATION';
const _co = 'COACHING';
const _stages = [_be, _bc, _de, _co];

/// An in-memory database whose query streams close synchronously.
///
/// drift otherwise keeps a closed stream's cache alive for one more turn of
/// the event loop, with a timer. Under a fake clock that timer would still be
/// pending when the test ends, and cancelling the subscription would wait for
/// it for ever.
AppDatabase openTrackerDatabase(FakeClock clock) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
    clock: clock.call,
  );
}

/// Completes [future] under the fake clock and returns its value.
T settle<T>(FakeAsync async, Future<T> future) {
  Object? value;
  var done = false;
  unawaited(
    future.then((result) {
      value = result;
      done = true;
    }),
  );
  async.flushMicrotasks();
  expect(done, isTrue, reason: 'the future did not complete');
  return value as T;
}

/// A scripted pipeline: one state per stage per game, and the run ids that go
/// with them.
///
/// The derived fields (`runnable`, `blockedBy`, `nextRunnableStage`,
/// `isComplete`) are computed the way the backend computes them, so a test
/// cannot set up a workflow the server could never send. `RUNNING` never
/// finishes on its own — the test says when a stage is ready.
class StageServer {
  StageServer(this.link, this.store) {
    link
      ..respond('GameAnalysisWorkflow', (variables) {
        final gameId = variables['gameId'] as String;
        if (missing.contains(gameId)) {
          return {
            'errors': [
              {'message': 'The game does not exist.'},
            ],
          };
        }
        return {
          'data': {'gameAnalysisWorkflow': _workflow(gameId)},
        };
      })
      ..respond('EngineStageRun', (variables) {
        final runId = variables['id'] as String;
        return {
          'data': {'engineStageRun': _run(runId)},
        };
      });
    for (final entry in const {
      'RunBaseEvaluation': (_be, 'runBaseEvaluation'),
      'RunBaseClassification': (_bc, 'runBaseClassification'),
      'RunDeepEvaluation': (_de, 'runDeepEvaluation'),
    }.entries) {
      final (stage, field) = entry.value;
      link.respond(entry.key, (variables) {
        final gameId = (variables['input']! as Map)['chessGameId']! as String;
        started.add((gameId: gameId, stage: stage));
        final refusal = refuse.remove(stage);
        if (refusal != null) {
          return {
            'data': {
              field: {
                'engineStageRun': null,
                'errors': [refusal],
              },
            },
          };
        }
        set(gameId, stage, 'QUEUED');
        return {
          'data': {
            field: {
              'engineStageRun': _run(runIdOf(gameId, stage)),
              'errors': null,
            },
          },
        };
      });
    }
  }

  final FixtureLink link;
  final FixtureStore store;

  /// State per game per stage; a game that is not in here has never run.
  final Map<String, Map<String, String>> states = {};

  /// Games the server does not know (deleted, or never this user's).
  final Set<String> missing = {};

  /// A refusal to answer the next command of that stage with.
  final Map<String, Map<String, dynamic>> refuse = {};

  /// Which stage was started for which game, in order.
  final List<({String gameId, String stage})> started = [];

  /// Bumped when a stage is run again, so its run id changes.
  final Map<String, int> _generation = {};

  String runIdOf(String gameId, String stage) {
    final generation = _generation['$gameId/$stage'] ?? 1;
    return 'run-$gameId-${stage.toLowerCase()}-$generation';
  }

  void set(String gameId, String stage, String state) {
    (states[gameId] ??= {})[stage] = state;
  }

  /// Puts [stage] into READY with a **new** run id, as a re-run does.
  void rerun(String gameId, String stage) {
    final key = '$gameId/$stage';
    _generation[key] = (_generation[key] ?? 1) + 1;
    set(gameId, stage, 'READY');
  }

  void setAll(String gameId, Map<String, String> byStage) {
    for (final MapEntry(:key, :value) in byStage.entries) {
      set(gameId, key, value);
    }
  }

  String stateOf(String gameId, String stage) =>
      states[gameId]?[stage] ?? 'NOT_RUN';

  int workflowQueriesOf(String gameId) => [
    for (final request in link.requestsOf('GameAnalysisWorkflow'))
      if (request.variables['gameId'] == gameId) request,
  ].length;

  List<String> get artifactFetches => [
    for (final request in link.requestsOf('EngineStageRun'))
      request.variables['id']! as String,
  ];

  int get analysisFetches => link.requestsOf('GameAnalysis').length;

  Map<String, dynamic> _workflow(String gameId) {
    final byStage = [for (final s in _stages) stateOf(gameId, s)];
    final active = byStage.any((s) => s == 'QUEUED' || s == 'RUNNING');
    final stages = <Map<String, dynamic>>[];
    for (var i = 0; i < _stages.length; i++) {
      final earlier = [
        for (var j = 0; j < i; j++)
          if (byStage[j] != 'READY') _stages[j],
      ];
      stages.add({
        'stage': _stages[i],
        'state': byStage[i],
        'runnable': earlier.isEmpty && !active && byStage[i] != 'READY',
        'blockedBy': earlier.isEmpty ? null : earlier.last,
        'usesModel': _stages[i] == _co,
        'run': byStage[i] == 'NOT_RUN'
            ? null
            : _summary(gameId, _stages[i], byStage[i]),
      });
    }
    return {
      'chessGameId': gameId,
      'stages': stages,
      'nextRunnableStage': stages.cast<Map<String, dynamic>?>().firstWhere(
        (s) => s!['runnable'] == true,
        orElse: () => null,
      )?['stage'],
      'isComplete': byStage.every((s) => s == 'READY'),
    };
  }

  Map<String, dynamic> _summary(String gameId, String stage, String state) => {
    'id': runIdOf(gameId, stage),
    'status': switch (state) {
      'QUEUED' => 'QUEUED',
      'RUNNING' => 'RUNNING',
      'FAILED' => 'FAILED',
      _ => 'DONE',
    },
    'hasArtifact': state == 'READY' || state == 'STALE',
    'progressStage': state == 'RUNNING' ? 'scan' : null,
    'progressDone': null,
    'progressTotal': null,
    'persona': null,
    'language': null,
    'requestedAt': '2026-09-19T10:00:00.000Z',
    'startedAt': null,
    'finishedAt': state == 'READY' ? '2026-09-19T10:01:00.000Z' : null,
    'failureCode': state == 'FAILED' ? 'stage_input_missing' : null,
    'failureMessage': null,
  };

  /// The artifact of a run id, derived from its stage.
  Map<String, dynamic>? _run(String runId) {
    final stage = _stages.firstWhere(
      (s) => runId.contains(s.toLowerCase()),
      orElse: () => '',
    );
    if (stage.isEmpty) return null;
    return {
      'id': runId,
      'chessGameId': 'g1',
      'stage': stage,
      'status': 'DONE',
      'artifact': _artifact(stage),
      'supersededAt': null,
      'finishedAt': '2026-09-19T10:01:00.000Z',
      'failureCode': null,
      'failureMessage': null,
    };
  }

  Object? _artifact(String stage) => switch (stage) {
    _be => store.json('analysis/stages/base-evaluation.json'),
    _bc => store.json('analysis/stages/base-classification.json'),
    _de => store.json('analysis/stages/deep-evaluation.json'),
    _ => null,
  };
}

const Map<String, dynamic> _rateLimited = {
  '__typename': 'RateLimitedError',
  'message': 'web_api_errors.rate_limited',
  'retryAfterSeconds': 90,
};

const Map<String, dynamic> _prerequisiteMissing = {
  '__typename': 'BusinessError',
  'message': 'web_api_errors.stage_prerequisite_missing',
};

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late FixtureLink link;
  late StageServer server;
  late WorkflowTracker tracker;
  late List<WorkflowEvent> events;

  WorkflowTracker newTracker({Duration Function()? baseInterval}) {
    final executor = linkExecutor(link);
    final created = WorkflowTracker(
      api: StageApi(executor),
      analysisApi: AnalysisApi(executor),
      db: db,
      games: CachedGamesRepository(api: GamesApi(executor), db: db),
      baseInterval: baseInterval,
    );
    created.events.listen(events.add);
    return created;
  }

  setUp(() {
    clock = FakeClock();
    db = openTrackerDatabase(clock);
    link = FixtureLink();
    server = StageServer(link, link.store);
    events = [];
    tracker = newTracker();
  });

  tearDown(() async {
    tracker.dispose();
    await db.close();
  });

  /// Runs [body] under a fake clock; `async.elapse` moves time.
  void fake(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      body(async);
      async.flushMicrotasks();
    });
  }

  /// Signs in and starts a chain on `g1`, then settles.
  void start(
    FakeAsync async, {
    String gameId = 'g1',
    AnalysisStage target = AnalysisStage.deepEvaluation,
  }) {
    unawaited(tracker.setOwner(alice));
    async.flushMicrotasks();
    unawaited(tracker.startChain(gameId, target: target));
    async.flushMicrotasks();
  }

  /// One poll cycle.
  void tick(FakeAsync async) {
    final wait = tracker.currentInterval;
    async.elapse(wait ?? const Duration(seconds: 30));
    async.flushMicrotasks();
  }

  List<String> stagesStartedFor(String gameId) => [
    for (final entry in server.started)
      if (entry.gameId == gameId) entry.stage,
  ];

  group('the chain', () {
    test('starting it writes the row before anything is fired', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        async.flushMicrotasks();

        // The mutation only goes out with the poll that follows, but the row
        // that makes a kill resumable is there before it.
        unawaited(tracker.startChain('g1'));
        async.flushMicrotasks();

        final row = settle(async, db.pendingWorkflowsDao.get(alice, 'g1'))!;
        expect(row.targetStage, 'DEEP_EVALUATION');
        expect(row.state, WorkflowState.running);
        expect(stagesStartedFor('g1'), [_be]);
      });
    });

    test('an accepted stage is visible when startChain resolves', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        async.flushMicrotasks();

        // The tap is answered only once the workflow shows the stage queued,
        // so the button never comes back before the strip replaces it.
        unawaited(tracker.startChain('g1'));
        async.flushMicrotasks();

        expect(stagesStartedFor('g1'), [_be]);
        expect(
          tracker.workflows.value['g1']?.stateOf(AnalysisStage.baseEvaluation),
          AnalysisStageState.queued,
        );
        expect(server.workflowQueriesOf('g1'), 2);
      });
    });

    test('fires stage 2 once stage 1 is ready, and 3 once 2 is', () {
      fake((async) {
        start(async);
        expect(stagesStartedFor('g1'), [_be]);

        // Stage 1 is queued; nothing else is started while it runs.
        server.set('g1', _be, 'RUNNING');
        tick(async);
        expect(stagesStartedFor('g1'), [_be]);

        server.set('g1', _be, 'READY');
        tick(async);
        expect(stagesStartedFor('g1'), [_be, _bc]);

        server.set('g1', _bc, 'READY');
        tick(async);
        expect(stagesStartedFor('g1'), [_be, _bc, _de]);
      });
    });

    test(
      'it never starts the coaching stage, even when that is the target',
      () {
        fake((async) {
          start(async, target: AnalysisStage.coaching);
          server.setAll('g1', {_be: 'READY', _bc: 'READY', _de: 'READY'});
          tick(async);
          tick(async);

          expect(stagesStartedFor('g1'), isNot(contains(_co)));
          expect(link.requestsOf('RunCoaching'), isEmpty);
          // And it keeps watching, because the coach has not written yet.
          expect(tracker.trackedGames, contains('g1'));
        });
      },
    );

    test('it stops when the target is stored', () {
      fake((async) {
        start(async);
        server.setAll('g1', {_be: 'READY', _bc: 'READY', _de: 'READY'});
        tick(async);

        expect(tracker.trackedGames, isEmpty);
        expect(
          settle(async, db.pendingWorkflowsDao.get(alice, 'g1'))!.state,
          WorkflowState.done,
        );
        // Nothing left to poll.
        expect(tracker.currentInterval, isNull);
        final polls = server.workflowQueriesOf('g1');
        async.elapse(const Duration(minutes: 5));
        expect(server.workflowQueriesOf('g1'), polls);
      });
    });

    test('a failed stage stops it and says which one failed', () {
      fake((async) {
        start(async);
        server.setAll('g1', {_be: 'READY', _bc: 'FAILED'});
        tick(async);

        expect(events.whereType<StageFailedEvent>().map((e) => e.stage), [
          AnalysisStage.baseClassification,
        ]);
        expect(
          events.whereType<StageFailedEvent>().single.failureCode,
          'stage_input_missing',
        );
        expect(tracker.trackedGames, isEmpty);
        expect(
          settle(async, db.pendingWorkflowsDao.get(alice, 'g1'))!.state,
          WorkflowState.failed,
        );
        expect(stagesStartedFor('g1'), [_be]);
      });
    });

    test('a coaching stage that failed does not stop the engine chain', () {
      fake((async) {
        start(async);
        server.setAll('g1', {_be: 'READY', _co: 'FAILED'});
        tick(async);

        // Stage 4 is past the target, so the chain carries on to stage 2.
        expect(stagesStartedFor('g1'), [_be, _bc]);
        expect(tracker.trackedGames, contains('g1'));
      });
    });

    test('a refused command stops it', () {
      fake((async) {
        start(async);
        server.set('g1', _be, 'READY');
        server.refuse[_bc] = _prerequisiteMissing;
        tick(async);

        expect(
          events.whereType<StageFailedEvent>().single.failureCode,
          'stage_input_missing',
        );
        expect(tracker.trackedGames, isEmpty);
      });
    });

    test('two stages are never started at once for the same game', () {
      fake((async) {
        start(async);
        server.set('g1', _be, 'READY');
        // Two polls that overlap: the second is folded into the first.
        unawaited(tracker.refreshNow());
        unawaited(tracker.refreshNow());
        async.flushMicrotasks();

        expect(stagesStartedFor('g1').where((s) => s == _bc), hasLength(1));
      });
    });
  });

  group('rate limiting', () {
    test('it waits what the server asked for, then carries on', () {
      fake((async) {
        start(async);
        server.set('g1', _be, 'READY');
        server.refuse[_bc] = _rateLimited;
        tick(async);

        // Refused, but not failed: the game is still watched.
        expect(tracker.trackedGames, contains('g1'));
        expect(events.whereType<StageFailedEvent>(), isEmpty);
        // The wait beats the 3 s cadence: the server said 90 s and the
        // engine commands now select `retryAfterSeconds`, so that is what
        // the tracker waits.
        expect(tracker.currentInterval, const Duration(seconds: 90));

        final polls = server.workflowQueriesOf('g1');
        async.elapse(const Duration(seconds: 89));
        expect(server.workflowQueriesOf('g1'), polls);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        // Stage 2 again — the refused attempt is the second entry, the one
        // that went through the third.
        expect(stagesStartedFor('g1'), [_be, _bc, _bc]);
        expect(server.stateOf('g1', _bc), 'QUEUED');
      });
    });

    test('the wait is honoured once, then the cadence is back', () {
      fake((async) {
        start(async);
        server.set('g1', _be, 'READY');
        server.refuse[_bc] = _rateLimited;
        tick(async);
        expect(tracker.currentInterval, const Duration(seconds: 90));

        tick(async);
        expect(tracker.currentInterval, lessThan(const Duration(seconds: 90)));
      });
    });
  });

  group('the cadence', () {
    test('3 s, then x1.5 each time, capped at 30 s', () {
      fake((async) {
        start(async);
        server.set('g1', _be, 'RUNNING');
        final waits = <Duration>[];
        for (var i = 0; i < 9; i++) {
          final wait = tracker.currentInterval!;
          waits.add(wait);
          final before = server.workflowQueriesOf('g1');
          async.elapse(wait - const Duration(milliseconds: 1));
          expect(server.workflowQueriesOf('g1'), before, reason: 'early ($i)');
          async.elapse(const Duration(milliseconds: 1));
          async.flushMicrotasks();
          expect(
            server.workflowQueriesOf('g1'),
            before + 1,
            reason: 'due ($i)',
          );
        }
        expect(waits.take(7), const [
          Duration(milliseconds: 3000),
          Duration(milliseconds: 4500),
          Duration(milliseconds: 6750),
          Duration(milliseconds: 10125),
          Duration(microseconds: 15187500),
          Duration(microseconds: 22781250),
          Duration(seconds: 30),
        ]);
        expect(waits.skip(7), everyElement(const Duration(seconds: 30)));
      });
    });

    test('the base interval comes from the configuration', () {
      tracker.dispose();
      tracker = newTracker(baseInterval: () => const Duration(seconds: 5));
      fake((async) {
        start(async);
        server.set('g1', _be, 'RUNNING');
        expect(tracker.currentInterval, const Duration(seconds: 5));
      });
    });

    test('refreshNow polls at once and starts the interval again', () {
      fake((async) {
        start(async);
        server.set('g1', _be, 'RUNNING');
        tick(async);
        tick(async);
        expect(tracker.currentInterval, const Duration(milliseconds: 6750));
        final polls = server.workflowQueriesOf('g1');

        unawaited(tracker.refreshNow());
        async.flushMicrotasks();
        expect(server.workflowQueriesOf('g1'), polls + 1);
        expect(tracker.currentInterval, const Duration(seconds: 3));
      });
    });
  });

  group('idle gating', () {
    test('nobody signed in: nothing is asked', () {
      fake((async) {
        unawaited(tracker.startChain('g1'));
        async
          ..flushMicrotasks()
          ..elapse(const Duration(minutes: 5));

        expect(link.requests, isEmpty);
        expect(tracker.currentInterval, isNull);
      });
    });

    test('nothing to watch: one reconciling poll and then silence', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        async.flushMicrotasks();

        // No game in flight, so there is nothing to ask about at all.
        expect(link.requestsOf('GameAnalysisWorkflow'), isEmpty);
        expect(tracker.currentInterval, isNull);
        async.elapse(const Duration(minutes: 5));
        expect(link.requestsOf('GameAnalysisWorkflow'), isEmpty);
      });
    });

    test('the background stops it; coming back polls at once', () {
      fake((async) {
        start(async);
        server.set('g1', _be, 'RUNNING');
        final polls = server.workflowQueriesOf('g1');

        tracker.setForeground(false);
        expect(tracker.currentInterval, isNull);
        async.elapse(const Duration(minutes: 10));
        expect(server.workflowQueriesOf('g1'), polls);

        // A push while in the background: nothing happens.
        unawaited(tracker.refreshNow());
        async.flushMicrotasks();
        expect(server.workflowQueriesOf('g1'), polls);

        tracker.setForeground(true);
        async.flushMicrotasks();
        expect(server.workflowQueriesOf('g1'), polls + 1);
        expect(tracker.currentInterval, const Duration(seconds: 3));
      });
    });

    test('signing out stops it and forgets the games', () {
      fake((async) {
        start(async);
        server.set('g1', _be, 'RUNNING');

        unawaited(tracker.setOwner(null));
        async.flushMicrotasks();
        expect(tracker.trackedGames, isEmpty);
        expect(tracker.workflows.value, isEmpty);

        final polls = server.workflowQueriesOf('g1');
        async.elapse(const Duration(minutes: 5));
        expect(server.workflowQueriesOf('g1'), polls);
      });
    });
  });

  group('resuming', () {
    test('a row from an earlier session is picked up on sign-in', () {
      fake((async) {
        settle(
          async,
          db.pendingWorkflowsDao.upsert(
            alice,
            gameId: 'g1',
            targetStage: 'DEEP_EVALUATION',
          ),
        );

        // A fresh tracker, as after an app kill.
        tracker.dispose();
        tracker = newTracker();
        unawaited(tracker.setOwner(alice));
        async.flushMicrotasks();

        expect(tracker.trackedGames, contains('g1'));
        // Stage 1 was already stored before the kill, so the chain goes on
        // from stage 2 rather than starting over.
        expect(stagesStartedFor('g1'), [_be]);
      });
    });

    test('a row written by somebody else is adopted while it runs', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        async.flushMicrotasks();

        // The submit queue after "Save & analyse".
        settle(
          async,
          db.pendingWorkflowsDao.upsert(
            alice,
            gameId: 'g2',
            targetStage: 'DEEP_EVALUATION',
          ),
        );
        async.flushMicrotasks();

        expect(tracker.trackedGames, contains('g2'));
        expect(server.workflowQueriesOf('g2'), greaterThan(0));
      });
    });

    test('a target this build does not know is watched to the free stages', () {
      fake((async) {
        settle(
          async,
          db.pendingWorkflowsDao.upsert(
            alice,
            gameId: 'g1',
            targetStage: 'SHINY_NEW_STAGE',
          ),
        );
        unawaited(tracker.setOwner(alice));
        async.flushMicrotasks();

        expect(stagesStartedFor('g1'), [_be]);
      });
    });

    test('a finished row is dropped on sign-in', () {
      fake((async) {
        settle(
          async,
          db.pendingWorkflowsDao.upsert(
            alice,
            gameId: 'g1',
            targetStage: 'DEEP_EVALUATION',
            state: WorkflowState.done,
          ),
        );
        unawaited(tracker.setOwner(alice));
        async.flushMicrotasks();

        expect(tracker.trackedGames, isEmpty);
        expect(settle(async, db.pendingWorkflowsDao.get(alice, 'g1')), isNull);
      });
    });
  });

  group('the game is gone', () {
    test('a workflow that comes back null untracks and deletes the row', () {
      fake((async) {
        start(async);
        server.missing.add('g1');
        tick(async);

        expect(tracker.trackedGames, isEmpty);
        expect(settle(async, db.pendingWorkflowsDao.get(alice, 'g1')), isNull);
        expect(tracker.workflows.value, isEmpty);
      });
    });

    test('offline keeps the game: it is asked about again', () {
      fake((async) {
        start(async);
        link.fail('GameAnalysisWorkflow', const SocketException('offline'));
        tick(async);

        expect(tracker.trackedGames, contains('g1'));
        expect(
          settle(async, db.pendingWorkflowsDao.get(alice, 'g1')),
          isNotNull,
        );
      });
    });
  });

  group('artifacts', () {
    /// The cached analysis of `g1`, or null.
    CachedAnalysis? cached(FakeAsync async) =>
        settle(async, db.analysisCacheDao.get(alice, 'g1'));

    test('stage 1 ready: fetched, assembled and stored as an engine row', () {
      fake((async) {
        start(async);
        server.set('g1', _be, 'READY');
        tick(async);

        final row = cached(async)!;
        expect(row.source, AnalysisSource.engine);
        expect(row.stage, _be);
        expect(jsonDecode(row.stageRunIds!), {_be: server.runIdOf('g1', _be)});
        final document = jsonDecode(row.payload)! as Map<String, dynamic>;
        expect((document['nodes']! as List), hasLength(80));
        // Stage 1 knows of no key positions.
        expect(
          (document['nodes']! as List).every(
            (n) => (n as Map)['is_critical'] == false,
          ),
          isTrue,
        );
      });
    });

    test('the stage is published only once its document is stored', () {
      fake((async) {
        start(async);
        // What a screen sees when it learns a stage is READY: it goes looking
        // for what that stage produced, so the cache has to hold it by then.
        // Publishing first left the review on "nothing available" until the
        // *next* stage landed.
        AnalysisSource? sourceWhenSeen;
        tracker.workflows.addListener(() {
          if (tracker.workflows.value['g1']?.newestReadyEngineStage != null &&
              sourceWhenSeen == null) {
            sourceWhenSeen = settle(
              async,
              db.analysisCacheDao.get(alice, 'g1'),
            )?.source;
          }
        });

        server.set('g1', _be, 'READY');
        tick(async);

        expect(sourceWhenSeen, AnalysisSource.engine);
      });
    });

    test('one fetch per run id: a second poll fetches nothing', () {
      fake((async) {
        start(async);
        server.set('g1', _be, 'READY');
        tick(async);
        expect(server.artifactFetches, [server.runIdOf('g1', _be)]);

        tick(async);
        tick(async);
        expect(server.artifactFetches, [server.runIdOf('g1', _be)]);
      });
    });

    test(
      'a stage that was run again has a new run id and is fetched again',
      () {
        fake((async) {
          start(async);
          server.set('g1', _be, 'READY');
          tick(async);
          final first = server.runIdOf('g1', _be);

          server.rerun('g1', _be);
          tick(async);

          expect(server.artifactFetches, [first, server.runIdOf('g1', _be)]);
          expect(first, isNot(server.runIdOf('g1', _be)));
        });
      },
    );

    test(
      'stage 2 lands after stage 1: the plies are patched in, not rebuilt',
      () {
        fake((async) {
          start(async);
          server.set('g1', _be, 'READY');
          tick(async);
          final fetches = server.artifactFetches.length;

          server.set('g1', _bc, 'READY');
          tick(async);

          // One more fetch, of stage 2 only.
          expect(server.artifactFetches, hasLength(fetches + 1));
          expect(server.artifactFetches.last, server.runIdOf('g1', _bc));

          final row = cached(async)!;
          final nodes = (jsonDecode(row.payload)! as Map)['nodes']! as List;
          final critical = [
            for (final node in nodes)
              if ((node as Map)['is_critical'] == true) node['ply'] as int,
          ];
          expect(critical, [6, 10, 14, 18, 22, 26, 30, 34, 36, 38]);
          expect(
            jsonDecode(row.stageRunIds!),
            containsPair(_bc, server.runIdOf('g1', _bc)),
          );
        });
      },
    );

    test('stage 3 ready: only stage 3 is fetched, 1 and 2 are marked read', () {
      fake((async) {
        start(async);
        // All three land between two polls, which is what a fast game looks
        // like — and what the tracker must not answer with three fetches.
        server.setAll('g1', {_be: 'READY', _bc: 'READY', _de: 'READY'});
        tick(async);

        expect(server.artifactFetches, [server.runIdOf('g1', _de)]);
        final row = cached(async)!;
        expect(row.stage, _de);
        expect(jsonDecode(row.stageRunIds!), {
          _be: server.runIdOf('g1', _be),
          _bc: server.runIdOf('g1', _bc),
          _de: server.runIdOf('g1', _de),
        });
        final document = jsonDecode(row.payload)! as Map<String, dynamic>;
        // The deep nodes: variations, accuracy, the settled key positions.
        expect(document['accuracy'], {'white': 91.6, 'black': 89.5});
        final nodes = (document['nodes']! as List).cast<Map<String, dynamic>>();
        expect(
          nodes.where((n) => (n['variations']! as List).isNotEmpty),
          isNotEmpty,
        );
        expect(
          [
            for (final n in nodes)
              if (n['is_critical'] == true) n['ply'],
          ],
          [6, 10, 18, 22, 30, 34, 36, 38],
        );
      });
    });

    test('an artifact that cannot be fetched is asked for again', () {
      fake((async) {
        start(async);
        server.set('g1', _be, 'READY');
        link.fail('EngineStageRun', const SocketException('offline'));
        tick(async);
        expect(cached(async), isNull);

        link.respond('EngineStageRun', (variables) {
          return {
            'data': {'engineStageRun': server._run(variables['id']! as String)},
          };
        });
        tick(async);
        expect(cached(async), isNotNull);
      });
    });
  });

  group('the library summary', () {
    /// A cached game row, so that there is something to write the pipeline on.
    void cacheGame(FakeAsync async, {bool hasAnalysis = false}) {
      settle(
        async,
        db.gamesCacheDao.upsertPage(alice, [
          CachedGameInput(
            gameId: 'g1',
            summaryJson: jsonEncode({
              'v': 2,
              'id': 'g1',
              'playerColor': 'white',
              'result': '1-0',
              'hasAnalysis': hasAnalysis,
            }),
            updatedAt: clock(),
          ),
        ]),
      );
    }

    GameWorkflowSummary? summaryOf(FakeAsync async) {
      final row = settle(async, db.gamesCacheDao.get(alice, 'g1'))!;
      return GameSummaryCodec.decode(row.summaryJson)!.workflow;
    }

    test('the states of every poll are written next to the game', () {
      fake((async) {
        cacheGame(async);
        start(async);
        tick(async);

        final first = summaryOf(async)!;
        expect(
          first.stateOf(AnalysisStage.baseEvaluation),
          AnalysisStageState.queued,
        );
        expect(first.isComplete, isFalse);

        server.set('g1', _be, 'READY');
        tick(async);
        expect(
          summaryOf(async)!.stateOf(AnalysisStage.baseEvaluation),
          AnalysisStageState.ready,
        );
      });
    });

    test('a poll that changed nothing does not rewrite the row', () {
      fake((async) {
        cacheGame(async);
        start(async);
        tick(async);
        final before = settle(async, db.gamesCacheDao.get(alice, 'g1'))!;

        // Stage 1 lands, the classification starts, and then nothing moves.
        server.set('g1', _be, 'READY');
        tick(async);
        tick(async);
        final written = settle(async, db.gamesCacheDao.get(alice, 'g1'))!;
        tick(async);
        final after = settle(async, db.gamesCacheDao.get(alice, 'g1'))!;

        expect(written.summaryJson, isNot(before.summaryJson));
        expect(after.summaryJson, written.summaryJson);
      });
    });

    test('a game nothing has cached is no obstacle', () {
      fake((async) {
        // No `cached_games` row at all: the pipeline still runs.
        start(async);
        server.set('g1', _be, 'READY');
        tick(async);
        expect(tracker.trackedGames, contains('g1'));
        expect(settle(async, db.gamesCacheDao.get(alice, 'g1')), isNull);
      });
    });
  });

  group('the coach', () {
    test(
      'a ready coaching stage fetches the document and stores it as coach',
      () {
        fake((async) {
          settle(
            async,
            db.gamesCacheDao.upsertPage(alice, [
              CachedGameInput(
                gameId: 'g1',
                summaryJson: jsonEncode({'id': 'g1', 'hasAnalysis': false}),
                updatedAt: clock(),
              ),
            ]),
          );
          link.use('GameAnalysis', 'short_game');
          start(async, target: AnalysisStage.coaching);
          server.setAll('g1', {
            _be: 'READY',
            _bc: 'READY',
            _de: 'READY',
            _co: 'READY',
          });
          tick(async);

          final row = settle(async, db.analysisCacheDao.get(alice, 'g1'))!;
          expect(row.source, AnalysisSource.coach);
          expect(server.analysisFetches, 1);
          expect(
            events.whereType<StageReadyEvent>().map((e) => e.stage),
            contains(AnalysisStage.coaching),
          );
          // The pipeline is finished, so the tracker lets go.
          expect(tracker.trackedGames, isEmpty);
          // And the library badge is flipped.
          final game = settle(async, db.gamesCacheDao.get(alice, 'g1'))!;
          expect(game.summaryJson, contains('"hasAnalysis":true'));
        });
      },
    );

    test('it is fetched once, not on every poll', () {
      fake((async) {
        link.use('GameAnalysis', 'short_game');
        start(async, target: AnalysisStage.coaching);
        server.setAll('g1', {
          _be: 'READY',
          _bc: 'READY',
          _de: 'READY',
          _co: 'RUNNING',
        });
        tick(async);
        server.set('g1', _co, 'READY');
        tick(async);

        expect(server.analysisFetches, 1);
      });
    });

    test('a coaching stage that went stale drops the coach row', () {
      fake((async) {
        link.use('GameAnalysis', 'short_game');
        start(async, target: AnalysisStage.coaching);
        server.setAll('g1', {
          _be: 'READY',
          _bc: 'READY',
          _de: 'READY',
          _co: 'READY',
        });
        tick(async);
        expect(
          settle(async, db.analysisCacheDao.get(alice, 'g1'))!.source,
          AnalysisSource.coach,
        );

        // The user changed the moves: the text is about another game now. The
        // tracker let go when the coach document landed, so this is the app
        // looking again (a cold open of the game, or a new chain).
        server.set('g1', _co, 'STALE');
        unawaited(tracker.startChain('g1', target: AnalysisStage.coaching));
        async.flushMicrotasks();

        expect(settle(async, db.analysisCacheDao.get(alice, 'g1')), isNull);
      });
    });

    test('an engine assembly never replaces the coach document', () {
      fake((async) {
        link.use('GameAnalysis', 'short_game');
        start(async, target: AnalysisStage.coaching);
        server.setAll('g1', {
          _be: 'READY',
          _bc: 'READY',
          _de: 'READY',
          _co: 'READY',
        });
        tick(async);

        // A stage that is run again while the coach document is stored.
        server.rerun('g1', _de);
        unawaited(tracker.startChain('g1', target: AnalysisStage.coaching));
        async.flushMicrotasks();

        expect(
          settle(async, db.analysisCacheDao.get(alice, 'g1'))!.source,
          AnalysisSource.coach,
        );
        // Not even fetched: a ready coaching stage already says more than any
        // engine artifact could, so nothing is pulled over the wire for it.
        expect(server.artifactFetches, isEmpty);
      });
    });
  });

  group('events', () {
    test('the first poll of a game announces nothing', () {
      fake((async) {
        // A game whose analysis has been finished for weeks would otherwise
        // announce itself the moment it is watched.
        server.setAll('g1', {_be: 'READY', _bc: 'READY', _de: 'READY'});
        start(async);

        expect(events.whereType<StageReadyEvent>(), isEmpty);
      });
    });

    test('one ready event per stage, as each one lands', () {
      fake((async) {
        start(async);
        server.set('g1', _be, 'READY');
        tick(async);
        server.set('g1', _bc, 'READY');
        tick(async);
        server.set('g1', _de, 'READY');
        tick(async);

        expect(events.whereType<StageReadyEvent>().map((e) => e.stage), [
          AnalysisStage.baseEvaluation,
          AnalysisStage.baseClassification,
          AnalysisStage.deepEvaluation,
        ]);
      });
    });

    test('moves that changed are announced once, and the chain stops', () {
      fake((async) {
        start(async);
        server.set('g1', _be, 'READY');
        tick(async);
        final started = stagesStartedFor('g1').length;

        server.set('g1', _be, 'STALE');
        tick(async);

        expect(events.whereType<WorkflowStaleEvent>(), hasLength(1));
        expect(tracker.trackedGames, isEmpty);
        // Nothing is re-run behind the user's back.
        expect(stagesStartedFor('g1'), hasLength(started));
      });
    });

    test('the workflow of a watched game is published', () {
      fake((async) {
        start(async);
        server.set('g1', _be, 'RUNNING');
        tick(async);

        final workflow = tracker.workflows.value['g1']!;
        expect(workflow.activeStage, AnalysisStage.baseEvaluation);
        expect(
          workflow.stageOf(AnalysisStage.baseEvaluation)!.run!.progressStage,
          'scan',
        );
      });
    });
  });

  group('several games', () {
    test(
      'one workflow query per game per tick, and each chain runs on its own',
      () {
        fake((async) {
          unawaited(tracker.setOwner(alice));
          async.flushMicrotasks();
          unawaited(tracker.startChain('g1'));
          unawaited(tracker.startChain('g2'));
          async.flushMicrotasks();

          final g1 = server.workflowQueriesOf('g1');
          final g2 = server.workflowQueriesOf('g2');
          server.set('g1', _be, 'READY');
          server.set('g2', _be, 'RUNNING');
          tick(async);

          // g1 started stage 2 in this tick, which earns it one follow-up
          // query; g2 only waited.
          expect(server.workflowQueriesOf('g1'), g1 + 2);
          expect(server.workflowQueriesOf('g2'), g2 + 1);
          expect(stagesStartedFor('g1'), [_be, _bc]);
          expect(stagesStartedFor('g2'), [_be]);
        });
      },
    );

    test('one game finishing leaves the other watched', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        async.flushMicrotasks();
        unawaited(tracker.startChain('g1'));
        unawaited(tracker.startChain('g2'));
        async.flushMicrotasks();

        server.setAll('g1', {_be: 'READY', _bc: 'READY', _de: 'READY'});
        server.set('g2', _be, 'RUNNING');
        tick(async);

        expect(tracker.trackedGames, {'g2'});
        expect(tracker.currentInterval, isNotNull);
      });
    });
  });
}
