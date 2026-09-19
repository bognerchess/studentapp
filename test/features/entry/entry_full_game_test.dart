// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/features/entry/domain/entry_game.dart';
import 'package:bogner_chess/features/entry/domain/entry_result.dart';
import 'package:bogner_chess/features/entry/ui/entry_identified.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/board_tester.dart';
import '../../helpers/pump_app.dart';
import 'pump_entry.dart';

/// A constructed 80-ply game (nobody ever played it; it exists to visit the
/// special moves): en passant (3. exf6), white castles short by moving the
/// king two squares (`e1g1`), black castles long by putting the king onto the
/// rook (`e8a8`), four promotions of which three are underpromotions
/// (`b2c1q`, `h2g1b`, `e2e1b`, `d7e8n`), checks, and checkmate on the last
/// ply. Every entry is what the user taps: from, to, promotion piece.
const List<String> kFullGameTaps = [
  'e2e4', 'd7d5', 'e4e5', 'f7f5', 'e5f6', 'g8f6', 'g1f3', 'b8c6', //
  'f1b5', 'c8g4', 'e1g1', 'd8d7', 'd2d4', 'e8a8', 'c2c3', 'g7g6',
  'g2g3', 'g6g5', 'c1e3', 'a7a5', 'h2h4', 'g5h4', 'g1g2', 'h4h3',
  'g2h2', 'e7e5', 'c3c4', 'd5c4', 'b1c3', 'f6h5', 'b2b3', 'e5e4',
  'a2a4', 'c4b3', 'd4d5', 'b7b6', 'd5c6', 'h7h6', 'd1c1', 'b3b2',
  'h2h1', 'b2c1q', 'b5a6', 'c8b8', 'c6d7', 'h3h2', 'e3b6', 'c7c6',
  'f3g1', 'h2g1b', 'f2f4', 'c1a1', 'f4f5', 'c6c5', 'f5f6', 'c5c4',
  'f6f7', 'e4e3', 'a6b7', 'a1f1', 'b6a5', 'e3e2', 'b7a6', 'e2e1b',
  'a6c4', 'd8e8', 'd7e8n', 'h5f6', 'c4d3', 'f6h7', 'e8f6', 'g4e2',
  'g3g4', 'h6h5', 'c3b5', 'h5g4', 'f6d5', 'g4g3', 'a5b6', 'g3g2',
];

const String kFullGameMovetext =
    '1. e4 d5 2. e5 f5 3. exf6 Nxf6 4. Nf3 Nc6 5. Bb5 Bg4 6. O-O Qd7 '
    '7. d4 O-O-O 8. c3 g6 9. g3 g5 10. Be3 a5 11. h4 gxh4 12. Kg2 h3+ '
    '13. Kh2 e5 14. c4 dxc4 15. Nc3 Nh5 16. b3 e4 17. a4 cxb3 18. d5 b6 '
    '19. dxc6 h6 20. Qc1 b2 21. Kh1 bxc1=Q 22. Ba6+ Kb8 23. cxd7 h2 '
    '24. Bxb6 c6 25. Ng1 hxg1=B 26. f4 Qxa1 27. f5 c5 28. f6 c4 29. f7 e3 '
    '30. Bb7 Qxf1 31. Bxa5 e2 32. Ba6 e1=B 33. Bxc4 Re8 34. dxe8=N Nf6 '
    '35. Bd3 Nh7 36. Nf6 Be2 37. g4 h5 38. Nb5 hxg4 39. Nd5 g3 40. Bb6 g2#';

void main() {
  group('the fixture', () {
    // Checked with dartchess alone, independently of EntryGame and the UI.
    test('is a legal 80-ply game with the special moves it promises', () {
      expect(kFullGameTaps, hasLength(80));

      Position position = Chess.initial;
      final sans = <String>[];
      for (final (ply, uci) in kFullGameTaps.indexed) {
        final move = NormalMove.fromUci(uci);
        expect(position.isLegal(move), isTrue, reason: 'ply ${ply + 1}: $uci');
        final (next, san) = position.makeSan(move);
        sans.add(san);
        position = next;
      }

      final numbered = [
        for (final (ply, san) in sans.indexed)
          ply.isEven ? '${ply ~/ 2 + 1}. $san' : san,
      ].join(' ');
      expect(numbered, kFullGameMovetext);

      expect(sans, contains('exf6'), reason: 'en passant');
      expect(sans, containsAll(['O-O', 'O-O-O']));
      expect(sans.where((san) => san.contains('=')), [
        'bxc1=Q',
        'hxg1=B',
        'e1=B',
        'dxe8=N',
      ]);
      expect(position.isCheckmate, isTrue);
      expect(position.outcome, Outcome.blackWins);
    });

    test('the en passant capture really is one', () {
      final game = EntryGame.fromPgnMoves('1. e4 d5 2. e5 f5 3. exf6');

      expect(game.positionAt(4).epSquare, Square.f6);
      expect(game.position.board.pieceAt(Square.f5), isNull);
    });
  });

  testWidgets('80 plies entered by tap-tap give the exact movetext', (
    tester,
  ) async {
    final harness = await pumpEntry(tester);
    routerOf(tester).pop();
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    final pushed = context.push<EntryResult>('/new/entry');
    await tester.pumpAndSettle();

    for (final (ply, taps) in kFullGameTaps.indexed) {
      await tester.playMove(taps);
      expect(
        tester.entryState.game.plyCount,
        ply + 1,
        reason: 'ply ${ply + 1} ($taps) was not accepted',
      );
    }

    expect(tester.entryPgn, kFullGameMovetext);
    expect(find.text('Checkmate · Black wins'), findsOneWidget);
    expect(harness.haptics, hasLength(80));
    expect(tester.takeException(), isNull);

    // Every ply reached the store, the last one complete.
    await settleAutosave(tester);
    expect(harness.store.saves, hasLength(80));
    expect(harness.store.saves.last.pgnMoves, kFullGameMovetext);
    expect(harness.store.saves.last.cursorPly, 80);

    // The draft reads back as the same game.
    expect(
      EntryGame.fromPgnMoves(harness.store.saves.last.pgnMoves).toPgnMoves(),
      kFullGameMovetext,
    );

    await tester.tapEntryControl(EntryIds.done);
    final result = await pushed;
    expect(result!.pgnMoves, kFullGameMovetext);
    expect(result.plyCount, 80);
    expect(result.suggestedResult, '0-1');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('the same game with the board flipped, by dragging', (
    tester,
  ) async {
    await pumpEntry(tester);
    await tester.tapEntryControl(EntryIds.flip);

    for (final taps in kFullGameTaps) {
      if (taps.length > 4) {
        // A promotion: the picker needs the taps of playMove.
        await tester.playMove(taps);
      } else {
        await tester.dragPiece(taps.substring(0, 2), taps.substring(2, 4));
      }
    }

    expect(tester.entryPgn, kFullGameMovetext);
    await settleAutosave(tester);
  });
}
