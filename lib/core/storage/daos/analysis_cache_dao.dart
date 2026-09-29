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

  /// Stores or replaces the document of [gameId], whatever is there.
  ///
  /// The coach's document is the best the app can have, so this one always
  /// wins: over an engine assembly, and over an older coach document. A
  /// document cached for another owner is left alone (see
  /// [GamesCacheDao.upsertPage]).
  Future<void> putCoach(
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
      source: const Value(AnalysisSource.coach),
      stage: const Value(null),
      stageRunIds: const Value(null),
    );
    return into(cachedAnalyses).insert(
      row,
      onConflict: DoUpdate(
        (_) => row,
        where: (old) => old.ownerSub.equals(ownerSub),
      ),
    );
  }

  /// Stores a document assembled from engine stage artifacts.
  ///
  /// **Never writes over a coach document.** The engine assembly has no
  /// comments and no lessons, so replacing a finished analysis with it would
  /// take text away from the user; the tracker instead calls [clearCoach]
  /// when the server says the coaching stage went stale.
  ///
  /// Returns whether the row was written.
  Future<bool> putEngine(
    String ownerSub,
    String gameId, {
    required int schemaVersion,
    required int schemaMinor,
    required String payload,
    required String stage,
    required String stageRunIds,
    DateTime? fetchedAt,
  }) async {
    final row = CachedAnalysesCompanion.insert(
      gameId: gameId,
      ownerSub: ownerSub,
      schemaVersion: schemaVersion,
      schemaMinor: schemaMinor,
      payload: payload,
      fetchedAt: fetchedAt ?? attachedDatabase.now(),
      source: const Value(AnalysisSource.engine),
      stage: Value(stage),
      stageRunIds: Value(stageRunIds),
    );
    return transaction(() async {
      await into(cachedAnalyses).insert(
        row,
        onConflict: DoUpdate(
          (_) => row,
          where: (old) =>
              old.ownerSub.equals(ownerSub) &
              old.source.equalsValue(AnalysisSource.engine),
        ),
      );
      // The guarded upsert is silent about what it did, and both things it
      // refuses to touch look the same from here: a coach document, and a row
      // that belongs to another owner.
      final stored = await _byId(ownerSub, gameId).getSingleOrNull();
      return stored != null && stored.source == AnalysisSource.engine;
    });
  }

  /// Drops the row of [gameId] when it holds a coach document, so that the
  /// engine assembly takes over again. Used when the coaching stage goes
  /// stale: its text was written about moves that have since changed.
  ///
  /// Returns whether a row was removed.
  Future<bool> clearCoach(String ownerSub, String gameId) async {
    final query = delete(cachedAnalyses)
      ..where(
        (t) =>
            t.ownerSub.equals(ownerSub) &
            t.gameId.equals(gameId) &
            t.source.equalsValue(AnalysisSource.coach),
      );
    return await query.go() > 0;
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
