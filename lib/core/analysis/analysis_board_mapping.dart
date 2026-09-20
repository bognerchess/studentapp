// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// From analysis terms to what `BoardView` draws.
///
/// This is the only file in `core/analysis` that touches `core/chess` (whose
/// models import Flutter); everything else here is pure Dart.
///
/// Arrow colours:
///
/// | analysis | board style | colour | why |
/// | --- | --- | --- | --- |
/// | best | `best` | green | the move to learn |
/// | played | `hint` | amber | a neutral pointer at the move under discussion; its verdict is the glyph |
/// | threat | `danger` | red | what the opponent is about to do |
///
/// Red is kept for threats, so a criticised move and the threat it allows
/// never have the same colour. Glyphs: `!` positive, `?!` inaccuracy, `?`
/// mistake, `??` blunder, with the tones `BoardView` already knows.
library;

import 'package:dartchess/dartchess.dart';

import '../chess/chess_models.dart';
import 'analysis_document.dart';
import 'analysis_view.dart';

extension AnalysisGlyphBoardMapping on AnalysisGlyph {
  BoardGlyph toBoardGlyph() => switch (this) {
    AnalysisGlyph.good => BoardGlyph.good,
    AnalysisGlyph.inaccuracy => BoardGlyph.inaccuracy,
    AnalysisGlyph.mistake => BoardGlyph.mistake,
    AnalysisGlyph.blunder => BoardGlyph.blunder,
  };
}

extension AnalysisArrowBoardMapping on AnalysisArrow {
  BoardArrow toBoardArrow() => BoardArrow(
    from: from,
    to: to,
    style: switch (kind) {
      AnalysisArrowKind.best => BoardArrowStyle.best,
      AnalysisArrowKind.played => BoardArrowStyle.hint,
      AnalysisArrowKind.threat => BoardArrowStyle.danger,
    },
  );
}

/// [arrowsFor] as `BoardView.arrows`. Draw them on `node.positionBefore`.
List<BoardArrow> boardArrowsFor(
  AnalysisNode node, {
  bool showBest = true,
  bool showPlayed = true,
}) => [
  for (final arrow in arrowsFor(
    node,
    showBest: showBest,
    showPlayed: showPlayed,
  ))
    arrow.toBoardArrow(),
];

/// [arrowsForComment] as `BoardView.arrows`. Pass the [board] that is on
/// screen, so that a threat is not drawn on the position before the move.
List<BoardArrow> boardArrowsForComment(
  CoachComment comment, {
  ArrowBoard? board,
}) => [
  for (final arrow in arrowsForComment(comment, board: board))
    arrow.toBoardArrow(),
];

extension AnalysisDocumentBoardMapping on AnalysisDocument {
  /// The glyph of [node] for `BoardView`, or null.
  BoardGlyph? boardGlyphFor(AnalysisNode node) =>
      glyphFor(node)?.toBoardGlyph();

  /// `BoardView.glyphs` for the position after [node]: its glyph on the
  /// destination square of the move, or an empty map.
  Map<Square, BoardGlyph> boardGlyphsFor(AnalysisNode node) => {
    _destinationOf(node): ?boardGlyphFor(node),
  };
}

/// Where the moved piece ends up. A castling move may arrive as king-takes-rook
/// (`e1h1`); the glyph belongs on the king's square.
Square _destinationOf(AnalysisNode node) {
  final king = node.positionAfter.board.kingOf(node.side);
  final movedKing =
      node.positionBefore.board.kingOf(node.side) == node.move.from;
  return movedKing && king != null ? king : node.move.to;
}
