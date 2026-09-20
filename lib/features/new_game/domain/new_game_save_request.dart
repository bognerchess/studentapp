// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/features/entry/domain/entry_result.dart';
import 'package:bogner_chess/features/import/domain/import_result.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/foundation.dart';

/// The last step of the new-game flow, as it travels to the metadata route
/// (go_router's `extra`): the moves, where they came from, and what the form
/// starts with. Both paths, the board and the import, end here.
@immutable
class NewGameSaveRequest {
  /// The board path. [stored] is the metadata of a draft that was finished
  /// once and reopened; it wins over the hints of the entry screen.
  NewGameSaveRequest.entry(
    EntryResult this.entry, {
    this.defaultPlayerName,
    GameMetadata? stored,
  }) : import = null,
       initial = stored ?? _fromEntry(entry);

  /// The import path: White and Black are facts from the PGN; which of them
  /// the user was is inferred from [accountName] when that is possible.
  NewGameSaveRequest.import(ImportResult this.import, {String? accountName})
    : entry = null,
      defaultPlayerName = accountName,
      initial = _fromImport(import, accountName);

  final EntryResult? entry;
  final ImportResult? import;

  /// What the form shows first.
  final GameMetadata initial;

  /// The signed-in user's name, for "Your name".
  final String? defaultPlayerName;

  bool get isImport => import != null;

  int get plyCount => entry?.plyCount ?? import!.plyCount;

  static GameMetadata _fromEntry(EntryResult entry) => GameMetadata(
    // Somebody who turned the board played Black. An unturned board says
    // nothing: many people enter a game they lost as Black from White's side.
    playerColor: entry.orientation == Side.black ? PlayerColor.black : null,
    result: GameResult.fromPgn(entry.suggestedResult),
  );

  static GameMetadata _fromImport(ImportResult import, String? accountName) {
    final metadata = GameMetadata.fromPgnHeaders(
      import.headers,
      playerName: accountName,
    );
    // The termination marker of the movetext is as good as a Result tag.
    return metadata.result == GameResult.unknown
        ? metadata.copyWith(result: GameResult.fromPgn(import.result))
        : metadata;
  }
}
