// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:drift/drift.dart';

/// Life cycle of a locally entered game.
///
/// Stored by name (`textEnum`), so the order here may change but a name may
/// not: renaming a value is a schema migration.
enum DraftState {
  /// The user is still entering moves. Autosave only works in this state.
  editing,

  /// Finished and waiting for the submit queue (possibly after a back-off).
  ready,

  /// The submit queue is sending it right now.
  submitting,

  /// The server has the game and, if asked for, the analysis request.
  submitted,

  /// Gave up after too many attempts or a terminal error. Needs a manual retry.
  failed,
}

/// Games entered on the device that the server does not have yet (AC-3).
@DataClassName('Draft')
@TableIndex(
  name: 'drafts_owner_state_updated',
  columns: {#ownerSub, #state, #updatedAt},
)
class Drafts extends Table {
  /// UUID v4, created on the device.
  TextColumn get id => text()();

  /// `sub` claim of the account the draft belongs to.
  TextColumn get ownerSub => text()();
  TextColumn get pgn => text()();

  /// Opaque JSON owned by the entry feature (players, date, result, ...).
  TextColumn get metaJson => text().withDefault(const Constant('{}'))();
  TextColumn get state => textEnum<DraftState>()();

  /// Idempotency key for `createGame`. Never changes once the draft exists.
  TextColumn get clientGameId => text().unique()();
  BoolColumn get wantsAnalysis => boolean().withDefault(const Constant(true))();

  /// Set as soon as `createGame` succeeded, even if the analysis request is
  /// still open, so a retry does not create the game again.
  TextColumn get serverGameId => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  /// Back-off: the submit queue leaves the draft alone until this moment.
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
