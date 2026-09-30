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

/// The staged analysis pipeline: the workflow of a game, the artifact of one
/// run, and the four commands that start a stage.
///
/// The three engine stages are free and the app chains them; `runCoaching` is
/// the only one that can be refused, and it is where the quota, the consent
/// and the e-mail check live.
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
        : AnalysisAccepted(stageRunOf(run));
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
/// Shared by [StageApi] and, until B12 removes it, by `AnalysisApi.request`:
/// the members are the same on both, and the staged path adds only
/// [AnalysisPrerequisiteMissing] on top.
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
