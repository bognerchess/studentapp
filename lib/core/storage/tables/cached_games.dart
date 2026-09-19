// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:drift/drift.dart';

import '../converters.dart';

/// Library rows as last seen from the server, for an instant and offline list.
@DataClassName('CachedGame')
@TableIndex(
  name: 'cached_games_owner_played',
  columns: {#ownerSub, #playedDate},
)
class CachedGames extends Table {
  /// Server id of the game.
  TextColumn get gameId => text()();
  TextColumn get ownerSub => text()();

  /// The list item as JSON, owned by the library feature.
  TextColumn get summaryJson => text()();

  /// Calendar date without a time zone, stored as `YYYY-MM-DD`.
  TextColumn get playedDate =>
      text().map(const DateOnlyConverter()).nullable()();
  TextColumn get opponentName => text().nullable()();

  /// `opponentName` in lower case, written by the DAO. SQLite folds case for
  /// ASCII only, which is not enough for "Müller".
  TextColumn get opponentSearch => text().nullable()();

  /// Server-side modification time.
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {gameId};
}
