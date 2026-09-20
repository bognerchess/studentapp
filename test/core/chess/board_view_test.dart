// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/chess/board_thumbnail.dart';
import 'package:bogner_chess/core/chess/board_view.dart';
import 'package:bogner_chess/core/chess/chessground_mapping.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/board_tester.dart';

const double _boardSize = 320;

Position _fen(String fen) => Chess.fromSetup(Setup.parseFen(fen));

/// Owns the position the way a screen does: plays what the board reports and
/// rebuilds.
class _Harness extends StatefulWidget {
  const _Harness({
    super.key,
    required this.initial,
    required this.moves,
    this.orientation = Side.white,
    this.interaction = BoardInteraction.entry,
    this.autoQueen = false,
    this.arrows = const [],
    this.glyphs = const {},
  });

  final Position initial;
  final List<NormalMove> moves;
  final Side orientation;
  final BoardInteraction interaction;
  final bool autoQueen;
  final List<BoardArrow> arrows;
  final Map<Square, BoardGlyph> glyphs;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late Position _position = widget.initial;
  NormalMove? _lastMove;

  @override
  Widget build(BuildContext context) => MaterialApp(
    // Dragging a piece needs the Overlay that every app provides.
    home: Align(
      alignment: Alignment.topLeft,
      child: BoardView(
        position: _position,
        size: _boardSize,
        orientation: widget.orientation,
        interaction: widget.interaction,
        lastMove: _lastMove,
        autoQueen: widget.autoQueen,
        arrows: widget.arrows,
        glyphs: widget.glyphs,
        onMove: (move) => setState(() {
          widget.moves.add(move);
          _position = _position.play(move);
          _lastMove = move;
        }),
      ),
    ),
  );
}

void main() {
  group('move entry', () {
    testWidgets('tapping e2 then e4 reports e2e4 and shows the new position', (
      tester,
    ) async {
      final moves = <NormalMove>[];
      await tester.pumpWidget(_Harness(initial: Chess.initial, moves: moves));

      expect(tester.boardSquareLabel('e2'), 'e2, white pawn');
      expect(tester.boardSquareLabel('e4'), 'e4, empty');

      await tester.tapSquare('e2');
      expect(moves, isEmpty);
      await tester.tapSquare('e4');

      expect(moves, [const NormalMove(from: Square.e2, to: Square.e4)]);
      expect(tester.boardSquareLabel('e2'), 'e2, empty');
      expect(tester.boardSquareLabel('e4'), 'e4, white pawn');

      // Both sides are entered on the same board.
      await tester.playMove('g8f6');
      expect(moves.last, const NormalMove(from: Square.g8, to: Square.f6));
      expect(tester.boardSquareLabel('f6'), 'f6, black knight');
    });

    testWidgets('the accessibility tap action takes the same path', (
      tester,
    ) async {
      final moves = <NormalMove>[];
      await tester.pumpWidget(_Harness(initial: Chess.initial, moves: moves));

      final node = tester.getSemantics(tester.boardSquare('e2'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      await tester.activateSquare('e2');
      await tester.activateSquare('e4');

      expect(moves, [const NormalMove(from: Square.e2, to: Square.e4)]);
    });

    testWidgets('dragging a piece reports the move', (tester) async {
      final moves = <NormalMove>[];
      await tester.pumpWidget(_Harness(initial: Chess.initial, moves: moves));

      await tester.dragPiece('g1', 'f3');

      expect(moves, [const NormalMove(from: Square.g1, to: Square.f3)]);
    });

    testWidgets('an illegal destination does nothing', (tester) async {
      final moves = <NormalMove>[];
      await tester.pumpWidget(_Harness(initial: Chess.initial, moves: moves));

      await tester.playMove('e2e5');
      await tester.dragPiece('b1', 'b3');
      // The side that is not to move cannot be picked up either.
      await tester.playMove('e7e5');

      expect(moves, isEmpty);
      expect(tester.boardSquareLabel('e2'), 'e2, white pawn');
    });

    testWidgets('castling arrives as the user made it and is playable', (
      tester,
    ) async {
      final moves = <NormalMove>[];
      await tester.pumpWidget(
        _Harness(
          initial: _fen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1'),
          moves: moves,
        ),
      );

      await tester.playMove('e1g1');

      expect(moves, [const NormalMove(from: Square.e1, to: Square.g1)]);
      expect(tester.boardSquareLabel('g1'), 'g1, white king');
      expect(tester.boardSquareLabel('f1'), 'f1, white rook');
    });

    testWidgets('a read-only board ignores taps and offers no tap action', (
      tester,
    ) async {
      final moves = <NormalMove>[];
      await tester.pumpWidget(
        _Harness(
          initial: Chess.initial,
          moves: moves,
          interaction: BoardInteraction.readOnly,
        ),
      );

      await tester.playMove('e2e4');
      await tester.dragPiece('e2', 'e4');

      expect(moves, isEmpty);
      final node = tester.getSemantics(tester.boardSquare('e2'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    });
  });

  group('promotion', () {
    const whitePromotes = '8/4P1k1/8/8/8/8/8/4K3 w - - 0 1';
    const blackPromotes = '4k3/8/8/8/8/8/4p1K1/8 b - - 0 1';

    testWidgets('the picker is driven by tapping, and the move has its role', (
      tester,
    ) async {
      final moves = <NormalMove>[];
      await tester.pumpWidget(
        _Harness(initial: _fen(whitePromotes), moves: moves),
      );

      await tester.playMove('e7e8');
      expect(moves, isEmpty, reason: 'the picker is open');
      expect(tester.boardSquareLabel('e8'), 'Promote to queen');
      expect(tester.boardSquareLabel('e7'), 'Promote to knight');
      expect(tester.boardSquareLabel('e6'), 'Promote to rook');
      expect(tester.boardSquareLabel('e5'), 'Promote to bishop');
      expect(tester.boardSquareLabel('a1'), 'Cancel promotion');

      await tester.tapSquare('e7');

      expect(moves, [
        const NormalMove(
          from: Square.e7,
          to: Square.e8,
          promotion: Role.knight,
        ),
      ]);
      expect(tester.boardSquareLabel('e8'), 'e8, white knight');
    });

    testWidgets('a promotion at the bottom of the screen, through semantics', (
      tester,
    ) async {
      final moves = <NormalMove>[];
      await tester.pumpWidget(
        _Harness(initial: _fen(blackPromotes), moves: moves),
      );

      await tester.activateSquare('e2');
      await tester.activateSquare('e1');
      expect(tester.boardSquareLabel('e1'), 'Promote to queen');
      expect(tester.boardSquareLabel('e4'), 'Promote to bishop');

      await tester.activateSquare('e3');

      expect(moves, [
        const NormalMove(from: Square.e2, to: Square.e1, promotion: Role.rook),
      ]);
    });

    testWidgets('the helper picks the piece on a flipped board too', (
      tester,
    ) async {
      final moves = <NormalMove>[];
      await tester.pumpWidget(
        _Harness(
          initial: _fen(whitePromotes),
          moves: moves,
          orientation: Side.black,
        ),
      );

      await tester.playMove('e7e8b');

      expect(moves, [
        const NormalMove(
          from: Square.e7,
          to: Square.e8,
          promotion: Role.bishop,
        ),
      ]);
    });

    testWidgets('tapping outside the picker cancels', (tester) async {
      final moves = <NormalMove>[];
      await tester.pumpWidget(
        _Harness(initial: _fen(whitePromotes), moves: moves),
      );

      await tester.playMove('e7e8');
      await tester.tapSquare('a1');

      expect(moves, isEmpty);
      expect(tester.boardSquareLabel('e7'), 'e7, white pawn');
    });

    testWidgets('autoQueen promotes without asking', (tester) async {
      final moves = <NormalMove>[];
      await tester.pumpWidget(
        _Harness(initial: _fen(whitePromotes), moves: moves, autoQueen: true),
      );

      await tester.playMove('e7e8');

      expect(moves, [
        const NormalMove(from: Square.e7, to: Square.e8, promotion: Role.queen),
      ]);
    });
  });

  group('orientation', () {
    testWidgets('squares sit where the user sees them', (tester) async {
      await tester.pumpWidget(
        _Harness(initial: Chess.initial, moves: const []),
      );
      const square = _boardSize / 8;
      expect(
        tester.getRect(tester.boardSquare('a1')),
        const Rect.fromLTWH(0, 7 * square, square, square),
      );
      expect(
        tester.getRect(tester.boardSquare('h8')),
        const Rect.fromLTWH(7 * square, 0, square, square),
      );

      await tester.pumpWidget(
        _Harness(
          key: UniqueKey(),
          initial: Chess.initial,
          moves: const [],
          orientation: Side.black,
        ),
      );
      expect(
        tester.getRect(tester.boardSquare('a1')),
        const Rect.fromLTWH(7 * square, 0, square, square),
      );
      expect(
        tester.getRect(tester.boardSquare('e2')),
        const Rect.fromLTWH(3 * square, square, square, square),
      );
    });

    testWidgets('a flipped board still reports the right squares', (
      tester,
    ) async {
      final moves = <NormalMove>[];
      await tester.pumpWidget(
        _Harness(initial: Chess.initial, moves: moves, orientation: Side.black),
      );

      // e2 is in the second row from the top now; tap by coordinate to prove
      // that the overlay and the board agree.
      const square = _boardSize / 8;
      await tester.tapAt(const Offset(3.5 * square, 1.5 * square));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(3.5 * square, 3.5 * square));
      await tester.pumpAndSettle();

      expect(moves, [const NormalMove(from: Square.e2, to: Square.e4)]);
    });
  });

  group('arrows and glyphs', () {
    testWidgets('become chessground shapes and annotations', (tester) async {
      await tester.pumpWidget(
        _Harness(
          initial: Chess.initial,
          moves: const [],
          interaction: BoardInteraction.readOnly,
          arrows: const [
            BoardArrow(from: Square.e2, to: Square.e4),
            BoardArrow(
              from: Square.g1,
              to: Square.f3,
              style: BoardArrowStyle.alternative,
              scale: 0.6,
            ),
          ],
          glyphs: const {Square.e4: BoardGlyph.blunder},
        ),
      );
      await tester.pumpAndSettle();

      final board = tester.widget<Chessboard>(find.byType(Chessboard));
      expect(board.shapes, {
        Arrow(
          color: arrowColorOf(BoardArrowStyle.best),
          orig: Square.e2,
          dest: Square.e4,
        ),
        Arrow(
          color: arrowColorOf(BoardArrowStyle.alternative),
          orig: Square.g1,
          dest: Square.f3,
          scale: 0.6,
        ),
      });
      expect(board.annotations, {
        Square.e4: Annotation(
          symbol: '??',
          color: glyphColorOf(BoardGlyphTone.blunder),
        ),
      });
      expect(board.controller.interactive, isFalse);
    });

    test('an arrow for a move; none for a drop', () {
      expect(
        BoardArrow.ofMove(const NormalMove(from: Square.d2, to: Square.d4)),
        const BoardArrow(from: Square.d2, to: Square.d4),
      );
      expect(
        BoardArrow.ofMove(const DropMove(to: Square.d4, role: Role.pawn)),
        isNull,
      );
    });
  });

  group('what chessground is told', () {
    test('entry: both sides, legal moves, no check', () {
      final data = gameDataOf(
        Chess.initial,
        interaction: BoardInteraction.entry,
      );
      expect(data.playerSide, PlayerSide.both);
      expect(data.sideToMove, Side.white);
      expect(data.validMoves[Square.e2], {Square.e3, Square.e4});
      expect(data.kingSquareInCheck, isNull);
    });

    test('the king in check is highlighted', () {
      final data = gameDataOf(
        _fen('4k3/8/8/8/8/8/4r3/4K3 w - - 0 1'),
        interaction: BoardInteraction.readOnly,
      );
      expect(data.kingSquareInCheck, Square.e1);
      expect(data.playerSide, PlayerSide.none);
      expect(data.validMoves, isEmpty);
    });

    test('entry settings: tap or drag, no premoves, 120 ms', () {
      final settings = boardSettingsOf(
        const BoardTheme(
          pieceSet: BoardPieceSet.rhosgfx,
          colors: BoardColors.green,
        ),
        showCoordinates: true,
        autoQueen: false,
        animationDuration: kBoardAnimationDuration,
      );
      expect(settings.pieceShiftMethod, PieceShiftMethod.either);
      expect(settings.enablePremoves, isFalse);
      expect(settings.showValidMoves, isTrue);
      expect(settings.animationDuration, const Duration(milliseconds: 120));
      expect(settings.pieceAssets, PieceSet.rhosgfxAssets);
      expect(settings.colorScheme, ChessboardColorScheme.green);
    });

    test('there are twelve themes: three piece sets, four colour pairs', () {
      expect(BoardTheme.all.toSet(), hasLength(12));
    });
  });

  testWidgets('BoardThumbnail is one labelled image', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: BoardThumbnail(
            fen: kInitialFEN,
            size: 96,
            semanticLabel: 'Final position',
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(BoardThumbnail)), const Size(96, 96));
    expect(find.bySemanticsLabel('Final position'), findsOneWidget);
  });
}
