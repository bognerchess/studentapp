import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/widgets.dart';
import './widgets/background.dart';
import './models.dart';

/// Describes the color scheme of a [ChessboardBackground].
///
/// Use the `static const` members to ensure flutter doesn't rebuild the board
/// background more than necessary.
@immutable
class ChessboardColorScheme {
  const ChessboardColorScheme({
    required this.lightSquare,
    required this.darkSquare,
    required this.background,
    required this.whiteCoordBackground,
    required this.blackCoordBackground,
    required this.lastMove,
    required this.selected,
    required this.validMoves,
    required this.validPremoves,
  });

  /// Light square color of the board
  final Color lightSquare;

  /// Dark square color of the board
  final Color darkSquare;

  /// Board background that defines light and dark square colors
  final ChessboardBackground background;

  /// Board background that defines light and dark square colors and with white
  /// facing coordinates included
  final ChessboardBackground whiteCoordBackground;

  /// Board background that defines light and dark square colors and with black
  /// facing coordinates included
  final ChessboardBackground blackCoordBackground;

  /// Color of highlighted last move
  final HighlightDetails lastMove;

  /// Color of highlighted selected square
  final HighlightDetails selected;

  /// Color of squares occupied with valid moves dots
  final Color validMoves;

  /// Color of squares occupied with valid premoves dots
  final Color validPremoves;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;

    return other is ChessboardColorScheme &&
        other.lightSquare == lightSquare &&
        other.darkSquare == darkSquare &&
        other.background == background &&
        other.whiteCoordBackground == whiteCoordBackground &&
        other.blackCoordBackground == blackCoordBackground &&
        other.lastMove == lastMove &&
        other.selected == selected &&
        other.validMoves == validMoves &&
        other.validPremoves == validPremoves;
  }

  @override
  int get hashCode => Object.hash(
    lightSquare,
    darkSquare,
    background,
    whiteCoordBackground,
    blackCoordBackground,
    lastMove,
    selected,
    validMoves,
    validPremoves,
  );

  ChessboardColorScheme copyWith({
    Color? lightSquare,
    Color? darkSquare,
    ChessboardBackground? background,
    ChessboardBackground? whiteCoordBackground,
    ChessboardBackground? blackCoordBackground,
    HighlightDetails? lastMove,
    HighlightDetails? selected,
    Color? validMoves,
    Color? validPremoves,
  }) {
    return ChessboardColorScheme(
      lightSquare: lightSquare ?? this.lightSquare,
      darkSquare: darkSquare ?? this.darkSquare,
      background: background ?? this.background,
      whiteCoordBackground: whiteCoordBackground ?? this.whiteCoordBackground,
      blackCoordBackground: blackCoordBackground ?? this.blackCoordBackground,
      lastMove: lastMove ?? this.lastMove,
      selected: selected ?? this.selected,
      validMoves: validMoves ?? this.validMoves,
      validPremoves: validPremoves ?? this.validPremoves,
    );
  }

  static const brown = ChessboardColorScheme(
    lightSquare: Color(0xfff0d9b6),
    darkSquare: Color(0xffb58863),
    background: SolidColorChessboardBackground(
      lightSquare: Color(0xfff0d9b6),
      darkSquare: Color(0xffb58863),
    ),
    whiteCoordBackground: SolidColorChessboardBackground(
      lightSquare: Color(0xfff0d9b6),
      darkSquare: Color(0xffb58863),
      coordinates: true,
    ),
    blackCoordBackground: SolidColorChessboardBackground(
      lightSquare: Color(0xfff0d9b6),
      darkSquare: Color(0xffb58863),
      coordinates: true,
      orientation: Side.black,
    ),
    lastMove: HighlightDetails(solidColor: Color(0x809cc700)),
    selected: HighlightDetails(solidColor: Color(0x6014551e)),
    validMoves: Color(0x4014551e),
    validPremoves: Color(0x40203085),
  );

  static const blue = ChessboardColorScheme(
    lightSquare: Color(0xffdee3e6),
    darkSquare: Color(0xff8ca2ad),
    background: SolidColorChessboardBackground(
      lightSquare: Color(0xffdee3e6),
      darkSquare: Color(0xff8ca2ad),
    ),
    whiteCoordBackground: SolidColorChessboardBackground(
      lightSquare: Color(0xffdee3e6),
      darkSquare: Color(0xff8ca2ad),
      coordinates: true,
    ),
    blackCoordBackground: SolidColorChessboardBackground(
      lightSquare: Color(0xffdee3e6),
      darkSquare: Color(0xff8ca2ad),
      coordinates: true,
      orientation: Side.black,
    ),
    lastMove: HighlightDetails(solidColor: Color(0x809bc700)),
    selected: HighlightDetails(solidColor: Color(0x6014551e)),
    validMoves: Color(0x4014551e),
    validPremoves: Color(0x40203085),
  );

  static const green = ChessboardColorScheme(
    lightSquare: Color(0xffffffdd),
    darkSquare: Color(0xff86a666),
    background: SolidColorChessboardBackground(
      lightSquare: Color(0xffffffdd),
      darkSquare: Color(0xff86a666),
    ),
    whiteCoordBackground: SolidColorChessboardBackground(
      lightSquare: Color(0xffffffdd),
      darkSquare: Color(0xff86a666),
      coordinates: true,
    ),
    blackCoordBackground: SolidColorChessboardBackground(
      lightSquare: Color(0xffffffdd),
      darkSquare: Color(0xff86a666),
      coordinates: true,
      orientation: Side.black,
    ),
    lastMove: HighlightDetails(solidColor: Color.fromRGBO(0, 155, 199, 0.41)),
    selected: HighlightDetails(solidColor: Color.fromRGBO(216, 85, 0, 0.3)),
    validMoves: Color.fromRGBO(0, 0, 0, 0.20),
    validPremoves: Color(0x40203085),
  );

  static const ic = ChessboardColorScheme(
    lightSquare: Color(0xffececec),
    darkSquare: Color(0xffc1c18e),
    background: SolidColorChessboardBackground(
      lightSquare: Color(0xffececec),
      darkSquare: Color(0xffc1c18e),
    ),
    whiteCoordBackground: SolidColorChessboardBackground(
      lightSquare: Color(0xffececec),
      darkSquare: Color(0xffc1c18e),
      coordinates: true,
    ),
    blackCoordBackground: SolidColorChessboardBackground(
      lightSquare: Color(0xffececec),
      darkSquare: Color(0xffc1c18e),
      coordinates: true,
      orientation: Side.black,
    ),
    lastMove: HighlightDetails(solidColor: Color(0x809cc700)),
    selected: HighlightDetails(solidColor: Color(0x6014551e)),
    validMoves: Color(0x4014551e),
    validPremoves: Color(0x40203085),
  );
}
