// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/account_api.dart';
import 'package:bogner_chess/core/api/analysis_api.dart';
import 'package:bogner_chess/core/api/api_client.dart';
import 'package:bogner_chess/core/api/config_api.dart';
import 'package:bogner_chess/core/api/devices_api.dart';
import 'package:bogner_chess/core/api/events_api.dart';
import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/api/generated/operations/config.graphql.dart';
import 'package:bogner_chess/core/api/legal_api.dart';
import 'package:bogner_chess/core/api/stage_api.dart';
import 'package:bogner_chess/core/api/usage_api.dart';
import 'package:bogner_chess/core/auth/fake_auth_repository.dart';
import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/mock_server/mock_server.dart';
import 'api_test_support.dart';

/// The repositories over the real link chain and real HTTP, against the mock
/// server in this process: what the app does with `config/fake.json`.
void main() {
  late MockServer server;
  late FakeAuthRepository auth;
  late ApiExecutor executor;

  Future<void> start([MockOptions? options]) async {
    server = await MockServer.start(
      backend: MockBackend(options: options ?? MockOptions()),
    );
    auth = FakeAuthRepository();
    executor = chainExecutor(auth: auth, apiUrl: server.graphqlUri);
  }

  setUp(start);

  tearDown(() async {
    await server.close();
    await auth.dispose();
  });

  final metadata = GameMetadata.forPlayer(
    playerColor: PlayerColor.white,
    playerName: 'Fake User',
    opponentName: 'Ada Lovelace',
    result: GameResult.whiteWins,
    playedDate: GameDate(2026, 9, 18),
    eventName: 'Club night',
    timeControl: const TimeControl(TimeControlKind.rapid, detail: '15+10'),
  );

  Future<GameSummary> importGame(String clientGameId) async {
    final outcome = await GamesApi(executor).import(
      metadata: metadata,
      movetext: '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6',
      clientGameId: clientGameId,
      source: ImportSource.board,
    );
    return (outcome as GameImported).game;
  }

  /// The pipeline of [gameId], polled until [stage] is no longer active.
  Future<AnalysisWorkflow> until(String gameId, AnalysisStage stage) async {
    final stages = StageApi(executor);
    for (var i = 0; i < 10; i++) {
      final workflow = (await stages.workflow(gameId))!;
      if (!workflow.stateOf(stage).isActive) {
        return workflow;
      }
    }
    fail('${stage.name} never finished');
  }

  /// The pipeline of [gameId], polled until nothing is running any more.
  Future<AnalysisWorkflow> untilDone(String gameId) async {
    final stages = StageApi(executor);
    for (var i = 0; i < 40; i++) {
      final workflow = (await stages.workflow(gameId))!;
      if (!workflow.workflowState.isActive) {
        return workflow;
      }
    }
    fail('the analysis of $gameId never stopped running');
  }

  /// One `analyseGame`, then polled to the end of whatever the server chained.
  Future<AnalysisWorkflow> analyse(String gameId, {String language = 'en'}) =>
      StageApi(executor)
          .analyseGame(gameId, language: language)
          .then((_) => untilDone(gameId));

  /// The three free stages of [gameId], each run to READY with the one-stage
  /// commands, which the backend keeps for its own tooling.
  Future<void> engineChain(String gameId) async {
    final stages = StageApi(executor);
    await stages.runBaseEvaluation(gameId);
    await until(gameId, AnalysisStage.baseEvaluation);
    await stages.runBaseClassification(gameId);
    await until(gameId, AnalysisStage.baseClassification);
    await stages.runDeepEvaluation(gameId);
    await until(gameId, AnalysisStage.deepEvaluation);
  }

  test('the whole loop: import, list, consent, the coach, review and '
      'feedback', () async {
    final games = GamesApi(executor);
    final analysis = AnalysisApi(executor);
    final stages = StageApi(executor);
    final legal = LegalApi(executor);
    final usage = UsageApi(executor);

    // The fake token and the headers reach the server.
    final config = await ConfigApi(executor).mobileConfig();
    expect(config.supportedCoachLanguages, ['en', 'de']);
    final seen = server.requests.single;
    expect(seen.headers['authorization'], 'Bearer $kFakeAccessToken');
    expect(seen.headers['x-tenant-slug'], 'test-tenant');
    expect(seen.headers['graphql-preflight'], '1');
    expect(seen.headers['accept-language'], 'de-CH');
    expect(seen.headers['user-agent'], 'BognerChess-iOS/0.1.0+1');

    // Import, idempotent per clientGameId.
    final game = await importGame('client-1');
    expect((await importGame('client-1')).id, game.id);
    expect(game.clientGameId, 'client-1');
    expect(game.opponentName, 'Ada Lovelace');
    expect(game.playedDate, GameDate(2026, 9, 18));
    expect(game.timeControl?.detail, '15+10');
    expect(game.result, GameResult.whiteWins);

    final page = await games.list(search: 'lovelace');
    expect(page.games.single.id, game.id);
    expect((await games.list()).totalCount, 4);
    final detail = (await games.get(game.id))!;
    expect(detail.plyCount, 6);
    expect(detail.pgn, contains('[Event "Club night"]'));

    // One request, and the server runs the whole thing. Without the AI consent
    // it stops short of the coach — and says so, instead of refusing.
    final first = await stages.analyseGame(game.id, language: 'de');
    expect(
      (first as AnalysisAccepted).targetReason,
      AnalysisTargetReason.aiConsentRequired,
    );
    var workflow = await untilDone(game.id);
    expect(workflow.engineReady, isTrue, reason: 'the engine ran anyway');
    expect(workflow.coachReady, isFalse);
    expect(workflow.targetStage, AnalysisStage.deepEvaluation);
    expect(await analysis.analysis(game.id), isNull);

    final consent = await legal.aiConsent();
    expect(consent.required, isTrue);
    final text = (await legal.document(
      LegalDocumentKey.aiConsent,
      language: 'de',
    ))!;
    expect(text.language, 'de');
    expect(text.version, consent.currentVersion);
    expect(
      (await legal.recordAiConsent(version: text.version)).required,
      isFalse,
    );

    // The same request again, now with nothing in the way: it resumes at the
    // coach rather than analysing the game over again.
    final second = await stages.analyseGame(game.id, language: 'de');
    expect((second as AnalysisAccepted).targetReason, isNull);
    expect(second.workflow?.targetStage, AnalysisStage.coaching);
    workflow = await untilDone(game.id);
    expect(workflow.coachReady, isTrue);
    expect(workflow.isComplete, isTrue);
    expect(workflow.state, AnalysisWorkflowState.ready);
    expect(workflow.progress, isNull, reason: 'nothing is running');
    expect((await games.get(game.id))?.hasAnalysis, isTrue);

    // Review and feedback.
    final fetched = (await analysis.analysis(game.id))!;
    final document = (fetched.parsed as AnalysisSupported).document;
    expect(document.plyCount, 80);
    expect(document.language, 'de');
    expect(fetched.feedback, isEmpty);
    final comment = document.comments.first;
    expect(
      await analysis.submitFeedback(
        commentId: comment.id,
        rating: CommentRating.down,
      ),
      CommentRating.down,
    );
    expect((await analysis.analysis(game.id))?.feedback, {
      comment.id: CommentRating.down,
    });
    expect(
      await analysis.submitFeedback(commentId: comment.id, rating: null),
      isNull,
    );
    expect((await analysis.analysis(game.id))?.feedback, isEmpty);
    await expectLater(
      analysis.submitFeedback(commentId: 'nope', rating: CommentRating.up),
      throwsA(isA<ApiRejected>()),
    );

    // Only the coaching stage counts against the quota.
    expect((await usage.usage()).dailyUsed, 1);
  });

  test('one analyseGame: the chain, the three artifacts, the coach, and a '
      'document GameAnalysis serves', () async {
    final stages = StageApi(executor);
    final analysis = AnalysisApi(executor);
    final games = GamesApi(executor);
    final usage = UsageApi(executor);
    await LegalApi(executor).recordAiConsent(version: 1);
    final game = await importGame('client-1');

    // Nothing has run.
    var workflow = (await stages.workflow(game.id))!;
    expect(workflow.gameId, game.id);
    expect(workflow.state, AnalysisWorkflowState.idle);
    expect(workflow.progress, isNull);
    expect(workflow.targetStage, isNull, reason: 'nobody has asked yet');
    expect(workflow.stages.map((s) => s.state), [
      AnalysisStageState.notRun,
      AnalysisStageState.notRun,
      AnalysisStageState.notRun,
      AnalysisStageState.notRun,
    ]);
    expect(workflow.anyActive, isFalse);
    expect(workflow.newestReadyEngineStage, isNull);
    expect(
      workflow.stageOf(AnalysisStage.coaching)?.usesModel,
      isTrue,
      reason: 'the server says which stage is metered',
    );

    // A game that is not ours reads as null, which is how the tracker learns
    // to stop watching it.
    expect(await stages.workflow('does-not-exist'), isNull);

    // One request. The server aims at the coach and queues the first stage.
    final accepted =
        await stages.analyseGame(game.id, language: 'de') as AnalysisAccepted;
    expect(accepted.run, isNull, reason: 'the server picks the stage');
    expect(accepted.workflow?.targetStage, AnalysisStage.coaching);
    expect(accepted.targetReason, isNull);
    expect(accepted.workflow?.state, AnalysisWorkflowState.analysing);

    workflow = (await stages.workflow(game.id))!;
    expect(workflow.activeStage, AnalysisStage.baseEvaluation);
    expect(workflow.state, AnalysisWorkflowState.analysing);
    expect(workflow.progress, inInclusiveRange(0.0, 1.0));

    // Asking again while a stage runs changes nothing.
    final again =
        await stages.analyseGame(game.id, language: 'de') as AnalysisAccepted;
    expect(again.workflow?.activeStage, AnalysisStage.baseEvaluation);
    expect(
      (await stages.workflow(game.id))!.stages
          .where((s) => s.run != null)
          .length,
      1,
      reason: 'no second run of the same stage',
    );

    // The app never starts a stage; the poll is what moves the chain on.
    workflow = await untilDone(game.id);
    expect(workflow.isComplete, isTrue);
    expect(workflow.coachReady, isTrue);
    expect(workflow.state, AnalysisWorkflowState.ready);
    expect(workflow.progress, isNull);
    expect(workflow.readyRunIds.keys, AnalysisStage.pipeline);

    // The three engine artifacts, each by run id, once.
    final ids = workflow.readyRunIds;
    final base = (await stages.artifact(ids[AnalysisStage.baseEvaluation]!))!;
    expect(base.stage, AnalysisStage.baseEvaluation);
    expect(base.status, JobStatus.done);
    expect(base.artifact?.json['stage'], 'base_evaluation');
    expect(base.artifact?.json['nodes'], isA<List<Object?>>());
    expect(await stages.artifact('run-does-not-exist'), isNull);

    final classified = (await stages.artifact(
      ids[AnalysisStage.baseClassification]!,
    ))!;
    expect(classified.artifact?.json['stage'], 'base_classification');

    final packet = (await stages.artifact(ids[AnalysisStage.deepEvaluation]!))!;
    expect(packet.artifact?.json['stage'], 'deep_evaluation');
    expect(
      (packet.artifact?.json['engine'] as Map).keys,
      contains('pass1_nodes'),
      reason: 'stage 3 writes engine flat',
    );

    // The coaching run carries the language the one request asked for, and so
    // do the engine runs that handed it down.
    final run = workflow.stageOf(AnalysisStage.coaching)!.run!;
    expect(run.language, 'de');
    expect(run.hasArtifact, isTrue);
    expect(
      workflow.stageOf(AnalysisStage.baseEvaluation)!.run!.language,
      'de',
      reason: 'a chained engine stage carries the coach language',
    );

    final document = (await analysis.analysis(game.id))!;
    final parsed = document.parsed as AnalysisSupported;
    expect(parsed.document.language, 'de');
    expect(parsed.document.plyCount, 80);
    expect((await games.get(game.id))?.hasAnalysis, isTrue);
    expect(
      (await usage.usage()).dailyUsed,
      1,
      reason: 'only the coaching stage of the chain is metered',
    );

    // Feedback on a staged document works like on any other.
    expect(
      await analysis.submitFeedback(
        commentId: parsed.document.comments.first.id,
        rating: CommentRating.up,
      ),
      CommentRating.up,
    );
  });

  test('analyseGame refuses: a rate limit; and reports a failure and stale '
      'moves as states', () async {
    final stages = StageApi(executor);
    await LegalApi(executor).recordAiConsent(version: 1);
    final game = await importGame('client-1');

    server.backend.applyScenario('rate_limited', const {
      'retryAfterSeconds': 12,
    });
    final limited = await stages.analyseGame(game.id);
    expect(limited, isA<AnalysisRateLimited>());
    expect(
      (limited as AnalysisRateLimited).retryAfter,
      const Duration(seconds: 12),
      reason: 'fair use is the one thing analyseGame refuses for',
    );

    // A stage that fails stops the chain and the workflow says FAILED; one
    // more analyseGame resumes there.
    server.backend.applyScenario('default', const {});
    server.backend.applyScenario('stage_fails', const {
      'stage': 'DEEP_EVALUATION',
    });
    var workflow = await analyse(game.id);
    expect(workflow.state, AnalysisWorkflowState.failed);
    expect(workflow.failedStage, AnalysisStage.deepEvaluation);
    expect(
      workflow.stageOf(AnalysisStage.deepEvaluation)?.run?.failureCode,
      'stage_input_missing',
    );
    expect(
      workflow.coachReady,
      isFalse,
      reason: 'the chain never reached the coach',
    );

    server.backend.applyScenario('default', const {});
    workflow = await analyse(game.id);
    expect(workflow.state, AnalysisWorkflowState.ready);
    expect(
      workflow.stateOf(AnalysisStage.baseEvaluation),
      AnalysisStageState.ready,
      reason: 'the stored stages were not run again',
    );

    // The seeded analysed game has a finished pipeline that goes stale when
    // its moves change.
    server.backend.applyScenario('stale', const {});
    final stale = (await stages.workflow('game-1'))!;
    expect(stale.state, AnalysisWorkflowState.stale);
    expect(
      stale.stages.map((s) => s.state),
      everyElement(AnalysisStageState.stale),
    );
    expect(stale.isComplete, isFalse);
    expect(stale.readyRunIds, isEmpty);
    expect(stale.progress, isNull);
  });

  test('the fourth coach request of the day reaches the limit', () async {
    await server.close();
    await start(MockOptions(queuedPolls: 0, runningPolls: 0));
    final stages = StageApi(executor);
    await LegalApi(executor).recordAiConsent(version: 1);

    for (var i = 1; i <= 3; i++) {
      final game = await importGame('client-$i');
      await engineChain(game.id);
      expect(await stages.runCoaching(game.id), isA<AnalysisAccepted>());
      expect((await until(game.id, AnalysisStage.coaching)).coachReady, isTrue);
    }
    final usage = await UsageApi(executor).usage();
    expect(usage.dailyUsed, 3);
    expect(usage.dailyRemaining, 0);
    expect(usage.canRequest, isFalse);

    // The one button never refuses for the quota: the engine runs and the
    // workflow says the coach was left out.
    final fourth = await importGame('client-4');
    final blocked = await stages.analyseGame(fourth.id) as AnalysisAccepted;
    expect(blocked.targetReason, AnalysisTargetReason.limitReached);
    expect(blocked.workflow?.targetStage, AnalysisStage.deepEvaluation);
    final engineOnly = await untilDone(fourth.id);
    expect(engineOnly.engineReady, isTrue);
    expect(engineOnly.coachReady, isFalse);
    expect(engineOnly.targetReason, AnalysisTargetReason.limitReached);

    // The one-stage command, which is what "run the coach again" uses, still
    // comes back with the typed numbers.
    final game = await importGame('client-5');
    await engineChain(game.id);
    final outcome = await stages.runCoaching(game.id);
    final limit = outcome as AnalysisLimitReached;
    expect(limit.window, LimitWindow.day);
    expect(limit.limit, 3);
    expect(limit.used, 3);
    expect(limit.resetAt.isUtc, isTrue);
    expect(limit.resetAt.isAfter(DateTime.now()), isTrue);
    expect(limit.resetAt, usage.dailyResetAt);
  });

  test('scenarios: an unconfirmed address refuses the coach, an invalid PGN '
      'refuses the import', () async {
    final stages = StageApi(executor);
    server.backend.applyScenario('consent_accepted', const {});
    final game = await importGame('client-1');
    await engineChain(game.id);

    server.backend.applyScenario('email_not_verified', const {});
    expect(await stages.runCoaching(game.id), isA<AnalysisEmailNotVerified>());
    // The one button does not refuse for it either; it is a reason.
    final other = await importGame('client-3');
    expect(
      (await stages.analyseGame(other.id) as AnalysisAccepted).targetReason,
      AnalysisTargetReason.emailNotVerified,
    );

    final invalid = await GamesApi(executor).import(
      metadata: metadata,
      movetext: '1. e4 e5 2. Zz9',
      clientGameId: 'client-2',
      source: ImportSource.pgn,
    );
    expect((invalid as ImportPgnInvalid).san, 'Zz9');
    expect(invalid.moveNumber, 2);
  });

  test('unauthenticated_once: one refresh, one retry, the caller notices '
      'nothing', () async {
    server.backend.applyScenario('unauthenticated_once', const {});

    final page = await GamesApi(executor).list();

    expect(page.totalCount, 3);
    expect(server.requests.map((r) => r.status), [401, 200]);
  });

  test('signed out: no request reaches the server', () async {
    await auth.signOut();
    await expectLater(
      GamesApi(executor).list(),
      throwsA(const ApiUnauthenticated()),
    );
    expect(server.requests, isEmpty);
  });

  test('slow: the time limit of the call applies', () async {
    server.backend.applyScenario('slow', const {'delayMs': 400});
    await expectLater(
      executor.query(
        document: documentNodeQueryMobileConfig,
        operationName: 'MobileConfig',
        parse: Query$MobileConfig.fromJson,
        timeout: const Duration(milliseconds: 50),
      ),
      throwsA(const ApiNetworkError(ApiNetworkCause.timeout)),
    );
  });

  test('a server that is not there is a network error', () async {
    final uri = server.graphqlUri;
    await server.close();
    final offline = chainExecutor(auth: auth, apiUrl: uri);
    await expectLater(
      ConfigApi(offline).mobileConfig(),
      throwsA(const ApiNetworkError()),
    );
  });

  test('devices, events, consents and account deletion', () async {
    final devices = DevicesApi(executor);
    final registered = await devices.register(
      deviceId: 'installation-1',
      environment: ApnsEnvironment.sandbox,
      appVersion: '0.1.0+1',
      locale: 'de-CH',
    );
    expect(registered.deviceId, 'installation-1');
    expect((await devices.unregister('installation-1'))?.revokedAt, isNotNull);
    expect(await devices.unregister('never-seen'), isNull);

    final events = EventsApi(executor);
    final event = AnalyticsEvent(
      name: 'app_opened',
      occurredAt: DateTime.utc(2026, 9, 19, 10),
      props: const {'cold': true},
    );
    expect(
      (await events.track(
        deviceId: 'd',
        sessionId: 's',
        events: [event],
      )).accepted,
      1,
    );

    final legal = LegalApi(executor);
    expect(
      (await legal.consent(LegalDocumentKey.analyticsConsent)).required,
      isTrue,
    );
    final withdrawn = await legal.recordConsent(
      key: LegalDocumentKey.analyticsConsent,
      version: 1,
      accepted: false,
    );
    expect(withdrawn.withdrawnAt, isNotNull);
    expect(
      (await events.track(
        deviceId: 'd',
        sessionId: 's',
        events: [event],
      )).rejected,
      1,
    );
    final accepted = await legal.recordConsent(
      key: LegalDocumentKey.analyticsConsent,
      version: 1,
      accepted: true,
    );
    expect(accepted.required, isFalse);
    await expectLater(
      legal.recordAiConsent(version: 99),
      throwsA(
        isA<ApiRejected>().having((e) => e.propertyName, 'property', 'Version'),
      ),
    );

    final games = GamesApi(executor);
    expect(await games.delete('game-3'), isA<GameDeleted>());
    expect(await games.delete('game-3'), isA<DeleteGameFailed>());

    final account = AccountApi(executor);
    server.backend.applyScenario('deletion_blocked', const {});
    expect(await account.deleteMyAccount(), isA<AccountDeletionBlocked>());
    server.backend.applyScenario('default', const {});
    final deleted = await account.deleteMyAccount() as AccountDeletionRequested;
    expect(deleted.deletion.status, AccountDeletionStatus.pending);
    expect((await games.list()).games, isEmpty);
  });
}
