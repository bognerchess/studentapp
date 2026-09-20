// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:dartchess/dartchess.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'board_geometry.dart';

/// The texts a screen reader hears on the board.
///
/// `core/chess` knows nothing about l10n, so the caller injects the texts. The
/// default is English; the app passes a localised instance.
@immutable
class BoardSemanticsLabels {
  const BoardSemanticsLabels({
    required this.square,
    required this.promoteTo,
    required this.cancelPromotion,
  });

  /// English, for tests and as the fallback.
  static const english = BoardSemanticsLabels(
    square: _englishSquare,
    promoteTo: _englishPromoteTo,
    cancelPromotion: 'Cancel promotion',
  );

  /// For example "e4, white pawn" or "e5, empty".
  final String Function(Square square, Piece? piece) square;

  /// For example "Promote to queen". Used while the promotion picker is open.
  final String Function(Role role) promoteTo;

  /// Every square outside the promotion picker while it is open.
  final String cancelPromotion;

  static String _englishSquare(Square square, Piece? piece) => piece == null
      ? '${square.name}, empty'
      : '${square.name}, ${piece.color.name} ${piece.role.name}';

  static String _englishPromoteTo(Role role) => 'Promote to ${role.name}';
}

/// The identifier of a square's semantics node (`accessibilityIdentifier` on
/// iOS), for UI automation: `board-square-e4`.
String boardSquareIdentifier(Square square) => 'board-square-${square.name}';

/// Sixty-four semantics nodes laid over the board, one per square.
///
/// chessground paints the board on a canvas, which is invisible to VoiceOver
/// and to anything else that reads the accessibility tree. This overlay gives
/// every square a label and, when [onActivate] is set, a tap action. It takes
/// no part in hit testing, so touches still reach the board underneath.
class BoardSemanticsOverlay extends StatelessWidget {
  const BoardSemanticsOverlay({
    super.key,
    required this.size,
    required this.orientation,
    required this.board,
    required this.labels,
    this.pendingPromotion,
    this.onActivate,
  });

  final double size;
  final Side orientation;
  final Board board;
  final BoardSemanticsLabels labels;

  /// The pawn move the promotion picker is open for, if it is open.
  final NormalMove? pendingPromotion;

  /// The semantic tap action. Null on a read-only board.
  final void Function(Square square)? onActivate;

  @override
  Widget build(BuildContext context) {
    final promotion = pendingPromotion;
    final choices = promotion == null
        ? const <Square, Role>{}
        : promotionChoices(promotion, orientation);

    String labelOf(Square square) {
      if (promotion == null) {
        return labels.square(square, board.pieceAt(square));
      }
      final role = choices[square];
      return role == null ? labels.cancelPromotion : labels.promoteTo(role);
    }

    // Reading order: left to right, top to bottom, as the user sees it.
    final squares = [...Square.values]
      ..sort((a, b) {
        final cellA = squareCell(a, orientation);
        final cellB = squareCell(b, orientation);
        return cellA.row != cellB.row
            ? cellA.row.compareTo(cellB.row)
            : cellA.column.compareTo(cellB.column);
      });

    final activate = onActivate;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          for (final (index, square) in squares.indexed)
            Positioned.fromRect(
              rect: squareRect(square, orientation, size),
              child: Semantics(
                container: true,
                excludeSemantics: true,
                identifier: boardSquareIdentifier(square),
                label: labelOf(square),
                button: activate != null,
                sortKey: OrdinalSortKey(index.toDouble()),
                onTap: activate == null ? null : () => activate(square),
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }
}
