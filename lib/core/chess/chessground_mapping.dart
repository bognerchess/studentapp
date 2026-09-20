// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// Translation from this app's board vocabulary (`chess_models.dart`) to
/// chessground's. Used by `BoardView` and `BoardThumbnail`, and by their
/// tests; nothing outside `core/chess` needs it.
library;

import 'dart:ui';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';

import 'chess_models.dart';

/// Entry animations are shorter than chessground's 250 ms default: forty
/// moves are typed in a row, and a slow slide makes that feel sticky.
const Duration kBoardAnimationDuration = Duration(milliseconds: 120);

PieceAssets pieceAssetsOf(BoardPieceSet pieceSet) => switch (pieceSet) {
  BoardPieceSet.cburnett => PieceSet.cburnettAssets,
  BoardPieceSet.merida => PieceSet.meridaAssets,
  BoardPieceSet.rhosgfx => PieceSet.rhosgfxAssets,
};

ChessboardColorScheme colorSchemeOf(BoardColors colors) => switch (colors) {
  BoardColors.brown => ChessboardColorScheme.brown,
  BoardColors.blue => ChessboardColorScheme.blue,
  BoardColors.green => ChessboardColorScheme.green,
  BoardColors.ic => ChessboardColorScheme.ic,
};

Color arrowColorOf(BoardArrowStyle style) => switch (style) {
  BoardArrowStyle.best => const Color(0xB3168A3A),
  BoardArrowStyle.alternative => const Color(0xB31E66C8),
  BoardArrowStyle.danger => const Color(0xB3C62828),
  BoardArrowStyle.hint => const Color(0xB3E69F00),
};

Color glyphColorOf(BoardGlyphTone tone) => switch (tone) {
  BoardGlyphTone.positive => const Color(0xFF2E9E4F),
  BoardGlyphTone.neutral => const Color(0xFF5B7FA6),
  BoardGlyphTone.inaccuracy => const Color(0xFFC98A00),
  BoardGlyphTone.mistake => const Color(0xFFE07B00),
  BoardGlyphTone.blunder => const Color(0xFFD13B3B),
};

/// Arrows as chessground shapes. An arrow whose two squares are equal cannot
/// be drawn and is dropped.
Set<Shape> shapesOf(Iterable<BoardArrow> arrows) => {
  for (final arrow in arrows)
    if (arrow.from != arrow.to)
      Arrow(
        color: arrowColorOf(arrow.style),
        orig: arrow.from,
        dest: arrow.to,
        scale: arrow.scale,
      ),
};

Map<Square, Annotation> annotationsOf(Map<Square, BoardGlyph> glyphs) => {
  for (final MapEntry(key: square, value: glyph) in glyphs.entries)
    square: Annotation(symbol: glyph.symbol, color: glyphColorOf(glyph.tone)),
};

/// The chessground snapshot of [position].
GameData gameDataOf(
  Position position, {
  required BoardInteraction interaction,
  Move? lastMove,
}) => GameData(
  fen: position.fen,
  playerSide: switch (interaction) {
    BoardInteraction.entry => PlayerSide.both,
    BoardInteraction.readOnly => PlayerSide.none,
  },
  sideToMove: position.turn,
  validMoves: switch (interaction) {
    BoardInteraction.entry => makeLegalMoves(position),
    BoardInteraction.readOnly => const {},
  },
  lastMove: lastMove,
  kingSquareInCheck: position.isCheck
      ? position.board.kingOf(position.turn)
      : null,
);

ChessboardSettings boardSettingsOf(
  BoardTheme theme, {
  required bool showCoordinates,
  required bool autoQueen,
  required Duration animationDuration,
}) => ChessboardSettings(
  colorScheme: colorSchemeOf(theme.colors),
  pieceAssets: pieceAssetsOf(theme.pieceSet),
  enableCoordinates: showCoordinates,
  animationDuration: animationDuration,
  showLastMove: true,
  showValidMoves: true,
  enablePremoves: false,
  autoQueenPromotion: autoQueen,
  pieceShiftMethod: PieceShiftMethod.either,
);

/// Loads the images of [theme]'s piece set into chessground's cache, so the
/// first board does not appear without pieces for a frame. Safe to call more
/// than once. Widget tests that compare pixels call it inside
/// `tester.runAsync`.
Future<void> precacheBoardTheme(BoardTheme theme, {double? devicePixelRatio}) =>
    ChessgroundImages.instance.loadAll(
      pieceAssetsOf(theme.pieceSet),
      devicePixelRatio: devicePixelRatio,
    );
