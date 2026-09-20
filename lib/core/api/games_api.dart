// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/api_client.dart';
import 'package:bogner_chess/core/api/api_error.dart';
import 'package:bogner_chess/core/api/generated/operations/fragments.graphql.dart';
import 'package:bogner_chess/core/api/generated/operations/games.graphql.dart';
import 'package:bogner_chess/core/api/generated/schema.graphql.dart';
import 'package:bogner_chess/core/api/mappers/enum_mappers.dart';
import 'package:bogner_chess/core/api/mappers/game_mapper.dart';
import 'package:bogner_chess/core/api/mappers/mutation_error.dart';
import 'package:bogner_chess/core/api/models/game_models.dart';
import 'package:bogner_chess/core/game/game_metadata.dart';

export 'package:bogner_chess/core/api/api_error.dart';
export 'package:bogner_chess/core/api/models/analysis_models.dart'
    show JobInfo, JobStatus;
export 'package:bogner_chess/core/api/models/game_models.dart';

/// The user's games on the server.
class GamesApi {
  GamesApi(this._executor);

  final ApiExecutor _executor;

  /// The server's largest page.
  static const int maxPageSize = 50;

  /// One page of the library, newest game first (games without a date last).
  ///
  /// [search] is a case-insensitive "contains" on opponent, white, black and
  /// event. [playedFrom] and [playedTo] are inclusive and leave out games
  /// without a date. Throws an [ApiError].
  Future<GamesPage> list({
    String? search,
    GameDate? playedFrom,
    GameDate? playedTo,
    int first = 20,
    String? after,
  }) async {
    final trimmed = search?.trim();
    final data = await _executor.query(
      document: documentNodeQueryMyMobileGames,
      operationName: 'MyMobileGames',
      variables: Variables$Query$MyMobileGames(
        search: trimmed == null || trimmed.isEmpty ? null : trimmed,
        playedFrom: playedFrom?.toIso(),
        playedTo: playedTo?.toIso(),
        first: first.clamp(1, maxPageSize),
        after: after,
      ).toJson(),
      parse: Query$MyMobileGames.fromJson,
    );
    final connection = data.myMobileGames;
    return GamesPage(
      games: List.unmodifiable([
        for (final node in connection?.nodes ?? const <Fragment$GameFields>[])
          gameSummaryOf(node),
      ]),
      totalCount: connection?.totalCount ?? 0,
      hasNextPage: connection?.pageInfo.hasNextPage ?? false,
      endCursor: connection?.pageInfo.endCursor,
    );
  }

  /// The game with its moves; null when it does not exist (any more) or
  /// belongs to someone else. Throws an [ApiError].
  Future<GameDetail?> get(String id) async {
    final data = await _executor.query(
      document: documentNodeQueryGameById,
      operationName: 'GameById',
      variables: Variables$Query$GameById(id: id).toJson(),
      parse: Query$GameById.fromJson,
    );
    final game = data.myChessGameById;
    return game == null ? null : gameDetailOf(game);
  }

  /// Stores a game. Idempotent per [clientGameId]: sending the same id again
  /// returns the game that was stored the first time, so the submit queue may
  /// retry after a lost answer.
  ///
  /// [movetext] is the moves in SAN ("1. e4 e5 2. Nf3"), with or without a
  /// result token; the tag pairs come from [metadata]. `metadata.playerColor`
  /// has to be known. Never throws.
  Future<ImportOutcome> import({
    required GameMetadata metadata,
    required String movetext,
    required String clientGameId,
    required ImportSource source,
  }) async {
    final color = metadata.playerColor;
    if (color == null) {
      return const ImportFailed(
        ApiRejected(
          typename: 'InputValidationError',
          messageKey: 'client.player_color_missing',
          propertyName: 'playerColor',
        ),
      );
    }
    final Mutation$ImportMobileGame data;
    try {
      data = await _executor.mutate(
        document: documentNodeMutationImportMobileGame,
        operationName: 'ImportMobileGame',
        variables: Variables$Mutation$ImportMobileGame(
          input: Input$ImportMobileGameInput(
            clientGameId: clientGameId,
            pgn: buildImportPgn(metadata, movetext),
            playerColor: playerColorToWire(color),
            result: gameResultToWire(metadata.result),
            playedDate: metadata.playedDate?.toIso(),
            eventName: metadata.eventName,
            timeControl: metadata.timeControl?.toPgnTag(),
            whitePlayerName: metadata.whiteName,
            blackPlayerName: metadata.blackName,
            opponentName: metadata.opponentName,
            playerElo: metadata.playerRating,
            opponentElo: metadata.opponentRating,
            source: importSourceToWire(source),
          ),
        ).toJson(),
        parse: Mutation$ImportMobileGame.fromJson,
      );
    } on ApiError catch (e) {
      return ImportFailed(e);
    }
    final payload = data.importMobileGame;
    final error = MutationError.firstOf(payload.errors?.map((e) => e.toJson()));
    if (error != null) {
      return switch (error.typename) {
        'PgnInvalidError' => ImportPgnInvalid(
          moveNumber: error.integer('moveNumber'),
          san: error.string('san'),
        ),
        'RateLimitedError' => ImportRateLimited(error.retryAfter),
        _ => ImportFailed(error.toRejected()),
      };
    }
    final game = payload.chessGame;
    return game == null
        ? ImportFailed(emptyPayload('ImportMobileGame'))
        : GameImported(gameSummaryOf(game));
  }

  /// Deletes a game with its analyses. Never throws.
  Future<DeleteGameOutcome> delete(String id) async {
    final Mutation$DeleteChessGame data;
    try {
      data = await _executor.mutate(
        document: documentNodeMutationDeleteChessGame,
        operationName: 'DeleteChessGame',
        variables: Variables$Mutation$DeleteChessGame(
          input: Input$DeleteChessGameInput(chessGameId: id),
        ).toJson(),
        parse: Mutation$DeleteChessGame.fromJson,
      );
    } on ApiError catch (e) {
      return DeleteGameFailed(e);
    }
    final error = MutationError.firstOf(
      data.deleteChessGame.errors?.map((e) => e.toJson()),
    );
    return error == null
        ? const GameDeleted()
        : DeleteGameFailed(error.toRejected());
  }
}
