// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analysis/analysis_board_mapping.dart';
import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/chess/chess_models.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import 'review_state.dart';

/// What `BoardView` shows for a [ReviewState]. Everything in here comes from
/// objects the parser already built: no FEN is parsed while stepping.
@immutable
class ReviewBoard {
  const ReviewBoard({
    required this.position,
    required this.orientation,
    this.lastMove,
    this.arrows = const [],
    this.glyphs = const {},
  });

  /// The main-line position (or the position inside the open line).
  ///
  /// On the main line the board always shows the position *after* the move
  /// under discussion, with everything the coach says about it on that one
  /// board: the verdict as a glyph on the moved piece, the better move as a
  /// green arrow, and what the opponent now threatens in red. One board and
  /// no "before / after" mode to get lost in.
  factory ReviewBoard.of(AnalysisDocument document, ReviewState state) {
    final orientation = _orientation(document.perspective, state.flipped);
    final line = state.line;
    final node = document.nodeAt(line?.ply ?? state.ply);
    final variation = line == null
        ? null
        : node?.variationById(line.variationId);
    if (line != null && node != null && variation != null) {
      return _inLine(document, node, variation, line.index, orientation);
    }

    if (node == null) {
      return ReviewBoard(
        position: document.startPosition,
        orientation: orientation,
      );
    }

    final comment = document.commentsById[state.selectedCommentId];
    final arrows = <BoardArrow>{
      ...boardArrowsFor(
        node,
        showBest: state.showBestArrow,
        showPlayed: state.showPlayedArrow,
      ),
      if (comment != null && comment.ply == node.ply)
        for (final arrow in boardArrowsForComment(comment))
          if (_wanted(arrow, state)) arrow,
    };
    return ReviewBoard(
      position: node.positionAfter,
      orientation: orientation,
      lastMove: node.move,
      arrows: List.unmodifiable(arrows),
      glyphs: document.boardGlyphsFor(node),
    );
  }

  /// Board and moves only: the analysis is of a newer major version.
  factory ReviewBoard.ofPartial(PartialAnalysis partial, ReviewState state) {
    final ply = state.ply.clamp(0, partial.moves.length);
    return ReviewBoard(
      position: partial.positionAt(ply),
      orientation: state.flipped ? Side.black : Side.white,
      lastMove: ply == 0 ? null : partial.moves[ply - 1].move,
    );
  }

  final Position position;
  final Side orientation;
  final Move? lastMove;
  final List<BoardArrow> arrows;
  final Map<Square, BoardGlyph> glyphs;

  static ReviewBoard _inLine(
    AnalysisDocument document,
    AnalysisNode node,
    Variation variation,
    int index,
    Side orientation,
  ) {
    final moves = variation.moves;
    final at = index.clamp(0, moves.length);
    // The move that led to the line's start position: the played move for a
    // refutation (it starts after it), the move before for the others.
    final startsAfterMove =
        variation.startPosition.fen == node.positionAfter.fen;
    final Move? before = startsAfterMove
        ? node.move
        : document.nodeAt(node.ply - 1)?.move;

    final next = at < moves.length ? moves[at].move : null;
    // The side the line is about moves first in it; its moves get the colour
    // of the line, the replies a thinner neutral arrow.
    final ownMove = at.isEven;
    final nextArrow = next == null
        ? null
        : BoardArrow.ofMove(
            next,
            style: ownMove ? lineArrowStyle(variation.kind) : _replyStyle,
            scale: ownMove ? 1.0 : 0.7,
          );
    return ReviewBoard(
      position: at == 0 ? variation.startPosition : moves[at - 1].positionAfter,
      orientation: orientation,
      lastMove: at == 0 ? before : moves[at - 1].move,
      arrows: [?nextArrow],
    );
  }

  static const BoardArrowStyle _replyStyle = BoardArrowStyle.hint;

  static bool _wanted(BoardArrow arrow, ReviewState state) =>
      switch (arrow.style) {
        BoardArrowStyle.best => state.showBestArrow,
        BoardArrowStyle.hint => state.showPlayedArrow,
        BoardArrowStyle.danger || BoardArrowStyle.alternative => true,
      };

  static Side _orientation(AnalysisPerspective perspective, bool flipped) {
    final base = perspective == AnalysisPerspective.black
        ? Side.black
        : Side.white;
    return flipped ? base.opposite : base;
  }
}

/// The arrow colour of a line: green for the best line, blue for an
/// alternative, red for the punishment of the played move.
BoardArrowStyle lineArrowStyle(VariationKind kind) => switch (kind) {
  VariationKind.bestLine => BoardArrowStyle.best,
  VariationKind.alternative => BoardArrowStyle.alternative,
  VariationKind.refutation => BoardArrowStyle.danger,
  VariationKind.unknown => BoardArrowStyle.hint,
};
