// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/storage/app_database.dart';

import '../domain/game_summary_codec.dart';
import '../domain/games_repository.dart';
import '../domain/library_models.dart';

/// [GamesRepository] on `GamesApi` and the `cached_games` table.
class CachedGamesRepository implements GamesRepository {
  CachedGamesRepository({required this._api, required this._db});

  final GamesApi _api;
  final AppDatabase _db;

  @override
  DateTime now() => _db.now();

  @override
  Stream<List<GameSummary>> watchGames(String owner, LibraryFilter filter) {
    // Dates are filtered in SQL. Text is filtered here, because the server
    // searches both names and the event while the table only indexes the
    // opponent.
    return _db.gamesCacheDao
        .watchGames(
          owner,
          playedFrom: filter.from?.toLocalDateTime(),
          playedTo: filter.to?.toLocalDateTime(),
        )
        .map(
          (rows) => [
            for (final row in rows)
              if (GameSummaryCodec.decode(row.summaryJson) case final game?)
                if (filter.matchesText([
                  game.whiteName,
                  game.blackName,
                  game.opponentName,
                  game.eventName,
                ]))
                  game,
          ],
        );
  }

  @override
  Future<GameSummary?> cached(String owner, String gameId) async {
    final row = await _db.gamesCacheDao.get(owner, gameId);
    return row == null ? null : GameSummaryCodec.decode(row.summaryJson);
  }

  @override
  Future<GamesPage> fetchPage(
    String owner, {
    required DateTime fetchedAt,
    LibraryFilter filter = const LibraryFilter(),
    String? after,
  }) async {
    final page = await _api.list(
      search: filter.hasText ? filter.text.trim() : null,
      playedFrom: filter.from,
      playedTo: filter.to,
      after: after,
    );
    await _db.gamesCacheDao.upsertPage(owner, [
      for (final game in await _keepKnownWorkflows(owner, page.games))
        _input(game),
    ], fetchedAt: fetchedAt);
    return page;
  }

  @override
  Future<int> removeStale(String owner, DateTime refreshStartedAt) =>
      _db.gamesCacheDao.removeStale(owner, refreshStartedAt);

  @override
  Future<GameDetail?> fetchDetail(String owner, String gameId) async {
    final fetched = await _api.get(gameId);
    if (fetched == null) {
      await _db.gamesCacheDao.remove(owner, gameId);
      return null;
    }
    // The fetch carries no pipeline; the caller shows one, so it has to come
    // back out of here and not only go into the cache.
    final row = await _db.gamesCacheDao.get(owner, gameId);
    final cached = row == null
        ? null
        : GameSummaryCodec.decode(row.summaryJson);
    final detail = cached?.workflow == null
        ? fetched
        : fetched.withWorkflow(cached!.workflow);
    await put(owner, detail);
    return detail;
  }

  @override
  Future<DeleteGameOutcome> delete(String owner, String gameId) async {
    final outcome = await _api.delete(gameId);
    if (outcome is GameDeleted) {
      await _db.gamesCacheDao.remove(owner, gameId);
    }
    return outcome;
  }

  @override
  Future<void> put(String owner, GameSummary game) async {
    // Keep the refresh stamp of a known row, so that storing one game does
    // not protect it from the next removeStale.
    final existing = await _db.gamesCacheDao.get(owner, game.id);
    await _db.gamesCacheDao.upsertPage(owner, [
      _input(_withWorkflowOf(game, existing)),
    ], fetchedAt: existing?.fetchedAt);
  }

  /// The server's game list carries no pipeline — `gameAnalysisWorkflow` is
  /// its own query — so a refresh would otherwise wipe what the tracker
  /// wrote and blank every badge until the next poll. One read for the whole
  /// page, and only games that are already cached are touched.
  Future<List<GameSummary>> _keepKnownWorkflows(
    String owner,
    List<GameSummary> games,
  ) async {
    final known = <String, GameWorkflowSummary>{};
    for (final game in games) {
      final row = await _db.gamesCacheDao.get(owner, game.id);
      final cached = row == null
          ? null
          : GameSummaryCodec.decode(row.summaryJson);
      if (cached?.workflow case final workflow?) {
        known[game.id] = workflow;
      }
    }
    if (known.isEmpty) {
      return games;
    }
    return [
      for (final game in games)
        if (known[game.id] case final workflow?)
          gameSummaryWith(
            game,
            hasAnalysis: game.hasAnalysis,
            workflow: workflow,
          )
        else
          game,
    ];
  }

  /// [game] with the pipeline the cached [row] remembers, when the incoming
  /// copy has none.
  GameSummary _withWorkflowOf(GameSummary game, CachedGame? row) {
    if (game.workflow != null || row == null) {
      return game;
    }
    final cached = GameSummaryCodec.decode(row.summaryJson);
    if (cached?.workflow case final workflow?) {
      return gameSummaryWith(
        game,
        hasAnalysis: game.hasAnalysis,
        workflow: workflow,
      );
    }
    return game;
  }

  @override
  Future<void> applyWorkflow(
    String owner,
    String gameId,
    GameWorkflowSummary workflow, {
    bool? hasAnalysis,
  }) async {
    final row = await _db.gamesCacheDao.get(owner, gameId);
    final game = row == null ? null : GameSummaryCodec.decode(row.summaryJson);
    if (game == null) {
      return;
    }
    if (game.workflow == workflow &&
        (hasAnalysis == null || game.hasAnalysis == hasAnalysis)) {
      return;
    }
    final updated = gameSummaryWith(
      game,
      hasAnalysis: hasAnalysis ?? game.hasAnalysis,
      workflow: workflow,
    );
    await _db.gamesCacheDao.upsertPage(owner, [
      _input(updated),
    ], fetchedAt: row!.fetchedAt);
  }

  @override
  Future<void> applyAnalysis(
    String owner,
    String gameId, {
    required bool hasAnalysis,
  }) async {
    final row = await _db.gamesCacheDao.get(owner, gameId);
    final game = row == null ? null : GameSummaryCodec.decode(row.summaryJson);
    if (game == null || game.hasAnalysis == hasAnalysis) {
      return;
    }
    final updated = gameSummaryWith(game, hasAnalysis: hasAnalysis);
    await _db.gamesCacheDao.upsertPage(owner, [
      _input(updated),
    ], fetchedAt: row!.fetchedAt);
  }

  CachedGameInput _input(GameSummary game) => CachedGameInput(
    gameId: game.id,
    summaryJson: GameSummaryCodec.encode(game),
    playedDate: game.playedDate?.toLocalDateTime(),
    opponentName: game.displayOpponentName,
    // The list has no modification time; creation time orders undated games.
    updatedAt: game.createdAt ?? _db.now(),
  );
}
