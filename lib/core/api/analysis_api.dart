// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

import 'package:bogner_chess/core/analysis/analysis_parser.dart'
    show AnalysisParser, kMaxSupportedAnalysisSchema;
import 'package:bogner_chess/core/api/api_client.dart';
import 'package:bogner_chess/core/api/api_error.dart';
import 'package:bogner_chess/core/api/generated/operations/analysis.graphql.dart';
import 'package:bogner_chess/core/api/generated/schema.graphql.dart';
import 'package:bogner_chess/core/api/mappers/enum_mappers.dart';
import 'package:bogner_chess/core/api/mappers/game_mapper.dart';
import 'package:bogner_chess/core/api/mappers/mutation_error.dart';
import 'package:bogner_chess/core/api/models/analysis_models.dart';

export 'package:bogner_chess/core/analysis/analysis_parse_result.dart';
export 'package:bogner_chess/core/api/api_error.dart';
export 'package:bogner_chess/core/api/models/analysis_models.dart';

/// Analysis jobs, finished analyses and feedback on coach comments.
class AnalysisApi {
  AnalysisApi(this._executor);

  final ApiExecutor _executor;

  /// Queues a whole-game analysis of [gameId].
  ///
  /// [language] is the coach language, one of
  /// `MobileConfig.supportedCoachLanguages` (see
  /// `MobileConfig.coachLanguageFor`). [deviceId] is the installation id.
  /// Never throws: quota, queue cap, rate limit, unverified e-mail address and
  /// missing AI consent are outcomes.
  Future<RequestAnalysisOutcome> request({
    required String gameId,
    String language = 'en',
    String? deviceId,
  }) async {
    final Mutation$RequestGameAnalysis data;
    try {
      data = await _executor.mutate(
        document: documentNodeMutationRequestGameAnalysis,
        operationName: 'RequestGameAnalysis',
        variables: Variables$Mutation$RequestGameAnalysis(
          input: Input$RequestGameAnalysisInput(
            chessGameId: gameId,
            deviceId: deviceId,
            language: language.toLowerCase(),
          ),
        ).toJson(),
        parse: Mutation$RequestGameAnalysis.fromJson,
      );
    } on ApiError catch (e) {
      return AnalysisRequestFailed(e);
    }
    final payload = data.requestGameAnalysis;
    final error = MutationError.firstOf(payload.errors?.map((e) => e.toJson()));
    if (error != null) {
      return _outcomeOf(error);
    }
    final job = payload.analysisJob;
    return job == null
        ? AnalysisRequestFailed(emptyPayload('RequestGameAnalysis'))
        : AnalysisAccepted(jobOf(job));
  }

  static RequestAnalysisOutcome _outcomeOf(MutationError error) {
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
    }
    return AnalysisRequestFailed(error.toRejected());
  }

  /// One job; null when it does not exist or belongs to someone else. Throws
  /// an [ApiError].
  Future<JobInfo?> job(String id) async {
    final data = await _executor.query(
      document: documentNodeQueryAnalysisJob,
      operationName: 'AnalysisJob',
      variables: Variables$Query$AnalysisJob(id: id).toJson(),
      parse: Query$AnalysisJob.fromJson,
    );
    final job = data.analysisJob;
    return job == null ? null : jobOf(job);
  }

  /// The user's jobs that are queued or running, oldest first. A job that is
  /// missing here has finished or failed. Throws an [ApiError].
  Future<List<JobInfo>> activeJobs() async {
    final data = await _executor.query(
      document: documentNodeQueryMyActiveAnalysisJobs,
      operationName: 'MyActiveAnalysisJobs',
      parse: Query$MyActiveAnalysisJobs.fromJson,
    );
    return List.unmodifiable(data.myActiveAnalysisJobs.map(jobOf));
  }

  /// The latest finished analysis of [gameId]; null when there is none yet.
  ///
  /// The server never hides a result because of [maxSchemaVersion]: a newer
  /// document comes back as `AnalysisNewerMajor` in [FetchedAnalysis.parsed].
  /// Throws an [ApiError].
  Future<FetchedAnalysis?> analysis(
    String gameId, {
    int maxSchemaVersion = kMaxSupportedAnalysisSchema,
  }) async {
    final data = await _executor.query(
      document: documentNodeQueryGameAnalysis,
      operationName: 'GameAnalysis',
      variables: Variables$Query$GameAnalysis(
        gameId: gameId,
        maxSchemaVersion: maxSchemaVersion,
      ).toJson(),
      parse: Query$GameAnalysis.fromJson,
      timeout: kAnalysisApiTimeout,
    );
    final analysis = data.gameAnalysis;
    if (analysis == null) {
      return null;
    }
    // The server sends the document as a JSON value. Should it ever arrive as
    // a string, that string is the JSON already.
    final document = analysis.document;
    final rawJson = document is String ? document : jsonEncode(document);
    return FetchedAnalysis(
      id: analysis.id,
      gameId: analysis.chessGameId,
      schemaVersion: analysis.schemaVersion,
      schemaMinor: analysis.schemaMinor,
      createdAt: analysis.createdAt,
      rawJson: rawJson,
      parsed: AnalysisParser.parseString(
        rawJson,
        maxSupportedMajor: maxSchemaVersion,
      ),
      feedback: Map.unmodifiable({
        for (final entry in analysis.commentFeedback)
          entry.commentId: ?commentRatingOf(entry.rating),
      }),
    );
  }

  /// Thumbs up or down on a coach comment; null clears the rating. Returns
  /// the rating the server now has. Throws an [ApiError]; the feedback outbox
  /// retries when it is retryable.
  Future<CommentRating?> submitFeedback({
    required String commentId,
    required CommentRating? rating,
  }) async {
    // A null field is left out by the generated input, and the server reads a
    // missing rating as "clear", the same as an explicit null.
    final data = await _executor.mutate(
      document: documentNodeMutationSubmitCoachCommentFeedback,
      operationName: 'SubmitCoachCommentFeedback',
      variables: Variables$Mutation$SubmitCoachCommentFeedback(
        input: Input$SubmitCoachCommentFeedbackInput(
          commentId: commentId,
          rating: rating == null ? null : commentRatingToWire(rating),
        ),
      ).toJson(),
      parse: Mutation$SubmitCoachCommentFeedback.fromJson,
    );
    final payload = data.submitCoachCommentFeedback;
    final error = MutationError.firstOf(payload.errors?.map((e) => e.toJson()));
    if (error != null) {
      throw error.toRejected();
    }
    final feedback = payload.coachCommentFeedback;
    return feedback == null ? null : commentRatingOf(feedback.rating);
  }
}
