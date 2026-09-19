// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'converters.dart';
import 'daos/analysis_cache_dao.dart';
import 'daos/drafts_dao.dart';
import 'daos/event_outbox_dao.dart';
import 'daos/feedback_outbox_dao.dart';
import 'daos/games_cache_dao.dart';
import 'daos/kv_dao.dart';
import 'daos/pending_jobs_dao.dart';
import 'tables/cached_analyses.dart';
import 'tables/cached_games.dart';
import 'tables/drafts.dart';
import 'tables/event_outbox.dart';
import 'tables/feedback_outbox.dart';
import 'tables/kv.dart';
import 'tables/pending_jobs.dart';

export 'converters.dart';
export 'daos/analysis_cache_dao.dart';
export 'daos/drafts_dao.dart';
export 'daos/event_outbox_dao.dart';
export 'daos/feedback_outbox_dao.dart';
export 'daos/games_cache_dao.dart';
export 'daos/kv_dao.dart';
export 'daos/pending_jobs_dao.dart';
export 'tables/cached_analyses.dart';
export 'tables/cached_games.dart';
export 'tables/drafts.dart';
export 'tables/event_outbox.dart';
export 'tables/feedback_outbox.dart';
export 'tables/kv.dart';
export 'tables/pending_jobs.dart';

part 'app_database.g.dart';

/// Returns the current time. Tests pass a fake.
typedef Clock = DateTime Function();

/// The one local database of the app. See docs/storage.md.
///
/// Everything that belongs to an account carries the `sub` claim of that
/// account (`owner_sub`), and every DAO method takes it as its first argument.
/// There is no "current user" in this layer on purpose: a query without an
/// owner cannot be written by accident.
///
/// Timestamps are stored as unix seconds (the drift default). Sub-second
/// precision is dropped, and a [DateTime] read back is in local time. Compare
/// instants, not fields.
@DriftDatabase(
  tables: [
    Drafts,
    CachedGames,
    CachedAnalyses,
    PendingJobs,
    EventOutbox,
    FeedbackOutbox,
    Kv,
  ],
  daos: [
    DraftsDao,
    GamesCacheDao,
    AnalysisCacheDao,
    PendingJobsDao,
    EventOutboxDao,
    FeedbackOutboxDao,
    KvDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the database on [executor]. Tests pass `NativeDatabase.memory()`.
  AppDatabase(super.executor, {Clock? clock}) : now = clock ?? DateTime.now;

  /// Opens the database file of the app in a background isolate.
  ///
  /// The file is `bogner_chess.sqlite` in the application support directory,
  /// which iOS backs up but never shows to the user.
  factory AppDatabase.open({Clock? clock}) => AppDatabase(
    driftDatabase(
      name: fileName,
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    ),
    clock: clock,
  );

  /// File name without the `.sqlite` extension.
  static const fileName = 'bogner_chess';

  /// The clock every DAO uses for `created_at`, `updated_at` and so on.
  final Clock now;

  /// Bump together with a new dump in `drift_schemas/`; see docs/storage.md.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Version 1 is the first one, so there is nothing to upgrade from yet.
    // docs/storage.md describes how to add the first step.
    onUpgrade: (m, from, to) async {
      throw StateError('No migration from schema version $from to $to');
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Removes everything that belongs to [ownerSub]: for sign-out and after
  /// the account was deleted.
  ///
  /// With [keepDrafts] the unsent games stay, for a sign-out that was forced
  /// (expired session) rather than chosen. Analytics events recorded without
  /// an owner stay in any case.
  Future<void> wipeOwner(String ownerSub, {bool keepDrafts = false}) {
    return transaction(() async {
      if (!keepDrafts) {
        await (delete(drafts)..where((t) => t.ownerSub.equals(ownerSub))).go();
      }
      await (delete(
        cachedGames,
      )..where((t) => t.ownerSub.equals(ownerSub))).go();
      await (delete(
        cachedAnalyses,
      )..where((t) => t.ownerSub.equals(ownerSub))).go();
      await (delete(
        pendingJobs,
      )..where((t) => t.ownerSub.equals(ownerSub))).go();
      await (delete(
        eventOutbox,
      )..where((t) => t.ownerSub.equals(ownerSub))).go();
      await (delete(
        feedbackOutbox,
      )..where((t) => t.ownerSub.equals(ownerSub))).go();
      await kvDao.removeAllForOwner(ownerSub);
    });
  }

  /// Empties every table, the key-value flags included.
  Future<void> wipeAll() {
    return transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }
}
