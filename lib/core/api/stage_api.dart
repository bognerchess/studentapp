// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/api_client.dart';
import 'package:bogner_chess/core/api/api_error.dart';
import 'package:bogner_chess/core/api/generated/operations/stages.graphql.dart';
import 'package:bogner_chess/core/api/generated/schema.graphql.dart';
import 'package:bogner_chess/core/api/mappers/enum_mappers.dart';
import 'package:bogner_chess/core/api/mappers/mutation_error.dart';
import 'package:bogner_chess/core/api/mappers/stage_mapper.dart';
import 'package:bogner_chess/core/api/models/analysis_models.dart';
import 'package:bogner_chess/core/api/models/stage_models.dart';

export 'package:bogner_chess/core/api/api_error.dart';
export 'package:bogner_chess/core/api/models/analysis_models.dart';
export 'package:bogner_chess/core/api/models/stage_models.dart';

/// The message key the server sends when a stage was asked for before the
/// stage it builds on was stored. Anything else from a `BusinessError` is a
/// plain failure.
const String kStagePrerequisiteMissingKey =
    'web_api_errors.stage_prerequisite_missing';

/// The analysis pipeline: the workflow of a game, the artifact of one run,
/// [analyseGame] for the whole chain, and the four commands that start one
/// stage each.
///
/// [analyseGame] is what the app uses. The server chains the stages and goes
/// as far as the coach when the coach is allowed; a closed gate of the coach
/// is not an error of it, it is `targetReason` on the workflow it answers
/// with. The four `run*` commands are the backend's one-stage surface, kept
/// here because `runCoaching` is still how an account without a limit asks
/// the coach to write again.
class StageApi {
  StageApi(this._executor);

  final ApiExecutor _executor;

  /// The pipeline of [gameId]: four stages, their states, and which one can
  /// be started next.
  ///
  /// Null when the game does not exist or belongs to someone else — the
  /// field is non-null in the schema, so the server reports that as a
  /// top-level error. The tracker reads null as "stop watching this game".
  /// Throws an [ApiError] for anything else.
  Future<AnalysisWorkflow?> workflow(String gameId) async {
    final Query$GameAnalysisWorkflow data;
    try {
      data = await _executor.query(
        document: documentNodeQueryGameAnalysisWorkflow,
        operationName: 'GameAnalysisWorkflow',
        variables: Variables$Query$GameAnalysisWorkflow(gameId: gameId)
            .toJson(),
        parse: Query$GameAnalysisWorkflow.fromJson,
      );
    } on ApiGraphQLError catch (e) {
      if (_isGameGone(e)) {
        return null;
      }
      rethrow;
    }
    return workflowOf(data.gameAnalysisWorkflow);
  }

  /// One run with its artifact; null when it does not exist or belongs to
  /// someone else. Uses the long analysis timeout: an artifact is hundreds of
  /// kilobytes. Throws an [ApiError].
  Future<StageRun?> artifact(String runId) async {
    final data = await _executor.query(
      document: documentNodeQueryEngineStageRun,
      operationName: 'EngineStageRun',
      variables: Variables$Query$EngineStageRun(id: runId).toJson(),
      parse: Query$EngineStageRun.fromJson,
      timeout: kAnalysisApiTimeout,
    );
    final run = data.engineStageRun;
    return run == null ? null : stageRunOf(run);
  }

  /// Runs the whole analysis of [gameId]: the server queues the first stage
  /// that is not stored and chains the ones after it, as far as the coach when
  /// the caller may ask the coach now, else as far as the deep evaluation.
  ///
  /// Idempotent while a stage runs, and after a failure it resumes at the
  /// stage that failed, so this is the retry as well. The quota, the queue
  /// cap, the fair-use limit of the coach, an unconfirmed address and a
  /// missing AI consent are **never** errors here: the engine result is
  /// produced anyway and `AnalysisWorkflow.targetReason` says what the user is
  /// missing. What is left is the fair-use limit of the engine commands, a
  /// game that is gone, and a game without readable moves.
  ///
  /// [language] is one of `MobileConfig.supportedCoachLanguages` (see
  /// `MobileConfig.coachLanguageFor`); it is what the coach writes in should
  /// the chain reach it. Never throws.
  Future<RequestAnalysisOutcome> analyseGame(
    String gameId, {
    String language = 'en',
    String? persona,
  }) async {
    final Mutation$AnalyseGame data;
    try {
      data = await _executor.mutate(
        document: documentNodeMutationAnalyseGame,
        operationName: 'AnalyseGame',
        variables: Variables$Mutation$AnalyseGame(
          input: Input$AnalyseGameInput(
            chessGameId: gameId,
            language: language.toLowerCase(),
            persona: persona,
          ),
        ).toJson(),
        parse: Mutation$AnalyseGame.fromJson,
      );
    } on ApiError catch (e) {
      return AnalysisRequestFailed(e);
    }
    final payload = data.analyseGame;
    final error = MutationError.firstOf(payload.errors?.map((e) => e.toJson()));
    if (error != null) {
      return outcomeOf(error);
    }
    final workflow = payload.gameAnalysisWorkflow;
    return workflow == null
        ? AnalysisRequestFailed(emptyPayload('AnalyseGame'))
        : AnalysisAccepted(workflow: workflowOf(workflow));
  }

  /// Stage 1: one engine pass over every position. Free, never refused for
  /// quota. Never throws.
  Future<RequestAnalysisOutcome> runBaseEvaluation(String gameId) async {
    final Mutation$RunBaseEvaluation data;
    try {
      data = await _executor.mutate(
        document: documentNodeMutationRunBaseEvaluation,
        operationName: 'RunBaseEvaluation',
        variables: Variables$Mutation$RunBaseEvaluation(
          input: Input$RunBaseEvaluationInput(chessGameId: gameId),
        ).toJson(),
        parse: Mutation$RunBaseEvaluation.fromJson,
      );
    } on ApiError catch (e) {
      return AnalysisRequestFailed(e);
    }
    final payload = data.runBaseEvaluation;
    return _accepted(
      'RunBaseEvaluation',
      payload.engineStageRun,
      payload.errors?.map((e) => e.toJson()),
    );
  }

  /// Stage 2: the moves worth a deeper look. [maxMoments] is the cheap knob;
  /// null is the pipeline default. Never throws.
  Future<RequestAnalysisOutcome> runBaseClassification(
    String gameId, {
    int? maxMoments,
  }) async {
    final Mutation$RunBaseClassification data;
    try {
      data = await _executor.mutate(
        document: documentNodeMutationRunBaseClassification,
        operationName: 'RunBaseClassification',
        variables: Variables$Mutation$RunBaseClassification(
          input: Input$RunBaseClassificationInput(
            chessGameId: gameId,
            maxMoments: maxMoments,
          ),
        ).toJson(),
        parse: Mutation$RunBaseClassification.fromJson,
      );
    } on ApiError catch (e) {
      return AnalysisRequestFailed(e);
    }
    final payload = data.runBaseClassification;
    return _accepted(
      'RunBaseClassification',
      payload.engineStageRun,
      payload.errors?.map((e) => e.toJson()),
    );
  }

  /// Stage 3: the multi-line search on the selected moves, the fact packet
  /// the coach reads. Never throws.
  Future<RequestAnalysisOutcome> runDeepEvaluation(String gameId) async {
    final Mutation$RunDeepEvaluation data;
    try {
      data = await _executor.mutate(
        document: documentNodeMutationRunDeepEvaluation,
        operationName: 'RunDeepEvaluation',
        variables: Variables$Mutation$RunDeepEvaluation(
          input: Input$RunDeepEvaluationInput(chessGameId: gameId),
        ).toJson(),
        parse: Mutation$RunDeepEvaluation.fromJson,
      );
    } on ApiError catch (e) {
      return AnalysisRequestFailed(e);
    }
    final payload = data.runDeepEvaluation;
    return _accepted(
      'RunDeepEvaluation',
      payload.engineStageRun,
      payload.errors?.map((e) => e.toJson()),
    );
  }

  /// Stage 4: the coach writes. The only metered stage, so this is the one
  /// call that comes back with a quota, consent or e-mail outcome.
  ///
  /// [language] is one of `MobileConfig.supportedCoachLanguages` (see
  /// `MobileConfig.coachLanguageFor`). [persona] is a coach character; null
  /// is the house voice. Never throws.
  Future<RequestAnalysisOutcome> runCoaching(
    String gameId, {
    String language = 'en',
    String? persona,
  }) async {
    final Mutation$RunCoaching data;
    try {
      data = await _executor.mutate(
        document: documentNodeMutationRunCoaching,
        operationName: 'RunCoaching',
        variables: Variables$Mutation$RunCoaching(
          input: Input$RunCoachingInput(
            chessGameId: gameId,
            language: language.toLowerCase(),
            persona: persona,
          ),
        ).toJson(),
        parse: Mutation$RunCoaching.fromJson,
      );
    } on ApiError catch (e) {
      return AnalysisRequestFailed(e);
    }
    final payload = data.runCoaching;
    return _accepted(
      'RunCoaching',
      payload.engineStageRun,
      payload.errors?.map((e) => e.toJson()),
    );
  }

  static RequestAnalysisOutcome _accepted(
    String operationName,
    Fragment$StageRunFields? run,
    Iterable<Map<String, dynamic>>? errors,
  ) {
    final error = MutationError.firstOf(errors);
    if (error != null) {
      return outcomeOf(error);
    }
    return run == null
        ? AnalysisRequestFailed(emptyPayload(operationName))
        : AnalysisAccepted(run: stageRunOf(run));
  }

  /// A top-level GraphQL error that means "this game is not yours or is
  /// gone".
  ///
  /// The backend raises a `BusinessError` from the resolver, which the error
  /// filter turns into a plain message with no code of its own, so the
  /// message is all there is to go on. Both the message key BE-22 introduces
  /// and the English sentence the resolver sends today are accepted; anything
  /// else is rethrown, so a cost or validation problem is never mistaken for
  /// a deleted game.
  static bool _isGameGone(ApiGraphQLError error) {
    if (error.codes.any(_notFoundCodes.contains)) {
      return true;
    }
    for (final message in error.messages) {
      final lower = message.toLowerCase();
      if (lower.contains('entity_not_found') ||
          lower.contains('does not exist')) {
        return true;
      }
    }
    return false;
  }

  static const Set<String> _notFoundCodes = {'ENTITY_NOT_FOUND', 'NOT_FOUND'};
}

/// What a mutation's error union means for the caller.
///
/// Shared by every command of [StageApi]: the members are a subset of one
/// another, and the staged path adds only [AnalysisPrerequisiteMissing] on
/// top. `analyseGame` can only answer with the rate limit and the generic
/// members, so the quota and consent cases below are dead code on that path —
/// and must stay, because the one-stage `runCoaching` still reaches them.
RequestAnalysisOutcome outcomeOf(MutationError error) {
  switch (error.typename) {
    case 'AnalysisLimitReachedError':
      final limit = error.integer('limit');
      final used = error.integer('used');
      final resetAt = error.instant('resetAt');
      if (limit != null && used != null && resetAt != null) {
        return AnalysisLimitReached(
          window: limitWindowOf(error.string('window')),
          limit: limit,
          used: used,
          resetAt: resetAt,
        );
      }
    case 'AnalysisQueueFullError':
      final max = error.integer('maxQueuedJobs');
      if (max != null) {
        return AnalysisQueueFull(max);
      }
    case 'RateLimitedError':
      return AnalysisRateLimited(error.retryAfter);
    case 'EmailNotVerifiedError':
      return const AnalysisEmailNotVerified();
    case 'AiConsentRequiredError':
      final version = error.integer('requiredVersion');
      if (version != null) {
        return AnalysisAiConsentRequired(version);
      }
    case 'BusinessError':
      if (error.message == kStagePrerequisiteMissingKey) {
        return const AnalysisPrerequisiteMissing();
      }
  }
  return AnalysisRequestFailed(error.toRejected());
}
