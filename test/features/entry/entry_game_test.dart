// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/features/entry/domain/entry_game.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

NormalMove uci(String move) => NormalMove.fromUci(move);

EntryGame playAll(String moves, [EntryGame? from]) => moves
    .split(' ')
    .where((m) => m.isNotEmpty)
    .fold(from ?? EntryGame.initial(), (game, m) => game.play(uci(m)));

void main() {
  group('a new game', () {
    test('is the empty standard starting position', () {
      final game = EntryGame.initial();

      expect(game.plyCount, 0);
      expect(game.cursor, 0);
      expect(game.position.fen, kInitialFEN);
      expect(game.lastMove, isNull);
      expect(game.isAtEnd, isTrue);
      expect(game.canUndo, isFalse);
      expect(game.canRedo, isFalse);
      expect(game.toPgnMoves(), '');
      expect(game.suggestedResult, isNull);
    });

    test('undo, redo and goTo on it change nothing', () {
      final game = EntryGame.initial();

      expect(game.undo(), same(game));
      expect(game.redo(), same(game));
      expect(game.goTo(5), same(game));
      expect(game.goTo(-1), same(game));
    });
  });

  group('play at the end of the line', () {
    test('appends the move with its SAN and advances the cursor', () {
      final game = playAll('e2e4 e7e5 g1f3');

      expect(game.plyCount, 3);
      expect(game.cursor, 3);
      expect(game.moves.map((m) => m.san), ['e4', 'e5', 'Nf3']);
      expect(game.lastMove!.move, uci('g1f3'));
      expect(game.position.turn, Side.black);
      expect(game.toPgnMoves(), '1. e4 e5 2. Nf3');
    });

    test('is immutable: the previous game is untouched', () {
      final before = playAll('e2e4');
      final after = before.play(uci('e7e5'));

      expect(before.plyCount, 1);
      expect(after.plyCount, 2);
      expect(() => before.moves.add(after.moves.last), throwsUnsupportedError);
    });

    test('rejects an illegal move', () {
      final game = EntryGame.initial();

      expect(game.isLegal(uci('e2e5')), isFalse);
      expect(() => game.play(uci('e2e5')), throwsArgumentError);
      // Black cannot start.
      expect(() => game.play(uci('e7e5')), throwsArgumentError);
    });

    test('rejects a move that leaves the king in check', () {
      // 1. e4 e5 2. Qh5 Nc6 3. Qxf7+ and now only the king can take.
      final game = playAll('e2e4 e7e5 d1h5 b8c6 h5f7');

      expect(game.position.isCheck, isTrue);
      expect(game.moves.last.san, 'Qxf7+');
      expect(game.isLegal(uci('a7a6')), isFalse);
      expect(game.isLegal(uci('e8f7')), isTrue);
    });
  });

  group('castling', () {
    const prelude = 'e2e4 e7e5 g1f3 g8f6 f1c4 f8c5';

    test('king to g1 and king onto the rook are the same move', () {
      final kingStep = playAll('$prelude e1g1');
      final ontoRook = playAll('$prelude e1h1');

      expect(kingStep, ontoRook);
      expect(kingStep.moves.last.san, 'O-O');
      expect(kingStep.position.fen, ontoRook.position.fen);
      // Stored in the canonical form, highlighted the way a player sees it.
      expect(kingStep.moves.last.move, uci('e1h1'));
      expect(ontoRook.moves.last.move, uci('e1h1'));
      expect(kingStep.moves.last.highlight, uci('e1g1'));
      expect(kingStep.position.board.pieceAt(Square.g1), Piece.whiteKing);
      expect(kingStep.position.board.pieceAt(Square.f1), Piece.whiteRook);
    });

    test('black castles short in both notations', () {
      final a = playAll('$prelude e1g1 e8g8');
      final b = playAll('$prelude e1g1 e8h8');

      expect(a, b);
      expect(a.toPgnMoves(), '1. e4 e5 2. Nf3 Nf6 3. Bc4 Bc5 4. O-O O-O');
      expect(a.moves.last.highlight, uci('e8g8'));
    });

    test('queenside in both notations', () {
      const queenside = 'd2d4 d7d5 b1c3 b8c6 c1f4 c8f5 d1d2 d8d7';
      final white = playAll('$queenside e1c1');
      final whiteOntoRook = playAll('$queenside e1a1');
      final both = playAll('$queenside e1c1 e8a8');

      expect(white, whiteOntoRook);
      expect(white.moves.last.san, 'O-O-O');
      expect(white.moves.last.move, uci('e1a1'));
      expect(white.moves.last.highlight, uci('e1c1'));
      expect(both.moves.last.san, 'O-O-O');
      expect(both.moves.last.highlight, uci('e8c8'));
      expect(both.position.board.pieceAt(Square.c8), Piece.blackKing);
      expect(both.position.board.pieceAt(Square.d8), Piece.blackRook);
    });

    test('replaying the stored castling move in the other notation only '
        'advances', () {
      final game = playAll('$prelude e1g1 e8g8').goTo(6);

      expect(game.wouldOverwriteTail(uci('e1g1')), isFalse);
      expect(game.wouldOverwriteTail(uci('e1h1')), isFalse);
      expect(game.play(uci('e1h1')).cursor, 7);
      expect(game.play(uci('e1h1')).plyCount, 8);
    });
  });

  group('en passant', () {
    test('captures the pawn that just passed', () {
      final game = playAll('e2e4 a7a6 e4e5 d7d5 e5d6');

      expect(game.moves.last.san, 'exd6');
      expect(game.position.board.pieceAt(Square.d5), isNull);
      expect(game.position.board.pieceAt(Square.d6), Piece.whitePawn);
    });

    test('is only legal on the very next move', () {
      final game = playAll('e2e4 a7a6 e4e5 d7d5 h2h3 h7h6');

      expect(game.isLegal(uci('e5d6')), isFalse);
    });

    test('survives a PGN round trip', () {
      final game = playAll('e2e4 a7a6 e4e5 d7d5 e5d6');

      expect(EntryGame.fromPgnMoves(game.toPgnMoves()), game);
    });
  });

  group('promotion', () {
    // White's a-pawn walks to b7 by capturing; black shuffles a knight.
    const toSeventh = 'a2a4 b7b5 a4b5 g8f6 b5b6 f6g8 b6a7 g8f6';

    test('needs a role', () {
      final game = playAll(toSeventh);

      expect(game.isLegal(uci('a7b8')), isFalse);
      expect(() => game.play(uci('a7b8')), throwsArgumentError);
    });

    test('to a queen', () {
      final game = playAll('$toSeventh a7b8q');

      expect(game.moves.last.san, 'axb8=Q');
      expect(game.position.board.pieceAt(Square.b8), Piece.whiteQueen);
    });

    test('to a knight, rook and bishop (underpromotion)', () {
      expect(playAll('$toSeventh a7b8n').moves.last.san, 'axb8=N');
      expect(playAll('$toSeventh a7b8r').moves.last.san, 'axb8=R');
      expect(playAll('$toSeventh a7b8b').moves.last.san, 'axb8=B');
      expect(
        playAll('$toSeventh a7b8n').position.board.pieceAt(Square.b8),
        Piece.whiteKnight,
      );
    });

    test('a different promotion piece is a different move', () {
      final game = playAll('$toSeventh a7b8q f6g8').goTo(8);

      expect(game.wouldOverwriteTail(uci('a7b8q')), isFalse);
      expect(game.wouldOverwriteTail(uci('a7b8n')), isTrue);
    });

    test('an underpromotion survives a PGN round trip', () {
      final game = playAll('$toSeventh a7b8n');

      expect(game.toPgnMoves(), endsWith('5. axb8=N'));
      expect(EntryGame.fromPgnMoves(game.toPgnMoves()), game);
    });
  });

  group('check, mate and the suggested result', () {
    test('check has a plus and no result', () {
      final game = playAll('e2e4 f7f6 d1h5');

      expect(game.moves.last.san, 'Qh5+');
      expect(game.position.isCheck, isTrue);
      expect(game.suggestedResult, isNull);
    });

    test("fool's mate: black wins", () {
      final game = playAll('f2f3 e7e5 g2g4 d8h4');

      expect(game.moves.last.san, 'Qh4#');
      expect(game.position.isCheckmate, isTrue);
      expect(game.outcome, Outcome.blackWins);
      expect(game.suggestedResult, '0-1');
      expect(game.position.legalMoves.values.every((s) => s.isEmpty), isTrue);
    });

    test("scholar's mate: white wins", () {
      final game = playAll('e2e4 e7e5 f1c4 b8c6 d1h5 g8f6 h5f7');

      expect(game.moves.last.san, 'Qxf7#');
      expect(game.suggestedResult, '1-0');
    });

    test('stalemate is a draw', () {
      // The shortest known stalemate (Sam Loyd), 19 plies.
      final game = playAll(
        'e2e3 a7a5 d1h5 a8a6 h5a5 h7h5 h2h4 a6h6 a5c7 f7f6 c7d7 e8f7 '
        'd7b7 d8d3 b7b8 d3h7 b8c8 f7g6 c8e6',
      );

      expect(game.position.isStalemate, isTrue);
      expect(game.outcome, Outcome.draw);
      expect(game.suggestedResult, '1/2-1/2');
    });

    test('the suggestion looks at the end of the line, not at the cursor', () {
      final game = playAll('f2f3 e7e5 g2g4 d8h4').goTo(1);

      expect(game.position.isCheckmate, isFalse);
      expect(game.suggestedResult, '0-1');
    });
  });

  group('undo and redo', () {
    test('undo at the end removes the last move', () {
      final game = playAll('e2e4 e7e5 g1f3').undo();

      expect(game.plyCount, 2);
      expect(game.cursor, 2);
      expect(game.isAtEnd, isTrue);
      expect(game.toPgnMoves(), '1. e4 e5');
      expect(game.position.turn, Side.white);
    });

    test('redo restores what undo removed, in order', () {
      final full = playAll('e2e4 e7e5 g1f3');
      final undone = full.undo().undo();

      expect(undone.toPgnMoves(), '1. e4');
      expect(undone.canRedo, isTrue);
      expect(undone.redo().toPgnMoves(), '1. e4 e5');
      expect(undone.redo().redo(), full);
      expect(undone.redo().redo().canRedo, isFalse);
    });

    test('correcting a slip needs no confirmation', () {
      // Meant Nf3, tapped Ne2: undo, play the right move.
      final game = playAll('e2e4 e7e5 g1e2').undo();

      expect(game.wouldOverwriteTail(uci('g1f3')), isFalse);
      final fixed = game.play(uci('g1f3'));
      expect(fixed.toPgnMoves(), '1. e4 e5 2. Nf3');
      expect(fixed.canRedo, isFalse, reason: 'Ne2 is forgotten');
    });

    test('re-playing the undone move by hand keeps the rest of the redo '
        'stack', () {
      final full = playAll('e2e4 e7e5 g1f3');
      final game = full.undo().undo().play(uci('e7e5'));

      expect(game.canRedo, isTrue);
      expect(game.redo(), full);
    });

    test('undo inside the line only steps back', () {
      final game = playAll('e2e4 e7e5 g1f3 b8c6').goTo(2).undo();

      expect(game.cursor, 1);
      expect(game.plyCount, 4);
      expect(game.toPgnMoves(), '1. e4 e5 2. Nf3 Nc6');
    });

    test('redo inside the line steps forward and stops at the end', () {
      var game = playAll('e2e4 e7e5 g1f3').goTo(0);

      game = game.redo();
      expect(game.cursor, 1);
      game = game.redo().redo();
      expect(game.cursor, 3);
      expect(game.canRedo, isFalse);
      expect(game.redo(), same(game));
    });

    test('undo all the way down stops at the start', () {
      var game = playAll('e2e4 e7e5');
      game = game.undo().undo();

      expect(game.plyCount, 0);
      expect(game.canUndo, isFalse);
      expect(game.undo(), same(game));
      expect(game.redo().redo().toPgnMoves(), '1. e4 e5');
    });
  });

  group('goTo', () {
    test('shows the position after that ply and keeps the line', () {
      final game = playAll('e2e4 e7e5 g1f3 b8c6').goTo(1);

      expect(game.cursor, 1);
      expect(game.plyCount, 4);
      expect(game.tailLength, 3);
      expect(game.lastMove!.san, 'e4');
      expect(game.position.turn, Side.black);
      expect(game.position.fen, game.positionAt(1).fen);
      expect(game.isAtEnd, isFalse);
    });

    test('clamps', () {
      final game = playAll('e2e4 e7e5');

      expect(game.goTo(99).cursor, 2);
      expect(game.goTo(-3).cursor, 0);
      expect(game.goTo(0).lastMove, isNull);
    });
  });

  group('play inside the line', () {
    final line = playAll('e2e4 e7e5 g1f3 b8c6 f1b5 a7a6');

    test('the move that is already there just advances', () {
      final game = line.goTo(2);

      expect(game.wouldOverwriteTail(uci('g1f3')), isFalse);
      final next = game.play(uci('g1f3'));
      expect(next.cursor, 3);
      expect(next.moves, line.moves);
    });

    test('a different move needs the confirmation', () {
      final game = line.goTo(2);

      expect(game.wouldOverwriteTail(uci('f1c4')), isTrue);
      expect(game.tailLength, 4);
      expect(() => game.play(uci('f1c4')), throwsStateError);
    });

    test('with overwrite the tail is replaced', () {
      final game = line.goTo(2).play(uci('f1c4'), overwrite: true);

      expect(game.toPgnMoves(), '1. e4 e5 2. Bc4');
      expect(game.cursor, 3);
      expect(game.isAtEnd, isTrue);
      expect(game.canRedo, isFalse);
    });

    test('overwriting from the very first move', () {
      final game = line.goTo(0).play(uci('d2d4'), overwrite: true);

      expect(game.toPgnMoves(), '1. d4');
    });

    test('at the end nothing is ever overwritten', () {
      expect(line.wouldOverwriteTail(uci('b5a4')), isFalse);
    });

    test('an illegal move is an ArgumentError, not an overwrite question', () {
      expect(
        () => line.goTo(2).play(uci('e1e3'), overwrite: true),
        throwsArgumentError,
      );
    });
  });

  group('PGN movetext', () {
    test('numbers the moves and has no headers or result', () {
      final pgn = playAll('e2e4 e7e5 g1f3 b8c6 f1b5').toPgnMoves();

      expect(pgn, '1. e4 e5 2. Nf3 Nc6 3. Bb5');
      expect(pgn, isNot(contains('[')));
      expect(pgn, isNot(contains('*')));
    });

    test('does not depend on the cursor', () {
      final game = playAll('e2e4 e7e5 g1f3');

      expect(game.goTo(1).toPgnMoves(), game.toPgnMoves());
    });

    test('is what dartchess reads back as the same main line', () {
      final game = playAll('e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5c6 d7c6 e1g1');
      final parsed = PgnGame.parsePgn(game.toPgnMoves());

      expect(
        parsed.moves.mainline().map((node) => node.san),
        game.moves.map((m) => m.san),
      );
    });

    test('fromPgnMoves puts the cursor at the end by default', () {
      final game = EntryGame.fromPgnMoves('1. e4 e5 2. Nf3 Nc6');

      expect(game.plyCount, 4);
      expect(game.cursor, 4);
      expect(game, playAll('e2e4 e7e5 g1f3 b8c6'));
    });

    test('fromPgnMoves restores a cursor and clamps it', () {
      expect(EntryGame.fromPgnMoves('1. e4 e5', cursorPly: 1).cursor, 1);
      expect(EntryGame.fromPgnMoves('1. e4 e5', cursorPly: 9).cursor, 2);
    });

    test('fromPgnMoves ignores headers, comments, NAGs, variations and the '
        'result', () {
      final game = EntryGame.fromPgnMoves(
        '[Event "Club"]\n[Result "1-0"]\n\n'
        '1. e4 {best by test} e5 \$1 (1... c5 2. Nf3) 2. Nf3 1-0',
      );

      expect(game.toPgnMoves(), '1. e4 e5 2. Nf3');
    });

    test('fromPgnMoves of nothing is a new game', () {
      expect(EntryGame.fromPgnMoves(''), EntryGame.initial());
      expect(EntryGame.fromPgnMoves('  \n'), EntryGame.initial());
    });

    test('fromPgnMoves throws on an illegal move', () {
      expect(
        () => EntryGame.fromPgnMoves('1. e4 e5 2. Ke3'),
        throwsFormatException,
      );
    });

    test('fromPgnMoves does not accept a promotion without a piece', () {
      expect(
        () => EntryGame.fromPgnMoves(
          '1. a4 b5 2. axb5 Nf6 3. b6 Ng8 4. bxa7 Nf6 5. axb8',
        ),
        throwsFormatException,
      );
    });

    test('lenient fromPgnMoves keeps the legal prefix', () {
      final game = EntryGame.fromPgnMoves('1. e4 e5 2. Ke3 Nc6', lenient: true);

      expect(game.toPgnMoves(), '1. e4 e5');
    });
  });

  group('equality', () {
    test('same moves and cursor are equal, a different cursor is not', () {
      expect(playAll('e2e4 e7e5'), playAll('e2e4 e7e5'));
      expect(playAll('e2e4 e7e5').hashCode, playAll('e2e4 e7e5').hashCode);
      expect(playAll('e2e4 e7e5'), isNot(playAll('e2e4 e7e5').goTo(1)));
      expect(playAll('e2e4 e7e5'), isNot(playAll('e2e4 e7e6')));
    });
  });
}
