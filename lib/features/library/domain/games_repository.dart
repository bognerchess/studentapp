// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cached_games_repository.dart';
import 'library_models.dart';

export 'package:bogner_chess/core/api/games_api.dart'
    show
        ApiError,
        ApiNetworkError,
        ApiUnauthenticated,
        DeleteGameFailed,
        DeleteGameOutcome,
        GameDeleted,
        GameDetail,
        GameSummary,
        GamesPage,
        JobInfo,
        JobStatus;

/// The user's games: the server's list with an offline copy in front of it.
///
/// Everything that shows a game reads the copy (so it is there at once and
/// without a connection) and asks this class to bring it up to date. Every
/// method takes the owner (`SignedIn.sub`); rows of one account are never
/// visible to another.
abstract interface class GamesRepository {
  /// The cached games that match [filter], newest first. Emits again
  /// whenever the cache changes.
  Stream<List<GameSummary>> watchGames(String owner, LibraryFilter filter);

  Future<GameSummary?> cached(String owner, String gameId);

  /// Fetches one page from the server and stores it. Pass the same
  /// [fetchedAt] (from [now]) for every page of one refresh. Throws an
  /// [ApiError].
  Future<GamesPage> fetchPage(
    String owner, {
    required DateTime fetchedAt,
    LibraryFilter filter = const LibraryFilter(),
    String? after,
  });

  /// After the last page of an unfiltered refresh: drops the games that
  /// refresh did not see (deleted on another device).
  Future<int> removeStale(String owner, DateTime refreshStartedAt);

  /// The game with its moves, from the server; the cache is updated on the
  /// way. Null when the server does not have it (any more), in which case it
  /// is removed from the cache as well. Throws an [ApiError].
  Future<GameDetail?> fetchDetail(String owner, String gameId);

  /// Deletes the game on the server and, when that worked, its cached copy,
  /// its cached analysis and its jobs.
  Future<DeleteGameOutcome> delete(String owner, String gameId);

  /// Stores a game the app just learned about, e.g. the answer of an upload,
  /// so that it is in the library before the next refresh.
  Future<void> put(String owner, GameSummary game);

  /// Records what the job tracker learned about a game's newest job. A game
  /// that is not cached is left alone.
  Future<void> applyJob(String owner, JobInfo job, {bool? hasAnalysis});

  /// The database clock.
  DateTime now();
}

final gamesRepositoryProvider = Provider<GamesRepository>(
  (ref) => CachedGamesRepository(
    api: ref.watch(gamesApiProvider),
    db: ref.watch(appDatabaseProvider),
  ),
);
