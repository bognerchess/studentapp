// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:drift/drift.dart';

/// Where a cached analysis document came from.
///
/// The staged pipeline lets the app build a readable document out of the
/// engine artifacts long before the coach has written anything, so a cached
/// row is one of two quite different things. Stored by name; see [DraftState]
/// for the rule.
enum AnalysisSource {
  /// The finished document the server assembled, with the coach's comments
  /// and lessons. Always wins over an engine assembly.
  coach,

  /// Assembled on the device from the engine stage artifacts: evals, key
  /// positions, variations and accuracy, but no coach text.
  engine,
}

/// The versioned analysis document of a game.
///
/// Either exactly as the server sent it ([AnalysisSource.coach]) or assembled
/// on the device from the engine stage artifacts ([AnalysisSource.engine]);
/// both are the same document format, so every reader is the same.
@DataClassName('CachedAnalysis')
class CachedAnalyses extends Table {
  TextColumn get gameId => text()();
  TextColumn get ownerSub => text()();
  IntColumn get schemaVersion => integer()();
  IntColumn get schemaMinor => integer()();

  /// The raw JSON document. Parsing and version checks belong to the reader.
  TextColumn get payload => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  /// Rows written before schema 2 are the server's documents, so the default
  /// is the one that makes an old row mean what it always meant.
  TextColumn get source =>
      textEnum<AnalysisSource>().withDefault(const Constant('coach'))();

  /// The furthest stage the payload was built from, as the wire name of
  /// `AnalysisStage`; null on a coach document, where the stage is implied.
  TextColumn get stage => text().nullable()();

  /// Which stage run each part of an engine assembly came from, as a JSON
  /// object of stage name to run id. This is what stops the tracker from
  /// fetching an artifact it has already read: an id that is still in here
  /// has been stored. Null or `{}` on a coach document.
  TextColumn get stageRunIds => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {gameId};
}
