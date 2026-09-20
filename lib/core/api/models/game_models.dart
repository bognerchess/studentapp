// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/api_error.dart';
import 'package:bogner_chess/core/api/models/analysis_models.dart';
import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:flutter/foundation.dart';

/// A game as the server stores it, without its moves: a row of the library.
///
/// [toString] leaves the names out, so that logging one does not leak
/// personal data.
@immutable
class GameSummary {
  const GameSummary({
    required this.id,
    required this.playerColor,
    required this.result,
    required this.hasAnalysis,
    this.clientGameId,
    this.whiteName,
    this.blackName,
    this.opponentName,
    this.whiteRating,
    this.blackRating,
    this.playedDate,
    this.eventName,
    this.timeControlTag,
    this.plyCount,
    this.createdAt,
    this.latestJob,
  });

  /// The server's id of the game.
  final String id;

  /// The idempotency key the app sent when it created the game; null for a
  /// game that was entered on the web.
  final String? clientGameId;

  final String? whiteName;
  final String? blackName;

  /// As stored by the server. Usually, but not necessarily, the name of the
  /// side that is not [playerColor].
  final String? opponentName;

  final int? whiteRating;
  final int? blackRating;

  /// The side the user played. A colour this build does not know reads as
  /// white, which is what the server assumes as well.
  final PlayerColor playerColor;

  /// `ONGOING` and values this build does not know read as
  /// [GameResult.unknown].
  final GameResult result;

  final GameDate? playedDate;
  final String? eventName;

  /// The time control in PGN tag syntax ("600+5"), as the server stores it.
  final String? timeControlTag;

  /// Number of half moves. Only known when the moves were fetched
  /// ([GameDetail]); the list does not carry them.
  final int? plyCount;

  final DateTime? createdAt;

  /// True once a finished analysis can be fetched.
  final bool hasAnalysis;

  /// The most recently requested analysis job of this game.
  final JobInfo? latestJob;

  /// [timeControlTag] the way players write it ("10+5").
  TimeControl? get timeControl => TimeControl.fromPgnTag(timeControlTag);

  /// The name to show for the other side.
  String? get displayOpponentName =>
      opponentName ??
      (playerColor == PlayerColor.white ? blackName : whiteName);

  @override
  String toString() =>
      'GameSummary($id, ${playerColor.name}, ${result.pgn}, '
      'analysis: $hasAnalysis, job: ${latestJob?.status.name})';
}

/// A game with its moves.
@immutable
class GameDetail extends GameSummary {
  const GameDetail({
    required super.id,
    required super.playerColor,
    required super.result,
    required super.hasAnalysis,
    required this.pgn,
    super.clientGameId,
    super.whiteName,
    super.blackName,
    super.opponentName,
    super.whiteRating,
    super.blackRating,
    super.playedDate,
    super.eventName,
    super.timeControlTag,
    super.plyCount,
    super.createdAt,
    super.latestJob,
    this.startingFen,
    this.site,
    this.round,
  });

  /// The PGN as it was imported.
  final String pgn;

  /// Null for the standard starting position.
  final String? startingFen;
  final String? site;
  final String? round;
}

/// One page of the library, newest game first.
@immutable
class GamesPage {
  const GamesPage({
    required this.games,
    required this.totalCount,
    required this.hasNextPage,
    this.endCursor,
  });

  final List<GameSummary> games;

  /// All games that match the filter, not only the ones on this page.
  final int totalCount;
  final bool hasNextPage;

  /// Pass it as `after` to get the next page.
  final String? endCursor;
}

/// How a game got into the app.
enum ImportSource { board, pgn, share }

/// What `GamesApi.import` came to.
sealed class ImportOutcome {
  const ImportOutcome();
}

/// Stored. Also the answer when the same `clientGameId` was stored before.
final class GameImported extends ImportOutcome {
  const GameImported(this.game);
  final GameSummary game;
}

/// The server could not replay the moves.
final class ImportPgnInvalid extends ImportOutcome {
  const ImportPgnInvalid({this.moveNumber, this.san});

  /// The first move that is not legal, when the server could tell.
  final int? moveNumber;
  final String? san;
}

final class ImportRateLimited extends ImportOutcome {
  const ImportRateLimited(this.retryAfter);
  final Duration retryAfter;
}

/// Anything else. The submit queue retries when [error] is retryable.
final class ImportFailed extends ImportOutcome {
  const ImportFailed(this.error);
  final ApiError error;
}

/// What `GamesApi.delete` came to.
sealed class DeleteGameOutcome {
  const DeleteGameOutcome();
}

/// Gone; also when the game did not exist any more.
final class GameDeleted extends DeleteGameOutcome {
  const GameDeleted();
}

final class DeleteGameFailed extends DeleteGameOutcome {
  const DeleteGameFailed(this.error);
  final ApiError error;
}
