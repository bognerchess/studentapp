// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:drift/drift.dart';

import '../app_database.dart';

part 'pending_workflows_dao.g.dart';

/// The games whose staged analysis the tracker watches.
@DriftAccessor(tables: [PendingWorkflows])
class PendingWorkflowsDao extends DatabaseAccessor<AppDatabase>
    with _$PendingWorkflowsDaoMixin {
  PendingWorkflowsDao(super.attachedDatabase);

  /// Records a game to watch, or moves a known one on.
  ///
  /// `created_at` and `last_polled_at` of a known game are kept, so that
  /// asking for the coach after the engine chain finished does not look like
  /// a new workflow. A game recorded for another owner is left alone.
  Future<void> upsert(
    String ownerSub, {
    required String gameId,
    required String targetStage,
    WorkflowState state = WorkflowState.running,
  }) {
    return into(pendingWorkflows).insert(
      PendingWorkflowsCompanion.insert(
        gameId: gameId,
        ownerSub: ownerSub,
        targetStage: targetStage,
        state: state,
        createdAt: attachedDatabase.now(),
      ),
      onConflict: DoUpdate(
        (_) => PendingWorkflowsCompanion(
          targetStage: Value(targetStage),
          state: Value(state),
        ),
        where: (old) => old.ownerSub.equals(ownerSub),
      ),
    );
  }

  /// The games the tracker still has to ask about, oldest first.
  Stream<List<PendingWorkflow>> watchActive(String ownerSub) =>
      _active(ownerSub).watch();

  Future<List<PendingWorkflow>> getActive(String ownerSub) =>
      _active(ownerSub).get();

  Future<PendingWorkflow?> get(String ownerSub, String gameId) =>
      _byId(ownerSub, gameId).getSingleOrNull();

  Stream<PendingWorkflow?> watch(String ownerSub, String gameId) =>
      _byId(ownerSub, gameId).watchSingleOrNull();

  /// Moves a game to [state] without touching what it is aiming at. Returns
  /// whether there was a row to move.
  Future<bool> setState(
    String ownerSub,
    String gameId,
    WorkflowState state,
  ) async {
    final query = update(pendingWorkflows)
      ..where((t) => t.ownerSub.equals(ownerSub) & t.gameId.equals(gameId));
    return await query.write(PendingWorkflowsCompanion(state: Value(state))) >
        0;
  }

  /// Stamps `last_polled_at` on [gameIds].
  Future<void> markPolled(String ownerSub, Iterable<String> gameIds) {
    final query = update(pendingWorkflows)
      ..where((t) => t.ownerSub.equals(ownerSub) & t.gameId.isIn(gameIds));
    return query.write(
      PendingWorkflowsCompanion(lastPolledAt: Value(attachedDatabase.now())),
    );
  }

  Future<bool> remove(String ownerSub, String gameId) async {
    final query = delete(pendingWorkflows)
      ..where((t) => t.ownerSub.equals(ownerSub) & t.gameId.equals(gameId));
    return await query.go() > 0;
  }

  /// Drops the games that are done or failed, once the UI has dealt with
  /// them.
  Future<int> removeFinished(String ownerSub) {
    final query = delete(pendingWorkflows)
      ..where(
        (t) =>
            t.ownerSub.equals(ownerSub) &
            t.state.isInValues(const [
              WorkflowState.done,
              WorkflowState.failed,
            ]),
      );
    return query.go();
  }

  SimpleSelectStatement<$PendingWorkflowsTable, PendingWorkflow> _active(
    String ownerSub,
  ) {
    return select(pendingWorkflows)
      ..where(
        (t) =>
            t.ownerSub.equals(ownerSub) &
            t.state.isInValues(const [WorkflowState.running]),
      )
      ..orderBy([
        (t) => OrderingTerm.asc(t.createdAt),
        (t) => OrderingTerm.asc(t.rowId),
      ]);
  }

  SimpleSelectStatement<$PendingWorkflowsTable, PendingWorkflow> _byId(
    String ownerSub,
    String gameId,
  ) {
    return select(pendingWorkflows)
      ..where((t) => t.ownerSub.equals(ownerSub) & t.gameId.equals(gameId));
  }
}
