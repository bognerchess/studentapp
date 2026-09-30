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
import 'package:bogner_chess/core/api/mappers/mutation_error.dart';
import 'package:bogner_chess/core/api/models/analysis_models.dart';

export 'package:bogner_chess/core/analysis/analysis_parse_result.dart';
export 'package:bogner_chess/core/api/api_error.dart';
export 'package:bogner_chess/core/api/models/analysis_models.dart';

/// Finished analyses and feedback on coach comments.
///
/// Starting an analysis is `StageApi`: the pipeline runs one stage at a time
/// and only the coaching stage writes the document this class reads.
class AnalysisApi {
  AnalysisApi(this._executor);

  final ApiExecutor _executor;

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
