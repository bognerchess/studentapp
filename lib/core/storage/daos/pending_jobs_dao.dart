// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:drift/drift.dart';

import '../app_database.dart';

part 'pending_jobs_dao.g.dart';

/// Analysis jobs for the poller.
@DriftAccessor(tables: [PendingJobs])
class PendingJobsDao extends DatabaseAccessor<AppDatabase>
    with _$PendingJobsDaoMixin {
  PendingJobsDao(super.attachedDatabase);

  /// Records a new job or the new [state] of a known one. `created_at` and
  /// `last_polled_at` of a known job are kept. A job id that is recorded for
  /// another owner is left alone.
  Future<void> upsert(
    String ownerSub, {
    required String jobId,
    required String gameId,
    required JobState state,
  }) {
    return into(pendingJobs).insert(
      PendingJobsCompanion.insert(
        jobId: jobId,
        gameId: gameId,
        ownerSub: ownerSub,
        state: state,
        createdAt: attachedDatabase.now(),
      ),
      onConflict: DoUpdate(
        (_) => PendingJobsCompanion(state: Value(state), gameId: Value(gameId)),
        where: (old) => old.ownerSub.equals(ownerSub),
      ),
    );
  }

  /// Jobs that are queued or running, oldest first.
  Stream<List<PendingJob>> watchActive(String ownerSub) =>
      _active(ownerSub).watch();

  Future<List<PendingJob>> getActive(String ownerSub) =>
      _active(ownerSub).get();

  /// The newest job of a game in any state, for the status line on the game.
  Stream<PendingJob?> watchLatestForGame(String ownerSub, String gameId) {
    final query = select(pendingJobs)
      ..where((t) => t.ownerSub.equals(ownerSub) & t.gameId.equals(gameId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.desc(t.rowId),
      ])
      ..limit(1);
    return query.watchSingleOrNull();
  }

  /// Stamps `last_polled_at` on [jobIds].
  Future<void> markPolled(String ownerSub, Iterable<String> jobIds) {
    final query = update(pendingJobs)
      ..where((t) => t.ownerSub.equals(ownerSub) & t.jobId.isIn(jobIds));
    return query.write(
      PendingJobsCompanion(lastPolledAt: Value(attachedDatabase.now())),
    );
  }

  Future<bool> remove(String ownerSub, String jobId) async {
    final query = delete(pendingJobs)
      ..where((t) => t.ownerSub.equals(ownerSub) & t.jobId.equals(jobId));
    return await query.go() > 0;
  }

  /// Drops jobs that are done or failed, once the UI has dealt with them.
  Future<int> removeFinished(String ownerSub) {
    final query = delete(pendingJobs)
      ..where(
        (t) =>
            t.ownerSub.equals(ownerSub) &
            t.state.isInValues(const [JobState.done, JobState.failed]),
      );
    return query.go();
  }

  SimpleSelectStatement<$PendingJobsTable, PendingJob> _active(
    String ownerSub,
  ) {
    return select(pendingJobs)
      ..where(
        (t) =>
            t.ownerSub.equals(ownerSub) &
            t.state.isInValues(const [JobState.queued, JobState.running]),
      )
      ..orderBy([
        (t) => OrderingTerm.asc(t.createdAt),
        (t) => OrderingTerm.asc(t.rowId),
      ]);
  }
}
