// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:drift/drift.dart';

/// Where a staged analysis of one game stands, as far as this device knows.
/// Stored by name; see [DraftState] for the rule.
enum WorkflowState {
  /// The chain is under way: the tracker polls this game and starts the next
  /// engine stage when the one before it is stored.
  running,

  /// The target stage is stored. Nothing left to do.
  done,

  /// A stage up to the target failed, or the server refused to start one.
  /// The user has to ask for a retry.
  failed;

  /// Whether the tracker still has to ask about this game.
  bool get isActive => this == running;
}

/// The games whose analysis this device started and has not seen finish.
///
/// There is no "my running workflows" field on the server — the pipeline is
/// queried per game — so the app has to remember which games to ask about.
/// The row is written **before** the first stage is started, so an app that
/// is killed between the two still resumes the chain on the next start.
///
/// One row per game, not per run: a game has one pipeline, and re-running a
/// stage does not start a second one.
@DataClassName('PendingWorkflow')
@TableIndex(name: 'pending_workflows_owner_state', columns: {#ownerSub, #state})
class PendingWorkflows extends Table {
  TextColumn get gameId => text()();
  TextColumn get ownerSub => text()();

  /// How far the chain should run. The three engine stages are free, so this
  /// is normally the deep evaluation; a coach request sets it to coaching.
  /// The wire name of `AnalysisStage`, because the storage layer does not
  /// know that enum (it lives in `lib/core/api/models/`).
  TextColumn get targetStage => text()();

  TextColumn get state => textEnum<WorkflowState>()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastPolledAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {gameId};
}
