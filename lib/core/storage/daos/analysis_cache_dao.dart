// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:drift/drift.dart';

import '../app_database.dart';

part 'analysis_cache_dao.g.dart';

/// Analysis documents as raw JSON, one per game.
@DriftAccessor(tables: [CachedAnalyses])
class AnalysisCacheDao extends DatabaseAccessor<AppDatabase>
    with _$AnalysisCacheDaoMixin {
  AnalysisCacheDao(super.attachedDatabase);

  /// Stores or replaces the document of [gameId]. A document cached for
  /// another owner is left alone (see [GamesCacheDao.upsertPage]).
  Future<void> put(
    String ownerSub,
    String gameId, {
    required int schemaVersion,
    required int schemaMinor,
    required String payload,
    DateTime? fetchedAt,
  }) {
    final row = CachedAnalysesCompanion.insert(
      gameId: gameId,
      ownerSub: ownerSub,
      schemaVersion: schemaVersion,
      schemaMinor: schemaMinor,
      payload: payload,
      fetchedAt: fetchedAt ?? attachedDatabase.now(),
    );
    return into(cachedAnalyses).insert(
      row,
      onConflict: DoUpdate(
        (_) => row,
        where: (old) => old.ownerSub.equals(ownerSub),
      ),
    );
  }

  Future<CachedAnalysis?> get(String ownerSub, String gameId) =>
      _byId(ownerSub, gameId).getSingleOrNull();

  Stream<CachedAnalysis?> watch(String ownerSub, String gameId) =>
      _byId(ownerSub, gameId).watchSingleOrNull();

  Future<bool> remove(String ownerSub, String gameId) async {
    final query = delete(cachedAnalyses)
      ..where((t) => t.ownerSub.equals(ownerSub) & t.gameId.equals(gameId));
    return await query.go() > 0;
  }

  SimpleSelectStatement<$CachedAnalysesTable, CachedAnalysis> _byId(
    String ownerSub,
    String gameId,
  ) {
    return select(cachedAnalyses)
      ..where((t) => t.ownerSub.equals(ownerSub) & t.gameId.equals(gameId));
  }
}
