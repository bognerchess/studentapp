// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/pgn/pgn_import.dart';

/// How the text got onto the import screen.
enum ImportOrigin {
  /// Typed or pasted.
  text,

  /// Picked with "Open file…".
  file,

  /// Handed over from outside the app: "Open in…" or the share extension.
  external,
}

/// What the import screen hands to whoever opened it: one game, cleaned up and
/// known to be legal. The metadata form and the submit step take it from here.
final class ImportResult {
  const ImportResult({
    required this.movetext,
    required this.headers,
    required this.warnings,
    required this.result,
    required this.plyCount,
    required this.finalFen,
    this.origin = ImportOrigin.text,
  });

  factory ImportResult.fromGame(
    PgnImportedGame game, {
    ImportOrigin origin = ImportOrigin.text,
  }) => ImportResult(
    movetext: game.movetext,
    headers: game.headers,
    warnings: game.warnings,
    result: game.result,
    plyCount: game.plyCount,
    finalFen: game.finalFen,
    origin: origin,
  );

  /// The main line in canonical SAN on one line, "1. e4 e5 2. Nf3": no
  /// comments, no variations, no result.
  final String movetext;

  /// The PGN tag pairs exactly as they were written; empty for a paste
  /// without tags. `GameMetadata.fromPgnHeaders` reads this map.
  final Map<String, String> headers;

  /// What the import left out. The user has seen these on the preview.
  final Set<PgnImportWarning> warnings;

  /// `1-0`, `0-1`, `1/2-1/2` or `*`, from the movetext or else the tags.
  final String result;

  final int plyCount;

  /// FEN after the last move, for a thumbnail.
  final String finalFen;

  /// Where the text came from. Edited text counts as [ImportOrigin.text].
  final ImportOrigin origin;
}
