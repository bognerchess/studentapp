// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:drift/drift.dart';

/// The versioned analysis document of a game, exactly as the server sent it.
@DataClassName('CachedAnalysis')
class CachedAnalyses extends Table {
  TextColumn get gameId => text()();
  TextColumn get ownerSub => text()();
  IntColumn get schemaVersion => integer()();
  IntColumn get schemaMinor => integer()();

  /// The raw JSON document. Parsing and version checks belong to the reader.
  TextColumn get payload => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {gameId};
}
