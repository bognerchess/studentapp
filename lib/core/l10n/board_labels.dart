// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/chess/board_view.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:dartchess/dartchess.dart';

/// What a screen reader says on a `BoardView`, in the app's language:
/// `BoardView(semanticsLabels: boardLabelsOf(context.l10n), ...)`.
BoardSemanticsLabels boardLabelsOf(AppLocalizations l10n) {
  return BoardSemanticsLabels(
    square: (square, piece) => piece == null
        ? l10n.boardSquareEmpty(square.name)
        : l10n.boardSquarePiece(square.name, _pieceKey(piece)),
    promoteTo: (role) => l10n.boardPromoteTo(role.name),
    cancelPromotion: l10n.boardCancelPromotion,
  );
}

/// The select key of `boardSquarePiece`: `whitePawn`, `blackKing`, ...
String _pieceKey(Piece piece) {
  final role = piece.role.name;
  return '${piece.color.name}${role[0].toUpperCase()}${role.substring(1)}';
}
