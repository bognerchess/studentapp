// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/features/entry/domain/entry_controller.dart';
import 'package:bogner_chess/features/entry/domain/entry_draft_store.dart';
import 'package:bogner_chess/features/entry/domain/entry_game.dart';
import 'package:bogner_chess/features/entry/ui/entry_identified.dart';
import 'package:bogner_chess/features/entry/ui/entry_screen.dart';
import 'package:bogner_chess/router.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_harness.dart';
import 'helpers/board_taps.dart';
import 'helpers/ply_work.dart';

/// PRD IN-1 on a device: a whole 40-move game entered on the board.
///
/// This is a **correctness test first**. Eighty plies go in as touches on the
/// board of the installed app, and the movetext that comes out has to be the
/// movetext of the fixture, character for character.
///
/// The second thing it does is guard against a performance regression, with
/// the per-ply budget the plan asks for. Read the doc comment of [PlyWork]
/// for what is measured and what it is worth: a debug build on a simulator is
/// several times slower than a release build on a phone, and no number here
/// says anything about how fast a person enters a game. **Human gate H9 —
/// a stopwatch, a paper scoresheet and a real iPhone, 40 moves in under three
/// minutes — is the acceptance bar.** This test only notices when the app's
/// own work per ply grows.

/// A constructed 80-ply game (nobody played it; it exists to visit the moves
/// that are easy to get wrong): en passant (`3. exf6`), white castles short
/// by moving the king two squares (`e1g1`), black castles long by putting the
/// king onto the rook (`e8a8`), four promotions of which three are
/// underpromotions, checks, and checkmate on the last ply. Each entry is what
/// the finger does: from square, to square, and for a promotion the piece.
const List<String> kEntryTaps = [
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

/// Exactly what the app has to produce. Forty moves, no headers, no result.
const String kEntryMovetext =
    '1. e4 d5 2. e5 f5 3. exf6 Nxf6 4. Nf3 Nc6 5. Bb5 Bg4 6. O-O Qd7 '
    '7. d4 O-O-O 8. c3 g6 9. g3 g5 10. Be3 a5 11. h4 gxh4 12. Kg2 h3+ '
    '13. Kh2 e5 14. c4 dxc4 15. Nc3 Nh5 16. b3 e4 17. a4 cxb3 18. d5 b6 '
    '19. dxc6 h6 20. Qc1 b2 21. Kh1 bxc1=Q 22. Ba6+ Kb8 23. cxd7 h2 '
    '24. Bxb6 c6 25. Ng1 hxg1=B 26. f4 Qxa1 27. f5 c5 28. f6 c4 29. f7 e3 '
    '30. Bb7 Qxf1 31. Bxa5 e2 32. Ba6 e1=B 33. Bxc4 Re8 34. dxe8=N Nf6 '
    '35. Bd3 Nh7 36. Nf6 Be2 37. g4 h5 38. Nb5 hxg4 39. Nd5 g3 40. Bb6 g2#';

/// The per-ply budget from the plan (`03-design-flutter-client.md`, section
/// 5): the app's own work for one ply stays under this. See [PlyWork].
const Duration kPlyBudget = Duration(milliseconds: 150);

/// Frames rendered after the last touch of a ply, before the ply's window is
/// closed. Without them a ply would be exactly its two or three touch frames
/// and the board animation and the move list scroll would cost nothing
/// measurable. With a fixed number of them, the measurement covers the first
/// few frames of both and stays comparable between runs.
const int kFramesAfterPly = 3;

void main() {
  final binding = ensureIntegrationBinding();

  testWidgets('the fixture is a legal 80-ply game with its special moves', (
    tester,
  ) async {
    // dartchess alone, no app, no board: if this fails, the expectation the
    // rest of the file measures the app against is itself wrong.
    expect(kEntryTaps, hasLength(80));

    var position = Chess.initial as Position;
    final sans = <String>[];
    for (final (index, uci) in kEntryTaps.indexed) {
      final move = NormalMove.fromUci(uci);
      expect(position.isLegal(move), isTrue, reason: 'ply ${index + 1}: $uci');
      final (next, san) = position.makeSan(move);
      sans.add(san);
      position = next;
    }
    final numbered = [
      for (final (index, san) in sans.indexed)
        index.isEven ? '${index ~/ 2 + 1}. $san' : san,
    ].join(' ');

    expect(numbered, kEntryMovetext);
    expect(sans, contains('exf6'), reason: 'en passant');
    expect(sans, containsAll(['O-O', 'O-O-O']));
    expect(sans.where((san) => san.contains('=')), [
      'bxc1=Q',
      'hxg1=B',
      'e1=B',
      'dxe8=N',
    ]);
    expect(position.isCheckmate, isTrue);
  });

  testWidgets('a 40-move game entered on the board gives exactly its movetext', (
    tester,
  ) async {
    final container = await launchApp(tester);
    await goTo(tester, container, AppRoutes.newGameEntry);
    expect(find.byType(EntryScreen), findsOneWidget);
    expect(_game(tester, container).plyCount, 0, reason: 'a fresh game');

    // The board does not move or turn during the game, so the geometry is
    // read once and every tap is computed from it.
    final board = tester.boardRect;
    final orientation = tester.boardOrientation;
    expect(orientation, Side.white);

    final recorder = PlyWorkRecorder(binding)..start();
    for (final (index, uci) in kEntryTaps.indexed) {
      final taps = tester.moveTaps(uci, board, orientation);
      recorder.beginPly('${index + 1}. $uci');
      await tester.tapPoints(taps, extraFrames: kFramesAfterPly);
      recorder.endPly();
      expect(
        _game(tester, container).plyCount,
        index + 1,
        reason: 'ply ${index + 1} ($uci) did not reach the game',
      );
    }
    await tester.pumpAndSettle();

    // Correctness first: the whole point of the test.
    final game = _game(tester, container);
    expect(game.toPgnMoves(), kEntryMovetext);
    expect(game.suggestedResult, '0-1', reason: 'checkmate on ply 80');
    expect(tester.takeException(), isNull);

    // The screen's own way out. Semantics are switched on only now, after
    // the measurement, because a live semantics tree is per-frame work the
    // app otherwise only does under VoiceOver.
    final state = container.read(entryControllerProvider(_draftId(tester)));
    final semantics = tester.ensureSemantics();
    await tester.tap(find.bySemanticsIdentifier(EntryIds.done));
    await tester.pumpAndSettle();
    semantics.dispose();
    expect(find.byType(EntryScreen), findsNothing, reason: 'Done left entry');

    // What the autosave left behind is the same game.
    final draft = await container
        .read(entryDraftStoreProvider)
        .load(state.draftId);
    expect(draft, isNotNull, reason: 'the draft of ${state.draftId}');
    expect(draft!.pgnMoves, kEntryMovetext);
    expect(EntryGame.fromPgnMoves(draft.pgnMoves).plyCount, 80);

    // The budget. The report goes out before the assertion, so that a run
    // that fails still says by how much.
    final report = await recorder.stop(tester, budget: kPlyBudget);
    publishReport(binding, 'entry_40_moves', report.toJson());
    debugPrint(report.toTable());

    expect(
      report.unmeasured,
      isEmpty,
      reason:
          'no frame timing was attributed to these plies, so the budget was '
          'not measured at all. Check that the engine reports frame numbers '
          'on this device.',
    );
    expect(
      report.overBudget.map(
        (ply) => '${ply.label}: ${ply.appWork.inMilliseconds} ms',
      ),
      isEmpty,
      reason:
          'the app spent more than ${kPlyBudget.inMilliseconds} ms of its own '
          'work on a ply (see the table above)',
    );
  });
}

String? _draftId(WidgetTester tester) =>
    tester.widget<EntryScreen>(find.byType(EntryScreen)).draftId;

EntryGame _game(WidgetTester tester, ProviderContainer container) =>
    container.read(entryControllerProvider(_draftId(tester))).game;
