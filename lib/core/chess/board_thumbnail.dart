// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/widgets.dart';

import 'chess_models.dart';
import 'chessground_mapping.dart';

/// A small board nobody can move on, for rows of the game library.
///
/// It is chessground's `StaticChessboard`, which is built for long scrolling
/// lists. It takes a FEN rather than a `Position`, because a list row has the
/// FEN of the final position at hand and should not have to replay a game to
/// draw it. To assistive technology it is one image with [semanticLabel], or
/// nothing at all when the row already says what it is.
class BoardThumbnail extends StatelessWidget {
  const BoardThumbnail({
    super.key,
    required this.fen,
    required this.size,
    this.orientation = Side.white,
    this.lastMove,
    this.theme = const BoardTheme(),
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
    this.semanticLabel,
  });

  /// Any FEN; only the piece placement is read.
  final String fen;

  /// Edge length in logical pixels.
  final double size;

  final Side orientation;
  final Move? lastMove;
  final BoardTheme theme;
  final BorderRadius borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final label = semanticLabel;
    final board = ExcludeSemantics(
      child: StaticChessboard(
        size: size,
        orientation: orientation,
        fen: fen,
        lastMove: lastMove,
        settings: StaticChessboardSettings(
          colorScheme: colorSchemeOf(theme.colors),
          pieceAssets: pieceAssetsOf(theme.pieceSet),
          borderRadius: borderRadius,
          enableCoordinates: false,
          animationDuration: Duration.zero,
        ),
      ),
    );
    return label == null
        ? board
        : Semantics(container: true, image: true, label: label, child: board);
  }
}
