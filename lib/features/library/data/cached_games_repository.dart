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
      for (final game in page.games) _input(game),
    ], fetchedAt: fetchedAt);
    return page;
  }

  @override
  Future<int> removeStale(String owner, DateTime refreshStartedAt) =>
      _db.gamesCacheDao.removeStale(owner, refreshStartedAt);

  @override
  Future<GameDetail?> fetchDetail(String owner, String gameId) async {
    final detail = await _api.get(gameId);
    if (detail == null) {
      await _db.gamesCacheDao.remove(owner, gameId);
    } else {
      await put(owner, detail);
    }
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
      _input(game),
    ], fetchedAt: existing?.fetchedAt);
  }

  @override
  Future<void> applyJob(String owner, JobInfo job, {bool? hasAnalysis}) async {
    final row = await _db.gamesCacheDao.get(owner, job.gameId);
    final game = row == null ? null : GameSummaryCodec.decode(row.summaryJson);
    if (row == null || game == null) {
      return;
    }
    final updated = gameSummaryWith(
      game,
      latestJob: job,
      hasAnalysis: hasAnalysis ?? game.hasAnalysis,
    );
    await _db.gamesCacheDao.upsertPage(owner, [
      _input(updated),
    ], fetchedAt: row.fetchedAt);
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
