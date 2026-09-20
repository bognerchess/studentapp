// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:dartchess/dartchess.dart';

/// The FEN after the last legal move of [pgn]'s main line; null when the PGN
/// cannot be read at all. A move that is not legal ends the replay there:
/// the picture of a game is better than no picture.
String? finalFenOf(String pgn) {
  try {
    final game = PgnGame.parsePgn(pgn);
    var position = PgnGame.startingPosition(game.headers);
    for (final node in game.moves.mainline()) {
      final move = position.parseSan(node.san);
      if (move == null) {
        break;
      }
      position = position.play(move);
    }
    return position.fen;
  } on Object {
    return null;
  }
}
