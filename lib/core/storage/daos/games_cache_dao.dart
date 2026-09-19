// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:drift/drift.dart';

import '../app_database.dart';

part 'games_cache_dao.g.dart';

/// One library row as the API layer hands it to the cache.
class CachedGameInput {
  const CachedGameInput({
    required this.gameId,
    required this.summaryJson,
    required this.updatedAt,
    this.playedDate,
    this.opponentName,
  });

  final String gameId;
  final String summaryJson;

  /// Only year, month and day are used; see [DateOnlyConverter].
  final DateTime? playedDate;
  final String? opponentName;

  /// Server-side modification time.
  final DateTime updatedAt;
}

/// The offline copy of the library list (AC-2).
@DriftAccessor(tables: [CachedGames, CachedAnalyses, PendingJobs])
class GamesCacheDao extends DatabaseAccessor<AppDatabase>
    with _$GamesCacheDaoMixin {
  GamesCacheDao(super.attachedDatabase);

  /// Inserts or replaces one page of the list. Pass the same [fetchedAt] for
  /// every page of one refresh, then call [removeStale] with it.
  ///
  /// A game that is cached for another owner is left alone: game ids are
  /// unique on the server, so that would be a bug upstream, and one account
  /// must never overwrite the data of another.
  Future<void> upsertPage(
    String ownerSub,
    List<CachedGameInput> games, {
    DateTime? fetchedAt,
  }) {
    final fetched = fetchedAt ?? attachedDatabase.now();
    return batch((b) {
      for (final game in games) {
        final row = CachedGamesCompanion.insert(
          gameId: game.gameId,
          ownerSub: ownerSub,
          summaryJson: game.summaryJson,
          playedDate: Value(game.playedDate),
          opponentName: Value(game.opponentName),
          opponentSearch: Value(game.opponentName?.toLowerCase()),
          updatedAt: game.updatedAt,
          fetchedAt: fetched,
        );
        b.insert(
          cachedGames,
          row,
          onConflict: DoUpdate<$CachedGamesTable, CachedGame>(
            (_) => row,
            where: (old) => old.ownerSub.equals(ownerSub),
          ),
        );
      }
    });
  }

  /// Games of [ownerSub], newest first (date played, undated games last, then
  /// server modification time).
  ///
  /// [opponentQuery] is a case-insensitive substring of the opponent's name.
  /// [playedFrom] and [playedTo] are inclusive calendar dates; with either
  /// set, undated games are left out.
  Stream<List<CachedGame>> watchGames(
    String ownerSub, {
    String? opponentQuery,
    DateTime? playedFrom,
    DateTime? playedTo,
    int? limit,
  }) {
    const dates = DateOnlyConverter();
    final query = select(cachedGames)
      ..where((t) => t.ownerSub.equals(ownerSub))
      ..orderBy([
        (t) => OrderingTerm.desc(t.playedDate, nulls: NullsOrder.last),
        (t) => OrderingTerm.desc(t.updatedAt),
        (t) => OrderingTerm.asc(t.gameId),
      ]);
    final needle = opponentQuery?.trim().toLowerCase() ?? '';
    if (needle.isNotEmpty) {
      // The query is text, not a pattern: escape what LIKE would interpret.
      final pattern = needle.replaceAllMapped(
        RegExp(r'[\\%_]'),
        (match) => '\\${match[0]}',
      );
      query.where((t) => t.opponentSearch.like('%$pattern%', escapeChar: r'\'));
    }
    if (playedFrom != null) {
      query.where(
        (t) => t.playedDate.isBiggerOrEqualValue(dates.toSql(playedFrom)),
      );
    }
    if (playedTo != null) {
      query.where(
        (t) => t.playedDate.isSmallerOrEqualValue(dates.toSql(playedTo)),
      );
    }
    if (limit != null) {
      query.limit(limit);
    }
    return query.watch();
  }

  Future<CachedGame?> get(String ownerSub, String gameId) {
    final query = select(cachedGames)
      ..where((t) => t.ownerSub.equals(ownerSub) & t.gameId.equals(gameId));
    return query.getSingleOrNull();
  }

  /// Removes the game together with its cached analysis and its jobs.
  Future<bool> remove(String ownerSub, String gameId) {
    return transaction(() async {
      final games = delete(cachedGames)
        ..where((t) => t.ownerSub.equals(ownerSub) & t.gameId.equals(gameId));
      final analyses = delete(cachedAnalyses)
        ..where((t) => t.ownerSub.equals(ownerSub) & t.gameId.equals(gameId));
      final jobs = delete(pendingJobs)
        ..where((t) => t.ownerSub.equals(ownerSub) & t.gameId.equals(gameId));
      final removed = await games.go();
      await analyses.go();
      await jobs.go();
      return removed > 0;
    });
  }

  /// Removes games that a complete refresh did not see any more (deleted on
  /// another device): everything fetched before [refreshStartedAt]. Returns
  /// the number of games removed. Their cached analyses go too.
  Future<int> removeStale(String ownerSub, DateTime refreshStartedAt) {
    return transaction(() async {
      final stale = selectOnly(cachedGames)
        ..addColumns([cachedGames.gameId])
        ..where(
          cachedGames.ownerSub.equals(ownerSub) &
              cachedGames.fetchedAt.isSmallerThanValue(refreshStartedAt),
        );
      final analyses = delete(cachedAnalyses)
        ..where((t) => t.ownerSub.equals(ownerSub) & t.gameId.isInQuery(stale));
      await analyses.go();
      final games = delete(cachedGames)
        ..where(
          (t) =>
              t.ownerSub.equals(ownerSub) &
              t.fetchedAt.isSmallerThanValue(refreshStartedAt),
        );
      return games.go();
    });
  }
}
