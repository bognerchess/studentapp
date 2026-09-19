// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:ui';

import 'package:dartchess/dartchess.dart';

/// Column (0 = left) and row (0 = top) of [square] on a board seen from
/// [orientation].
({int column, int row}) squareCell(Square square, Side orientation) =>
    orientation == Side.white
    ? (column: square.file.value, row: 7 - square.rank.value)
    : (column: 7 - square.file.value, row: square.rank.value);

/// The rectangle [square] covers on a board of [boardSize] logical pixels seen
/// from [orientation], relative to the board's top left corner.
Rect squareRect(Square square, Side orientation, double boardSize) {
  final cell = squareCell(square, orientation);
  final squareSize = boardSize / 8;
  return Rect.fromLTWH(
    cell.column * squareSize,
    cell.row * squareSize,
    squareSize,
    squareSize,
  );
}

/// Whether [move] in [position] is a pawn reaching the last rank, which is
/// when the board asks for the promotion piece.
bool isPromotionPawnMove(Position position, NormalMove move) =>
    move.promotion == null &&
    position.board.roleAt(move.from) == Role.pawn &&
    (move.to.rank == Rank.first || move.to.rank == Rank.eighth);

/// Where the board's built-in promotion picker puts its four choices while
/// [move] (a pawn move without a promotion role yet) is pending.
///
/// The picker is a column of four squares in the file of the destination. It
/// starts on the destination square when that square is at the top of the
/// screen (queen first), and otherwise ends on it (queen last, on the
/// destination). Every other square cancels the promotion. This mirrors
/// `PromotionSelector` in the vendored chessground; the promotion widget test
/// fails if the two drift apart.
Map<Square, Role> promotionChoices(NormalMove move, Side orientation) {
  const fromTop = [Role.queen, Role.knight, Role.rook, Role.bishop];
  final destination = squareCell(move.to, orientation);
  final atTop = destination.row == 0;
  final firstRow = atTop ? 0 : 4;
  final roles = atTop ? fromTop : fromTop.reversed.toList(growable: false);
  return {
    for (final square in Square.values)
      if (squareCell(square, orientation) case (:final column, :final row)
          when column == destination.column &&
              row >= firstRow &&
              row < firstRow + 4)
        square: roles[row - firstRow],
  };
}
