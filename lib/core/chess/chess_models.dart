// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// Board vocabulary for the rest of the app.
///
/// Features describe what they want to see on the board with these types and
/// never import `chessground`. Squares, moves, pieces and positions are the
/// `dartchess` types, which every layer may use.
library;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

/// How the user may interact with a `BoardView`.
enum BoardInteraction {
  /// Move entry: the side to move can be moved, whichever colour it is, by
  /// tapping two squares or by dragging. Legal destinations are shown.
  /// Premoves are off.
  entry,

  /// Nothing can be moved. Position changes are still animated.
  readOnly,
}

/// The piece sets this app is allowed to bundle. The list mirrors the NOTICE
/// file and `tool/asset_allowlist.txt`; adding a value means adding both.
enum BoardPieceSet {
  /// Colin M. L. Burnett, GPLv2+.
  cburnett,

  /// Armando Hernandez Marroquin, GPLv2+.
  merida,

  /// RhosGFX, CC0 1.0.
  rhosgfx,
}

/// Board colours. All of them are colour pairs defined in code; the app ships
/// no board images.
enum BoardColors { brown, blue, green, ic }

/// A piece set together with board colours.
@immutable
class BoardTheme {
  const BoardTheme({
    this.pieceSet = BoardPieceSet.cburnett,
    this.colors = BoardColors.brown,
  });

  final BoardPieceSet pieceSet;
  final BoardColors colors;

  /// Every combination, piece sets first: for a theme picker.
  static final List<BoardTheme> all = [
    for (final pieceSet in BoardPieceSet.values)
      for (final colors in BoardColors.values)
        BoardTheme(pieceSet: pieceSet, colors: colors),
  ];

  BoardTheme copyWith({BoardPieceSet? pieceSet, BoardColors? colors}) =>
      BoardTheme(
        pieceSet: pieceSet ?? this.pieceSet,
        colors: colors ?? this.colors,
      );

  @override
  bool operator ==(Object other) =>
      other is BoardTheme &&
      other.pieceSet == pieceSet &&
      other.colors == colors;

  @override
  int get hashCode => Object.hash(pieceSet, colors);

  @override
  String toString() => 'BoardTheme(${pieceSet.name}, ${colors.name})';
}

/// What an arrow means. `BoardView` picks the colour.
enum BoardArrowStyle {
  /// The engine's best move or best line. Green.
  best,

  /// A second candidate, for example the engine alternative. Blue.
  alternative,

  /// A move that is being criticised, or a threat. Red.
  danger,

  /// A neutral pointer, for example a hint. Amber.
  hint,
}

/// An arrow from one square to another.
@immutable
class BoardArrow {
  const BoardArrow({
    required this.from,
    required this.to,
    this.style = BoardArrowStyle.best,
    this.scale = 1.0,
  }) : assert(scale > 0.0 && scale <= 1.0, 'scale must be in (0, 1]');

  /// The arrow for [move]. A drop has no origin, so it has no arrow.
  static BoardArrow? ofMove(
    Move move, {
    BoardArrowStyle style = BoardArrowStyle.best,
    double scale = 1.0,
  }) => switch (move) {
    NormalMove(:final from, :final to) when from != to => BoardArrow(
      from: from,
      to: to,
      style: style,
      scale: scale,
    ),
    _ => null,
  };

  final Square from;
  final Square to;
  final BoardArrowStyle style;

  /// Width relative to the default (a quarter of a square). Use a value below
  /// 1 for the later moves of a line.
  final double scale;

  @override
  bool operator ==(Object other) =>
      other is BoardArrow &&
      other.from == from &&
      other.to == to &&
      other.style == style &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(from, to, style, scale);

  @override
  String toString() => 'BoardArrow(${from.name}${to.name}, ${style.name})';
}

/// The mood of a glyph. `BoardView` picks the colour.
enum BoardGlyphTone { positive, neutral, inaccuracy, mistake, blunder }

/// A small badge on the corner of a square, such as "??" on the destination
/// of a blunder.
@immutable
class BoardGlyph {
  const BoardGlyph(this.symbol, this.tone)
    : assert(
        symbol.length > 0 && symbol.length <= 2,
        'a glyph has one or two characters',
      );

  static const brilliant = BoardGlyph('!!', BoardGlyphTone.positive);
  static const good = BoardGlyph('!', BoardGlyphTone.positive);
  static const interesting = BoardGlyph('!?', BoardGlyphTone.neutral);
  static const inaccuracy = BoardGlyph('?!', BoardGlyphTone.inaccuracy);
  static const mistake = BoardGlyph('?', BoardGlyphTone.mistake);
  static const blunder = BoardGlyph('??', BoardGlyphTone.blunder);

  /// One or two characters.
  final String symbol;
  final BoardGlyphTone tone;

  @override
  bool operator ==(Object other) =>
      other is BoardGlyph && other.symbol == symbol && other.tone == tone;

  @override
  int get hashCode => Object.hash(symbol, tone);

  @override
  String toString() => 'BoardGlyph($symbol, ${tone.name})';
}
