// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/chess/chess_models.dart';
import 'package:bogner_chess/features/review/domain/review_board.dart';
import 'package:bogner_chess/features/review/domain/review_state.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_review.dart';

BoardArrow _arrow(String uci, BoardArrowStyle style, {double scale = 1}) =>
    BoardArrow(
      from: Square.fromName(uci.substring(0, 2)),
      to: Square.fromName(uci.substring(2, 4)),
      style: style,
      scale: scale,
    );

void main() {
  final document = (parseFixture(kFortyMoveGame) as AnalysisSupported).document;
  final commentAt6 = document.nodeAt(6)!.commentIds.single;

  group('main line', () {
    test('start position: no move, no arrows, the player at the bottom', () {
      final board = ReviewBoard.of(document, const ReviewState());
      expect(board.position.fen, document.startPosition.fen);
      expect(board.lastMove, isNull);
      expect(board.arrows, isEmpty);
      expect(board.glyphs, isEmpty);
      // The analysed player had Black.
      expect(board.orientation, Side.black);
      expect(
        ReviewBoard.of(document, const ReviewState(flipped: true)).orientation,
        Side.white,
      );
    });

    test('a commented move: position after it, glyph, best and threat', () {
      final board = ReviewBoard.of(
        document,
        ReviewState(ply: 6, selectedCommentId: commentAt6),
      );
      final node = document.nodeAt(6)!;
      expect(board.position, same(node.positionAfter));
      expect(board.lastMove, node.move);
      expect(board.glyphs, {Square.b6: BoardGlyph.mistake});
      // Best once (the node and the comment agree), the threat, no played.
      expect(board.arrows, [
        _arrow('d7d5', BoardArrowStyle.best),
        _arrow('d2d4', BoardArrowStyle.danger),
      ]);
    });

    test('the toggles', () {
      final all = ReviewBoard.of(
        document,
        ReviewState(
          ply: 6,
          selectedCommentId: commentAt6,
          showPlayedArrow: true,
        ),
      );
      expect(all.arrows, [
        _arrow('d7d5', BoardArrowStyle.best),
        _arrow('b7b6', BoardArrowStyle.hint),
        _arrow('d2d4', BoardArrowStyle.danger),
      ]);

      final none = ReviewBoard.of(
        document,
        ReviewState(
          ply: 6,
          selectedCommentId: commentAt6,
          showBestArrow: false,
        ),
      );
      expect(none.arrows, [_arrow('d2d4', BoardArrowStyle.danger)]);
    });

    test('without a selected comment only the engine arrow', () {
      final board = ReviewBoard.of(document, const ReviewState(ply: 6));
      expect(board.arrows, [_arrow('d7d5', BoardArrowStyle.best)]);
    });

    test('a comment of another ply adds nothing', () {
      final board = ReviewBoard.of(
        document,
        ReviewState(ply: 7, selectedCommentId: commentAt6),
      );
      expect(
        board.arrows.where((a) => a.style == BoardArrowStyle.danger),
        isEmpty,
      );
    });

    test('never parses a FEN: positions are the parser\'s objects', () {
      for (var ply = 1; ply <= document.plyCount; ply++) {
        expect(
          ReviewBoard.of(document, ReviewState(ply: ply)).position,
          same(document.nodeAt(ply)!.positionAfter),
        );
      }
    });
  });

  group('inside a line', () {
    ReviewBoard at(String id, int index) => ReviewBoard.of(
      document,
      ReviewState(
        ply: 6,
        selectedCommentId: commentAt6,
        line: LineCursor(ply: 6, variationId: id, index: index),
      ),
    );

    test('best line: starts before the played move', () {
      final node = document.nodeAt(6)!;
      final start = at('v6-best', 0);
      expect(start.position.fen, node.positionBefore.fen);
      expect(start.lastMove, document.nodeAt(5)!.move);
      expect(start.arrows, [_arrow('d7d5', BoardArrowStyle.best)]);
      expect(start.glyphs, isEmpty);

      final one = at('v6-best', 1);
      expect(one.position.board.pieceAt(Square.d5)?.role, Role.pawn);
      expect(one.lastMove, NormalMove.fromUci('d7d5'));
      // The reply is a thinner, neutral arrow.
      expect(one.arrows, [_arrow('e4d5', BoardArrowStyle.hint, scale: 0.7)]);

      final two = at('v6-best', 2);
      expect(two.arrows, [_arrow('d8d5', BoardArrowStyle.best)]);
    });

    test('refutation: starts after the played move, in red', () {
      final node = document.nodeAt(6)!;
      final start = at('v6-refutation', 0);
      expect(start.position.fen, node.positionAfter.fen);
      expect(start.lastMove, node.move);
      expect(start.arrows, [_arrow('d2d4', BoardArrowStyle.danger)]);
    });

    test('alternative in blue, and no arrow after the last move', () {
      expect(at('v6-alt1', 0).arrows, [
        _arrow('b8c6', BoardArrowStyle.alternative),
      ]);
      final variation = document.nodeAt(6)!.variationById('v6-alt1')!;
      final end = at('v6-alt1', variation.moves.length);
      expect(end.arrows, isEmpty);
      expect(end.position, same(variation.moves.last.positionAfter));
      // Out of range is clamped.
      expect(at('v6-alt1', 99).position, same(end.position));
    });

    test('a line that no longer exists falls back to the main line', () {
      final board = at('gone', 1);
      expect(board.position, same(document.nodeAt(6)!.positionAfter));
    });
  });

  test('newer major: moves only, White at the bottom', () {
    final partial = (parseFixture(kNewerMajor) as AnalysisNewerMajor).partial;
    final start = ReviewBoard.ofPartial(partial, const ReviewState());
    expect(start.position.fen, partial.startPosition.fen);
    expect(start.lastMove, isNull);
    expect(start.orientation, Side.white);

    final third = ReviewBoard.ofPartial(partial, const ReviewState(ply: 3));
    expect(third.position, same(partial.moves[2].positionAfter));
    expect(third.lastMove, partial.moves[2].move);
    expect(third.arrows, isEmpty);
    expect(
      ReviewBoard.ofPartial(partial, const ReviewState(ply: 999)).position,
      same(partial.moves.last.positionAfter),
    );
  });
}
