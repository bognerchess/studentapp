// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';
import 'dart:io';

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/api/analysis_api.dart' as api;
import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/api/stage_api.dart'
    show
        AnalysisStage,
        AnalysisStageState,
        AnalysisWorkflow,
        JobStatus,
        StageApi,
        StageRunSummary,
        WorkflowStage;
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/features/library/data/cached_games_repository.dart';
import 'package:bogner_chess/features/review/data/api_review_repository.dart';
import 'package:bogner_chess/features/review/data/local_feedback_store.dart';
import 'package:bogner_chess/features/review/domain/review_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/api/api_test_support.dart';
import '../../core/storage/test_database.dart';
import '../../helpers/fixture_link.dart';

/// Rated up, down and with an unknown value in `GameAnalysis/default.json`.
const _up = '322b7d97-32b5-4bc3-9f81-475368d0ef1c';
const _down = '0e60df92-f823-4d99-a5e3-82cbad3c3ba1';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late FixtureLink link;
  late CachedGamesRepository games;
  late ApiReviewRepository repository;
  String? owner;

  /// What the tracker would be holding: null means "not watching this game",
  /// which is the cold open the repository answers with one query.
  final Map<String, AnalysisWorkflow> tracked = {};

  /// What the tracker's catch-up does when asked, and how often it was.
  late Future<void> Function(String gameId) sync;
  final List<String> synced = [];

  setUp(() {
    synced.clear();
    sync = (gameId) async => synced.add(gameId);
    clock = FakeClock();
    db = openTestDatabase(clock);
    link = FixtureLink();
    final executor = linkExecutor(link);
    games = CachedGamesRepository(api: GamesApi(executor), db: db);
    owner = alice;
    tracked.clear();
    repository = ApiReviewRepository(
      analysisApi: api.AnalysisApi(executor),
      stageApi: StageApi(executor),
      games: games,
      db: db,
      owner: () => owner,
      trackedWorkflow: (gameId) => tracked[gameId],
      syncArtifacts: (gameId) => sync(gameId),
    );
  });
  tearDown(() => db.close());

  int fetches() => link.requestsOf('GameAnalysis').length;
  int workflowQueries() => link.requestsOf('GameAnalysisWorkflow').length;

  /// The engine assembly the tracker would have written, so that the coach
  /// document has something to win against.
  Future<void> cacheEngineAssembly() async {
    await db.analysisCacheDao.putEngine(
      alice,
      'game-1',
      schemaVersion: 1,
      schemaMinor: 0,
      payload: jsonEncode(link.store.json('analysis/v1/short-game.json')),
      stage: 'DEEP_EVALUATION',
      stageRunIds: jsonEncode({'DEEP_EVALUATION': 'run-de'}),
    );
  }

  test('cache miss: fetched, stored with its schema version, header from the '
      'library, feedback from the server', () async {
    await games.fetchPage(alice, fetchedAt: games.now());

    final data = await repository.load('game-1');
    expect(data.result, isA<AnalysisSupported>());
    expect(fetches(), 1);
    expect(link.requestsOf('GameAnalysis').single.variables, {
      'gameId': 'game-1',
      'maxSchemaVersion': kMaxSupportedAnalysisSchema,
    });
    expect(data.header.white, 'Fake User');
    expect(data.header.black, 'Jonas Keller');
    expect(data.header.result, '1-0');
    expect(data.header.date, DateTime(2026, 9, 12));
    expect(data.myFeedback[_up], CommentRating.up);
    expect(data.myFeedback[_down], CommentRating.down);
    expect(data.myFeedback, hasLength(2), reason: 'the unknown rating is none');

    final cached = (await db.analysisCacheDao.get(alice, 'game-1'))!;
    expect(cached.schemaVersion, 1);
    expect(cached.schemaMinor, 0);
    expect(
      AnalysisParser.parseString(cached.payload),
      isA<AnalysisSupported>(),
    );
  });

  test('cache hit: no request, works offline, thumbs remembered', () async {
    await games.fetchPage(alice, fetchedAt: games.now());
    await repository.load('game-1');
    link
      ..fail('GameAnalysis', const SocketException('offline'))
      ..fail('GameById', const SocketException('offline'));

    final data = await repository.load('game-1');
    expect(fetches(), 1);
    expect(data.result, isA<AnalysisSupported>());
    expect(data.myFeedback[_up], CommentRating.up);
    expect(data.header.black, 'Jonas Keller');
  });

  group('the engine assembly and the coach document', () {
    test('a cached engine assembly is shown, and says so', () async {
      await cacheEngineAssembly();
      link.use('GameAnalysisWorkflow', 'engine_ready');

      final data = await repository.load('game-1');
      expect(data.result, isA<AnalysisSupported>());
      expect(data.source, AnalysisSource.engine);
      expect(fetches(), 0, reason: 'the coach has not written');
    });

    test('a ready coaching stage beats the engine assembly', () async {
      await cacheEngineAssembly();
      link.use('GameAnalysisWorkflow', 'all_ready');

      final data = await repository.load('game-1');
      expect(data.source, AnalysisSource.coach);
      expect(fetches(), 1);
      // And the run it was fetched for is recorded, so the next open is free.
      final row = (await db.analysisCacheDao.get(alice, 'game-1'))!;
      expect(row.source, AnalysisSource.coach);
      expect(jsonDecode(row.stageRunIds!), {'COACHING': 'run-co'});

      await repository.load('game-1');
      expect(fetches(), 1);
    });

    test('a newer coaching run makes the coach document stale', () async {
      await cacheEngineAssembly();
      link.use('GameAnalysisWorkflow', 'all_ready');
      await repository.load('game-1');
      expect(fetches(), 1);

      // The user asked the coach again; a new run is ready.
      link.respond('GameAnalysisWorkflow', (_) {
        final body = link.store.response('GameAnalysisWorkflow', 'all_ready');
        final workflow =
            (body['data'] as Map)['gameAnalysisWorkflow']
                as Map<String, Object?>;
        final stages = workflow['stages'] as List;
        ((stages.last as Map)['run'] as Map)['id'] = 'run-co-2';
        return body;
      });
      await repository.load('game-1');
      expect(fetches(), 2);
      final row = (await db.analysisCacheDao.get(alice, 'game-1'))!;
      expect(jsonDecode(row.stageRunIds!), {'COACHING': 'run-co-2'});
    });

    test('a coach row without a recorded run is left alone', () async {
      // What the whole-game path writes, and what a build before this one
      // wrote: no run id to compare, and already the best kind of document.
      await db.analysisCacheDao.putCoach(
        alice,
        'game-1',
        schemaVersion: 1,
        schemaMinor: 0,
        payload: jsonEncode(link.store.json('analysis/v1/short-game.json')),
      );
      link.use('GameAnalysisWorkflow', 'all_ready');

      expect((await repository.load('game-1')).source, AnalysisSource.coach);
      expect(fetches(), 0);
    });

    test('the tracker knows the workflow: no query of our own', () async {
      await cacheEngineAssembly();
      tracked['game-1'] = _engineReady;

      final data = await repository.load('game-1');
      expect(data.source, AnalysisSource.engine);
      expect(workflowQueries(), 0);
      expect(fetches(), 0);
    });

    test('nothing cached: the document is fetched without asking the '
        'pipeline first', () async {
      await repository.load('game-1');
      expect(fetches(), 1);
      expect(
        workflowQueries(),
        0,
        reason: 'the answer could not have changed what happens',
      );
    });

    test('stale but offline: the cached copy is shown', () async {
      await cacheEngineAssembly();
      link
        ..use('GameAnalysisWorkflow', 'all_ready')
        ..fail('GameAnalysis', const SocketException('offline'));

      final data = await repository.load('game-1');
      expect(data.result, isA<AnalysisSupported>());
      expect(data.source, AnalysisSource.engine);
    });

    test('the pipeline cannot be reached: the cached copy is shown', () async {
      await cacheEngineAssembly();
      link.fail('GameAnalysisWorkflow', const SocketException('offline'));

      expect((await repository.load('game-1')).source, AnalysisSource.engine);
      expect(fetches(), 0);
    });

    test('a game that is gone: no workflow, the cached copy stands', () async {
      await cacheEngineAssembly();
      link.use('GameAnalysisWorkflow', 'not_found');

      expect((await repository.load('game-1')).source, AnalysisSource.engine);
    });
  });

  test('nothing cached and offline: the error is thrown', () async {
    link.fail('GameAnalysis', const SocketException('offline'));
    await expectLater(
      repository.load('game-1'),
      throwsA(isA<api.ApiNetworkError>()),
    );
  });

  test('the server has no analysis: AnalysisNotAvailable', () async {
    link.use('GameAnalysis', 'none');
    await expectLater(
      repository.load('game-1'),
      throwsA(isA<AnalysisNotAvailable>()),
    );
    // The tracker was asked to catch up once before giving up.
    expect(synced, ['game-1']);
  });

  test('nothing stored and no coach document: the engine stages the tracker '
      'catches up on are served', () async {
    link.use('GameAnalysis', 'none');
    sync = (gameId) async {
      synced.add(gameId);
      await cacheEngineAssembly();
    };

    final data = await repository.load('game-1');
    expect(data.result, isA<AnalysisSupported>());
    expect(data.source, AnalysisSource.engine);
    expect(synced, ['game-1']);
  });

  test('a newer major version is handed over and cached as such', () async {
    link.use('GameAnalysis', 'newer_major');
    final data = await repository.load('game-1');
    expect(data.result, isA<AnalysisNewerMajor>());
    expect(data.myFeedback, isEmpty);
    expect((await db.analysisCacheDao.get(alice, 'game-1'))!.schemaVersion, 2);

    // From the cache it is the same.
    expect((await repository.load('game-1')).result, isA<AnalysisNewerMajor>());
    expect(fetches(), 1);
  });

  test('an invalid document is handed over, and asked for again', () async {
    link.use('GameAnalysis', 'invalid_document');
    expect((await repository.load('game-1')).result, isA<AnalysisInvalid>());

    link.use('GameAnalysis', 'default');
    expect((await repository.load('game-1')).result, isA<AnalysisSupported>());
    expect(fetches(), 2);
  });

  test('a game the library never listed: header from GameById', () async {
    final data = await repository.load('game-1');
    expect(link.requestsOf('GameById'), hasLength(1));
    expect(data.header.white, 'Fake User');

    // And without a connection the header is simply empty.
    await db.gamesCacheDao.remove(alice, 'game-1');
    await db.analysisCacheDao.putCoach(
      alice,
      'game-1',
      schemaVersion: 1,
      schemaMinor: 0,
      payload: jsonEncode(link.store.json('analysis/v1/short-game.json')),
    );
    link.fail('GameById', const SocketException('offline'));
    final offline = await repository.load('game-1');
    expect(offline.header.white, isNull);
    expect(offline.result, isA<AnalysisSupported>());
  });

  test('a thumb waiting in the outbox beats the server', () async {
    await db.feedbackOutboxDao.put(alice, _up, FeedbackRating.down);
    await LocalFeedbackStore(db).write(alice, _up, CommentRating.down);

    final data = await repository.load('game-1');
    expect(data.myFeedback[_up], CommentRating.down);
    expect(data.myFeedback[_down], CommentRating.down);
  });

  test(
    'signed out: unauthenticated; another account has its own cache',
    () async {
      await repository.load('game-1');
      owner = null;
      await expectLater(
        repository.load('game-1'),
        throwsA(isA<api.ApiUnauthenticated>()),
      );
      owner = bob;
      await repository.load('game-1');
      expect(fetches(), 2);
    },
  );
}

/// What the tracker holds for a game whose three engine stages are stored and
/// whose coach has not been asked.
final AnalysisWorkflow _engineReady = AnalysisWorkflow(
  gameId: 'game-1',
  isComplete: false,
  nextRunnableStage: AnalysisStage.coaching,
  stages: [
    for (final (stage, state) in const [
      (AnalysisStage.baseEvaluation, AnalysisStageState.ready),
      (AnalysisStage.baseClassification, AnalysisStageState.ready),
      (AnalysisStage.deepEvaluation, AnalysisStageState.ready),
      (AnalysisStage.coaching, AnalysisStageState.notRun),
    ])
      WorkflowStage(
        stage: stage,
        state: state,
        runnable: stage == AnalysisStage.coaching,
        usesModel: stage.usesModel,
        run: state == AnalysisStageState.ready
            ? StageRunSummary(
                id: 'run-${stage.name}',
                status: JobStatus.done,
                hasArtifact: true,
                requestedAt: DateTime.utc(2026, 9, 19, 10),
              )
            : null,
      ),
  ],
);
