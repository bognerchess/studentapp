import 'package:dartchess/dartchess.dart';
import 'package:flutter/widgets.dart';
import 'models.dart';

const _pieceSetsPath = 'assets/piece_sets';

/// A piece set and its corresponding piece assets.
enum PieceSet {
  cburnett('Colin M.L. Burnett', PieceSet.cburnettAssets),
  merida('Merida', PieceSet.meridaAssets),
  rhosgfx('RhosGFX', PieceSet.rhosgfxAssets);

  const PieceSet(this.label, this.assets);

  /// The label of this [PieceSet].
  final String label;

  /// The [PieceAssets] for this [PieceSet].
  final PieceAssets assets;

  /// The [PieceAssets] for the 'Colin M.L. Burnett' piece set.
  static const PieceAssets cburnettAssets = {
    PieceKind.blackRook: AssetImage('$_pieceSetsPath/cburnett/bR.webp', package: 'chessground'),
    PieceKind.blackPawn: AssetImage('$_pieceSetsPath/cburnett/bP.webp', package: 'chessground'),
    PieceKind.blackKnight: AssetImage('$_pieceSetsPath/cburnett/bN.webp', package: 'chessground'),
    PieceKind.blackBishop: AssetImage('$_pieceSetsPath/cburnett/bB.webp', package: 'chessground'),
    PieceKind.blackQueen: AssetImage('$_pieceSetsPath/cburnett/bQ.webp', package: 'chessground'),
    PieceKind.blackKing: AssetImage('$_pieceSetsPath/cburnett/bK.webp', package: 'chessground'),
    PieceKind.whiteRook: AssetImage('$_pieceSetsPath/cburnett/wR.webp', package: 'chessground'),
    PieceKind.whitePawn: AssetImage('$_pieceSetsPath/cburnett/wP.webp', package: 'chessground'),
    PieceKind.whiteKnight: AssetImage('$_pieceSetsPath/cburnett/wN.webp', package: 'chessground'),
    PieceKind.whiteBishop: AssetImage('$_pieceSetsPath/cburnett/wB.webp', package: 'chessground'),
    PieceKind.whiteQueen: AssetImage('$_pieceSetsPath/cburnett/wQ.webp', package: 'chessground'),
    PieceKind.whiteKing: AssetImage('$_pieceSetsPath/cburnett/wK.webp', package: 'chessground'),
  };

  /// The [PieceAssets] for the 'Merida' piece set.
  static const PieceAssets meridaAssets = {
    PieceKind.blackRook: AssetImage('$_pieceSetsPath/merida/bR.webp', package: 'chessground'),
    PieceKind.blackPawn: AssetImage('$_pieceSetsPath/merida/bP.webp', package: 'chessground'),
    PieceKind.blackKnight: AssetImage('$_pieceSetsPath/merida/bN.webp', package: 'chessground'),
    PieceKind.blackBishop: AssetImage('$_pieceSetsPath/merida/bB.webp', package: 'chessground'),
    PieceKind.blackQueen: AssetImage('$_pieceSetsPath/merida/bQ.webp', package: 'chessground'),
    PieceKind.blackKing: AssetImage('$_pieceSetsPath/merida/bK.webp', package: 'chessground'),
    PieceKind.whiteRook: AssetImage('$_pieceSetsPath/merida/wR.webp', package: 'chessground'),
    PieceKind.whitePawn: AssetImage('$_pieceSetsPath/merida/wP.webp', package: 'chessground'),
    PieceKind.whiteKnight: AssetImage('$_pieceSetsPath/merida/wN.webp', package: 'chessground'),
    PieceKind.whiteBishop: AssetImage('$_pieceSetsPath/merida/wB.webp', package: 'chessground'),
    PieceKind.whiteQueen: AssetImage('$_pieceSetsPath/merida/wQ.webp', package: 'chessground'),
    PieceKind.whiteKing: AssetImage('$_pieceSetsPath/merida/wK.webp', package: 'chessground'),
  };

  /// The [PieceAssets] for the 'RhosGFX' piece set.
  static const PieceAssets rhosgfxAssets = {
    PieceKind.blackRook: AssetImage('$_pieceSetsPath/rhosgfx/bR.webp', package: 'chessground'),
    PieceKind.blackPawn: AssetImage('$_pieceSetsPath/rhosgfx/bP.webp', package: 'chessground'),
    PieceKind.blackKnight: AssetImage('$_pieceSetsPath/rhosgfx/bN.webp', package: 'chessground'),
    PieceKind.blackBishop: AssetImage('$_pieceSetsPath/rhosgfx/bB.webp', package: 'chessground'),
    PieceKind.blackQueen: AssetImage('$_pieceSetsPath/rhosgfx/bQ.webp', package: 'chessground'),
    PieceKind.blackKing: AssetImage('$_pieceSetsPath/rhosgfx/bK.webp', package: 'chessground'),
    PieceKind.whiteRook: AssetImage('$_pieceSetsPath/rhosgfx/wR.webp', package: 'chessground'),
    PieceKind.whitePawn: AssetImage('$_pieceSetsPath/rhosgfx/wP.webp', package: 'chessground'),
    PieceKind.whiteKnight: AssetImage('$_pieceSetsPath/rhosgfx/wN.webp', package: 'chessground'),
    PieceKind.whiteBishop: AssetImage('$_pieceSetsPath/rhosgfx/wB.webp', package: 'chessground'),
    PieceKind.whiteQueen: AssetImage('$_pieceSetsPath/rhosgfx/wQ.webp', package: 'chessground'),
    PieceKind.whiteKing: AssetImage('$_pieceSetsPath/rhosgfx/wK.webp', package: 'chessground'),
  };
}
