// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/generated/schema.graphql.dart';
import 'package:bogner_chess/core/api/models/account_models.dart';
import 'package:bogner_chess/core/api/models/analysis_models.dart';
import 'package:bogner_chess/core/api/models/device_models.dart';
import 'package:bogner_chess/core/api/models/game_models.dart';
import 'package:bogner_chess/core/api/models/legal_models.dart';
import 'package:bogner_chess/core/game/game_metadata.dart';

// Every switch over a generated enum has a case for `$unknown`, the value the
// generated fromJson gives to anything a newer server may send.

PlayerColor playerColorOf(Enum$ChessGamePlayerColor value) => switch (value) {
  Enum$ChessGamePlayerColor.BLACK => PlayerColor.black,
  Enum$ChessGamePlayerColor.WHITE ||
  Enum$ChessGamePlayerColor.$unknown => PlayerColor.white,
};

Enum$ChessGamePlayerColor playerColorToWire(PlayerColor value) =>
    switch (value) {
      PlayerColor.white => Enum$ChessGamePlayerColor.WHITE,
      PlayerColor.black => Enum$ChessGamePlayerColor.BLACK,
    };

GameResult gameResultOf(Enum$ChessGameResult value) => switch (value) {
  Enum$ChessGameResult.WHITE_WINS => GameResult.whiteWins,
  Enum$ChessGameResult.BLACK_WINS => GameResult.blackWins,
  Enum$ChessGameResult.DRAW => GameResult.draw,
  Enum$ChessGameResult.ONGOING ||
  Enum$ChessGameResult.$unknown => GameResult.unknown,
};

/// Null for an unknown result: the server then reads the PGN `Result` tag.
Enum$ChessGameResult? gameResultToWire(GameResult value) => switch (value) {
  GameResult.whiteWins => Enum$ChessGameResult.WHITE_WINS,
  GameResult.blackWins => Enum$ChessGameResult.BLACK_WINS,
  GameResult.draw => Enum$ChessGameResult.DRAW,
  GameResult.unknown => null,
};

Enum$ChessGameSource importSourceToWire(ImportSource value) => switch (value) {
  ImportSource.board => Enum$ChessGameSource.MOBILE_BOARD,
  ImportSource.pgn => Enum$ChessGameSource.MOBILE_PGN,
  ImportSource.share => Enum$ChessGameSource.MOBILE_SHARE,
};

JobStatus jobStatusOf(Enum$AnalysisJobStatus value) => switch (value) {
  Enum$AnalysisJobStatus.QUEUED => JobStatus.queued,
  Enum$AnalysisJobStatus.RUNNING => JobStatus.running,
  Enum$AnalysisJobStatus.DONE => JobStatus.done,
  Enum$AnalysisJobStatus.FAILED => JobStatus.failed,
  Enum$AnalysisJobStatus.$unknown => JobStatus.unknown,
};

/// From the wire name, because it is read from an error's JSON form.
LimitWindow limitWindowOf(Object? value) => switch (value) {
  'DAY' || Enum$LimitWindow.DAY => LimitWindow.day,
  'MONTH' || Enum$LimitWindow.MONTH => LimitWindow.month,
  _ => LimitWindow.unknown,
};

UsagePolicy usagePolicyOf(Enum$LimitPolicyKind value) => switch (value) {
  Enum$LimitPolicyKind.DEFAULT => UsagePolicy.standard,
  Enum$LimitPolicyKind.CUSTOM => UsagePolicy.custom,
  Enum$LimitPolicyKind.UNLIMITED => UsagePolicy.unlimited,
  Enum$LimitPolicyKind.$unknown => UsagePolicy.unknown,
};

/// Null for a rating this build does not know: it is then not shown.
CommentRating? commentRatingOf(Enum$CommentRating value) => switch (value) {
  Enum$CommentRating.UP => CommentRating.up,
  Enum$CommentRating.DOWN => CommentRating.down,
  Enum$CommentRating.$unknown => null,
};

Enum$CommentRating commentRatingToWire(CommentRating value) => switch (value) {
  CommentRating.up => Enum$CommentRating.UP,
  CommentRating.down => Enum$CommentRating.DOWN,
};

Enum$ApnsEnvironment apnsEnvironmentToWire(ApnsEnvironment value) =>
    switch (value) {
      ApnsEnvironment.sandbox => Enum$ApnsEnvironment.SANDBOX,
      ApnsEnvironment.production => Enum$ApnsEnvironment.PRODUCTION,
    };

LegalDocumentKey legalDocumentKeyOf(Enum$LegalDocumentKey value) =>
    switch (value) {
      Enum$LegalDocumentKey.AI_CONSENT => LegalDocumentKey.aiConsent,
      Enum$LegalDocumentKey.PRIVACY_POLICY => LegalDocumentKey.privacyPolicy,
      Enum$LegalDocumentKey.TERMS => LegalDocumentKey.terms,
      Enum$LegalDocumentKey.ANALYTICS_CONSENT =>
        LegalDocumentKey.analyticsConsent,
      Enum$LegalDocumentKey.$unknown => LegalDocumentKey.unknown,
    };

/// Throws an [ArgumentError] for [LegalDocumentKey.unknown], which is only
/// ever read.
Enum$LegalDocumentKey legalDocumentKeyToWire(LegalDocumentKey value) =>
    switch (value) {
      LegalDocumentKey.aiConsent => Enum$LegalDocumentKey.AI_CONSENT,
      LegalDocumentKey.privacyPolicy => Enum$LegalDocumentKey.PRIVACY_POLICY,
      LegalDocumentKey.terms => Enum$LegalDocumentKey.TERMS,
      LegalDocumentKey.analyticsConsent =>
        Enum$LegalDocumentKey.ANALYTICS_CONSENT,
      LegalDocumentKey.unknown => throw ArgumentError.value(
        value,
        'key',
        'cannot be sent',
      ),
    };

AccountDeletionStatus accountDeletionStatusOf(
  Enum$AccountDeletionStatus value,
) => switch (value) {
  Enum$AccountDeletionStatus.PENDING => AccountDeletionStatus.pending,
  Enum$AccountDeletionStatus.COMPLETED => AccountDeletionStatus.completed,
  Enum$AccountDeletionStatus.BLOCKED => AccountDeletionStatus.blocked,
  Enum$AccountDeletionStatus.FAILED => AccountDeletionStatus.failed,
  Enum$AccountDeletionStatus.$unknown => AccountDeletionStatus.unknown,
};
