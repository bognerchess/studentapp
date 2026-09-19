// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:ui' show Tristate;

import 'package:bogner_chess/core/chess/board_view.dart';
import 'package:bogner_chess/features/entry/domain/entry_draft_store.dart';
import 'package:bogner_chess/features/entry/domain/entry_result.dart';
import 'package:bogner_chess/features/entry/domain/entry_settings.dart';
import 'package:bogner_chess/features/entry/ui/entry_identified.dart';
import 'package:bogner_chess/features/entry/ui/entry_move_list.dart';
import 'package:bogner_chess/features/entry/ui/entry_screen.dart';
import 'package:bogner_chess/router.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/board_tester.dart';
import '../../helpers/pump_app.dart';
import 'fakes.dart';
import 'pump_entry.dart';

/// The first ten plies of the Ruy Lopez, Morphy defence.
const List<String> kRuyLopez = [
  'e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', //
  'a7a6', 'b5a4', 'g8f6', 'e1g1', 'f8e7',
];
const String kRuyLopezPgn =
    '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7';

/// White's a-pawn reaches a7 and can capture on b8.
const List<String> kToSeventh = [
  'a2a4', 'b7b5', 'a4b5', 'g8f6', 'b5b6', 'f6g8', 'b6a7', 'g8f6', //
];

Future<void> playAll(WidgetTester tester, Iterable<String> moves) async {
  for (final move in moves) {
    await tester.playMove(move);
  }
}

EntryDraftSnapshot draft(
  String pgn, {
  String id = 'draft-1',
  int? cursor,
  Side orientation = Side.white,
}) => EntryDraftSnapshot(
  id: id,
  pgnMoves: pgn,
  cursorPly: cursor ?? 99,
  orientation: orientation,
  updatedAt: DateTime.utc(2026, 9, 1),
);

/// The tappable row of the "always promote to queen" menu item.
final Finder autoQueenItem = find
    .ancestor(
      of: find.text('Always promote to queen'),
      matching: find.byType(InkWell),
    )
    .first;

SemanticsNode semanticsOf(WidgetTester tester, String identifier) => find
    .semantics
    .byPredicate((node) => node.identifier == identifier)
    .evaluate()
    .single;

void main() {
  group('entering moves', () {
    testWidgets('ten plies by tap-tap give the expected movetext', (
      tester,
    ) async {
      await pumpEntry(tester);

      await playAll(tester, kRuyLopez);

      expect(tester.entryPgn, kRuyLopezPgn);
      expect(find.text('Nf3'), findsOneWidget);
      expect(find.text('O-O'), findsOneWidget);
      expect(find.text('5.'), findsOneWidget);
      expect(tester.boardSquareLabel('g1'), 'g1, white king');
      await settleAutosave(tester);
    });

    testWidgets('dragging works too', (tester) async {
      await pumpEntry(tester);

      await tester.dragPiece('e2', 'e4');
      await tester.dragPiece('e7', 'e5');

      expect(tester.entryPgn, '1. e4 e5');
      await settleAutosave(tester);
    });

    testWidgets('an illegal tap-tap changes nothing', (tester) async {
      final harness = await pumpEntry(tester);

      await tester.playMove('e2e5');
      await tester.playMove('e7e5');

      expect(tester.entryPgn, '');
      expect(harness.haptics, isEmpty);
      await settleAutosave(tester);
      expect(harness.store.saves, isEmpty);
    });

    testWidgets('every move gives a light haptic', (tester) async {
      final harness = await pumpEntry(tester);

      await playAll(tester, kRuyLopez.take(3));

      expect(
        harness.haptics,
        List.filled(3, 'HapticFeedbackType.selectionClick'),
      );
      await settleAutosave(tester);
    });

    testWidgets('the status line follows the game to checkmate', (
      tester,
    ) async {
      await pumpEntry(tester);
      expect(find.text('Move 1 · White to move'), findsOneWidget);
      expect(find.text('Play the first move on the board.'), findsOneWidget);

      await tester.playMove('f2f3');
      expect(find.text('Move 1 · Black to move'), findsOneWidget);
      expect(find.text('Play the first move on the board.'), findsNothing);

      await playAll(tester, ['e7e5', 'g2g4', 'd8h4']);
      expect(find.text('Checkmate · Black wins'), findsOneWidget);
      expect(find.text('Qh4#'), findsOneWidget);
      await settleAutosave(tester);
    });

    testWidgets('the wakelock is held while the screen is open', (
      tester,
    ) async {
      final harness = await pumpEntry(tester);
      expect(harness.wakelock.isOn, isTrue);

      routerOf(tester).pop();
      await tester.pumpAndSettle();

      expect(find.byType(EntryScreen), findsNothing);
      expect(harness.wakelock.calls, ['enable', 'disable']);
    });
  });

  group('undo and redo', () {
    testWidgets('both are disabled on an empty game, Done too', (tester) async {
      await pumpEntry(tester);

      for (final id in [EntryIds.undo, EntryIds.redo, EntryIds.done]) {
        final data = semanticsOf(tester, id).getSemanticsData();
        expect(data.flagsCollection.isEnabled, Tristate.isFalse, reason: id);
        expect(data.hasAction(SemanticsAction.tap), isFalse, reason: id);
      }
    });

    testWidgets('undo removes the last move, redo restores it', (tester) async {
      await pumpEntry(tester);
      await playAll(tester, kRuyLopez.take(4));

      await tester.tapEntryControl(EntryIds.undo);
      expect(tester.entryPgn, '1. e4 e5 2. Nf3');
      expect(find.text('Nc6'), findsNothing);
      expect(tester.boardSquareLabel('b8'), 'b8, black knight');

      await tester.tapEntryControl(EntryIds.undo);
      expect(tester.entryPgn, '1. e4 e5');

      await tester.tapEntryControl(EntryIds.redo);
      await tester.tapEntryControl(EntryIds.redo);
      expect(tester.entryPgn, '1. e4 e5 2. Nf3 Nc6');
      expect(tester.boardSquareLabel('c6'), 'c6, black knight');
      await settleAutosave(tester);
    });

    testWidgets('correcting a slip: undo, other move, no question', (
      tester,
    ) async {
      await pumpEntry(tester);
      await playAll(tester, ['e2e4', 'e7e5', 'g1e2']);

      await tester.tapEntryControl(EntryIds.undo);
      await tester.playMove('g1f3');

      expect(tester.entryPgn, '1. e4 e5 2. Nf3');
      expect(find.byType(BottomSheet), findsNothing);
      await settleAutosave(tester);
    });

    testWidgets('undo inside the line steps back without removing', (
      tester,
    ) async {
      await pumpEntry(tester);
      await playAll(tester, kRuyLopez.take(4));
      await tester.tapEntryControl(entryMoveIdentifier(2));

      await tester.tapEntryControl(EntryIds.undo);

      expect(tester.entryState.game.cursor, 1);
      expect(tester.entryPgn, '1. e4 e5 2. Nf3 Nc6');
      await tester.tapEntryControl(EntryIds.redo);
      expect(tester.entryState.game.cursor, 2);
      await settleAutosave(tester);
    });

    testWidgets('the controls work through the accessibility tree', (
      tester,
    ) async {
      await pumpEntry(tester);
      await playAll(tester, kRuyLopez.take(2));

      expect(semanticsOf(tester, EntryIds.undo).label, 'Undo');
      expect(semanticsOf(tester, EntryIds.redo).label, 'Forward');
      expect(semanticsOf(tester, EntryIds.flip).label, 'Flip board');
      expect(semanticsOf(tester, EntryIds.done).label, 'Done');
      expect(semanticsOf(tester, EntryIds.menu).label, 'More options');
      expect(semanticsOf(tester, entryMoveIdentifier(2)).label, '1. Black, e5');

      tester.semantics.tap(
        find.semantics.byPredicate((n) => n.identifier == EntryIds.undo),
      );
      await tester.pumpAndSettle();
      expect(tester.entryPgn, '1. e4');
      await settleAutosave(tester);
    });
  });

  group('jumping and overwriting', () {
    testWidgets('tapping a move shows that position', (tester) async {
      await pumpEntry(tester);
      await playAll(tester, kRuyLopez);

      await tester.tapEntryControl(entryMoveIdentifier(3));

      expect(tester.entryState.game.cursor, 3);
      expect(tester.boardSquareLabel('f3'), 'f3, white knight');
      expect(tester.boardSquareLabel('b8'), 'b8, black knight');
      expect(find.text('Move 2 · Black to move'), findsOneWidget);
      expect(tester.entryPgn, kRuyLopezPgn, reason: 'nothing is removed');

      await tester.tapEntryControl(entryMoveIdentifier(0));
      expect(tester.entryState.game.cursor, 0);
      expect(tester.boardSquareLabel('e2'), 'e2, white pawn');
      await settleAutosave(tester);
    });

    testWidgets('playing the same move from the middle just goes on', (
      tester,
    ) async {
      await pumpEntry(tester);
      await playAll(tester, kRuyLopez);
      await tester.tapEntryControl(entryMoveIdentifier(2));

      await tester.playMove('g1f3');

      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.entryState.game.cursor, 3);
      expect(tester.entryPgn, kRuyLopezPgn);
      await settleAutosave(tester);
    });

    testWidgets('a different move asks, and Replace cuts the tail', (
      tester,
    ) async {
      final harness = await pumpEntry(tester);
      await playAll(tester, kRuyLopez);
      await tester.tapEntryControl(entryMoveIdentifier(4));
      harness.haptics.clear();

      await tester.playMove('f1c4');

      expect(find.text('Replace the following 6 moves?'), findsOneWidget);
      expect(find.textContaining('Bc4 is not the move'), findsOneWidget);
      expect(find.textContaining('(Bb5)'), findsOneWidget);
      expect(tester.entryPgn, kRuyLopezPgn, reason: 'not yet');
      expect(harness.haptics, isEmpty);

      await tester.tapEntryControl(EntryIds.overwriteConfirm);

      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.entryPgn, '1. e4 e5 2. Nf3 Nc6 3. Bc4');
      expect(tester.boardSquareLabel('c4'), 'c4, white bishop');
      expect(harness.haptics, hasLength(1));
      await settleAutosave(tester);
      expect(harness.store.saves.last.pgnMoves, '1. e4 e5 2. Nf3 Nc6 3. Bc4');
    });

    testWidgets('Keep moves leaves everything as it was', (tester) async {
      await pumpEntry(tester);
      await playAll(tester, kRuyLopez);
      await tester.tapEntryControl(entryMoveIdentifier(4));

      await tester.playMove('f1c4');
      await tester.tapEntryControl(EntryIds.overwriteCancel);

      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.entryPgn, kRuyLopezPgn);
      expect(tester.entryState.game.cursor, 4);
      expect(tester.boardSquareLabel('f1'), 'f1, white bishop');
      expect(tester.boardSquareLabel('c4'), 'c4, empty');
      await settleAutosave(tester);
    });

    testWidgets('dismissing the sheet keeps the moves; one move is singular', (
      tester,
    ) async {
      await pumpEntry(tester);
      await playAll(tester, kRuyLopez.take(3));
      await tester.tapEntryControl(entryMoveIdentifier(2));

      await tester.playMove('b1c3');
      expect(find.text('Replace the following move?'), findsOneWidget);

      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.entryPgn, '1. e4 e5 2. Nf3');
      await settleAutosave(tester);
    });
  });

  group('promotion', () {
    testWidgets('the picker offers the underpromotion', (tester) async {
      await pumpEntry(tester);
      await playAll(tester, kToSeventh);

      await tester.tapSquare('a7');
      await tester.tapSquare('b8');
      expect(tester.entryState.game.plyCount, 8, reason: 'waits for a piece');
      expect(tester.boardSquareLabel('b8'), 'Promote to queen');

      await tester.tapSquare('b8');
      expect(tester.entryPgn, endsWith('5. axb8=Q'));

      await tester.tapEntryControl(EntryIds.undo);
      await tester.playMove('a7b8n');
      expect(tester.entryPgn, endsWith('5. axb8=N'));
      expect(tester.boardSquareLabel('b8'), 'b8, white knight');
      await settleAutosave(tester);
    });

    testWidgets('"always promote to queen" skips the picker and is kept', (
      tester,
    ) async {
      final harness = await pumpEntry(tester);
      await playAll(tester, kToSeventh);

      await tester.tapEntryControl(EntryIds.menu);
      expect(find.text('Always promote to queen'), findsOneWidget);
      await tester.tap(autoQueenItem);
      await tester.pumpAndSettle();

      expect(harness.preferences.values[kEntryAutoQueenKey], isTrue);
      expect(
        tester.widget<BoardView>(find.byType(BoardView)).autoQueen,
        isTrue,
      );

      await tester.tapSquare('a7');
      await tester.tapSquare('b8');
      expect(tester.entryPgn, endsWith('5. axb8=Q'));

      // And off again.
      await tester.tapEntryControl(EntryIds.menu);
      await tester.tap(autoQueenItem);
      await tester.pumpAndSettle();
      expect(harness.preferences.values[kEntryAutoQueenKey], isFalse);
      await settleAutosave(tester);
    });

    testWidgets('the stored setting is applied on the next visit', (
      tester,
    ) async {
      await pumpEntry(
        tester,
        preferences: FakePreferences({kEntryAutoQueenKey: true}),
      );

      expect(
        tester.widget<BoardView>(find.byType(BoardView)).autoQueen,
        isTrue,
      );
    });
  });

  group('flip', () {
    testWidgets('turns the board and the squares with it', (tester) async {
      await pumpEntry(tester);
      final before = tester.getCenter(tester.boardSquare('a1'));

      await tester.tapEntryControl(EntryIds.flip);

      expect(tester.entryState.orientation, Side.black);
      expect(tester.getCenter(tester.boardSquare('h8')), before);
      await tester.playMove('e2e4');
      expect(tester.entryPgn, '1. e4');
      await settleAutosave(tester);
    });
  });

  group('autosave', () {
    testWidgets('an untouched game is not a draft', (tester) async {
      final harness = await pumpEntry(tester);
      await tester.tapEntryControl(EntryIds.flip);
      await settleAutosave(tester);

      expect(harness.store.saves, isEmpty);
    });

    testWidgets('every ply is saved, debounced, with cursor and orientation', (
      tester,
    ) async {
      final harness = await pumpEntry(tester);
      final saves = harness.store.saves;

      for (final (index, move) in kRuyLopez.take(4).indexed) {
        await tester.playMove(move);
        await settleAutosave(tester);
        expect(saves, hasLength(index + 1));
        expect(saves.last.cursorPly, index + 1);
      }
      expect(saves.map((s) => s.pgnMoves), [
        '1. e4',
        '1. e4 e5',
        '1. e4 e5 2. Nf3',
        '1. e4 e5 2. Nf3 Nc6',
      ]);
      expect(saves.map((s) => s.id).toSet(), {tester.entryState.draftId});
      expect(saves.last.updatedAt, kEntryTestNow);
      expect(saves.last.orientation, Side.white);

      await tester.tapEntryControl(EntryIds.undo);
      await settleAutosave(tester);
      expect(saves.last.pgnMoves, '1. e4 e5 2. Nf3');

      await tester.tapEntryControl(entryMoveIdentifier(1));
      await tester.tapEntryControl(EntryIds.flip);
      await settleAutosave(tester);
      expect(saves.last.cursorPly, 1);
      expect(saves.last.orientation, Side.black);
    });

    testWidgets('pausing the app writes at once', (tester) async {
      final harness = await pumpEntry(tester);
      await tester.playMoveWithoutSettling('e2e4');
      expect(tester.entryPgn, '1. e4');
      expect(harness.store.saves, isEmpty, reason: 'debounce still running');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(harness.store.saves.single.pgnMoves, '1. e4');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    });

    testWidgets('leaving the screen writes at once', (tester) async {
      final harness = await pumpEntry(tester);
      await tester.playMoveWithoutSettling('e2e4');
      expect(harness.store.saves, isEmpty, reason: 'debounce still running');

      routerOf(tester).pop();
      await tester.pumpAndSettle();

      expect(harness.store.saves.single.pgnMoves, '1. e4');
    });

    testWidgets('a failing store does not disturb entry', (tester) async {
      final harness = await pumpEntry(tester);
      harness.store.saveError = StateError('disk full');

      await tester.playMove('e2e4');
      await settleAutosave(tester);
      expect(tester.entryPgn, '1. e4');
      harness.store.saveError = null;
      await tester.playMove('e7e5');
      await settleAutosave(tester);

      expect(tester.takeException(), isNull);
      expect(harness.store.saves.single.pgnMoves, '1. e4 e5');
    });
  });

  group('resume', () {
    testWidgets('a draft comes back with moves, cursor and orientation', (
      tester,
    ) async {
      final store = RecordingDraftStore([
        draft(kRuyLopezPgn, cursor: 4, orientation: Side.black),
      ]);

      await pumpEntry(tester, store: store, draftId: 'draft-1');

      expect(store.loads, ['draft-1']);
      expect(tester.entryState.draftId, 'draft-1');
      expect(tester.entryPgn, kRuyLopezPgn);
      expect(tester.entryState.game.cursor, 4);
      expect(tester.entryState.orientation, Side.black);
      expect(tester.boardSquareLabel('c6'), 'c6, black knight');
      expect(tester.boardSquareLabel('b5'), 'b5, empty');
      expect(store.saves, isEmpty, reason: 'loading is not a change');

      // Going on from there saves under the same id.
      await tester.playMove('f1b5');
      await settleAutosave(tester);
      expect(store.saves.single.id, 'draft-1');
      expect(store.saves.single.cursorPly, 5);
    });

    testWidgets('a draft at its end can simply be continued', (tester) async {
      final store = RecordingDraftStore([draft('1. e4 e5')]);
      await pumpEntry(tester, store: store, draftId: 'draft-1');

      await tester.playMove('g1f3');
      await settleAutosave(tester);

      expect(store.saves.single.pgnMoves, '1. e4 e5 2. Nf3');
    });

    testWidgets('a damaged draft gives back its legal prefix', (tester) async {
      final store = RecordingDraftStore([draft('1. e4 e5 2. Ke3 Nc6')]);

      await pumpEntry(tester, store: store, draftId: 'draft-1');

      expect(tester.entryPgn, '1. e4 e5');
    });

    testWidgets('an unknown draft id starts an empty game under that id', (
      tester,
    ) async {
      final harness = await pumpEntry(tester, draftId: 'gone');

      expect(tester.entryPgn, '');
      await tester.playMove('e2e4');
      await settleAutosave(tester);
      expect(harness.store.saves.single.id, 'gone');
    });
  });

  group('Done', () {
    testWidgets('without a next step: saved as draft, back to New game', (
      tester,
    ) async {
      final harness = await pumpEntry(tester);
      await playAll(tester, ['f2f3', 'e7e5', 'g2g4', 'd8h4']);

      await tester.tapEntryControl(EntryIds.done);

      expect(find.byType(EntryScreen), findsNothing);
      expect(locationOf(tester), AppRoutes.newGame);
      expect(find.text('Saved as draft'), findsOneWidget);
      expect(harness.store.saves.last.pgnMoves, '1. f3 e5 2. g4 Qh4#');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('a caller that pushed the screen gets the EntryResult', (
      tester,
    ) async {
      await pumpEntry(tester);
      routerOf(tester).pop();
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold).first);
      final pushed = context.push<EntryResult>(AppRoutes.newGameEntry);
      await tester.pumpAndSettle();
      await playAll(tester, ['f2f3', 'e7e5', 'g2g4', 'd8h4']);
      final draftId = tester.entryState.draftId;
      await tester.tapEntryControl(EntryIds.flip);
      await tester.tapEntryControl(EntryIds.done);

      expect(
        await pushed,
        EntryResult(
          draftId: draftId,
          pgnMoves: '1. f3 e5 2. g4 Qh4#',
          plyCount: 4,
          suggestedResult: '0-1',
          orientation: Side.black,
        ),
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('German', () {
    testWidgets('every text of the screen and the sheet is German', (
      tester,
    ) async {
      await pumpEntry(tester, locale: const Locale('de', 'CH'));

      expect(find.text('Züge eingeben'), findsOneWidget);
      expect(find.text('Fertig'), findsOneWidget);
      expect(find.text('Rückgängig'), findsOneWidget);
      expect(find.text('Zug 1 · Weiss am Zug'), findsOneWidget);
      expect(find.text('Spiele den ersten Zug auf dem Brett.'), findsOneWidget);
      expect(find.byTooltip('Brett drehen'), findsOneWidget);
      expect(find.byTooltip('Vorwärts'), findsOneWidget);
      expect(tester.boardSquareLabel('e2'), 'e2, weisser Bauer');
      expect(tester.boardSquareLabel('d8'), 'd8, schwarze Dame');
      expect(tester.boardSquareLabel('e4'), 'e4, leer');

      await playAll(tester, kRuyLopez.take(3));
      expect(find.text('Zug 2 · Schwarz am Zug'), findsOneWidget);
      expect(semanticsOf(tester, entryMoveIdentifier(1)).label, '1. Weiss, e4');

      await tester.tapEntryControl(entryMoveIdentifier(1));
      await tester.playMove('d7d5');
      expect(find.text('Die folgenden 2 Züge ersetzen?'), findsOneWidget);
      expect(find.text('Ersetzen'), findsOneWidget);
      expect(find.text('Züge behalten'), findsOneWidget);
      await tester.tapEntryControl(EntryIds.overwriteCancel);

      await tester.tapEntryControl(EntryIds.menu);
      expect(find.text('Immer in Dame umwandeln'), findsOneWidget);
      await tester.tapAt(const Offset(10, 400));
      await tester.pumpAndSettle();
      await settleAutosave(tester);
    });

    testWidgets('the promotion picker is announced in German', (tester) async {
      await pumpEntry(tester, locale: const Locale('de'));
      await playAll(tester, kToSeventh);

      await tester.tapSquare('a7');
      await tester.tapSquare('b8');

      expect(tester.boardSquareLabel('b8'), 'Umwandeln in Dame');
      expect(tester.boardSquareLabel('h1'), 'Umwandlung abbrechen');
      await tester.tapSquare('h1');
      await settleAutosave(tester);
    });
  });

  group('small screen, large type, both themes', () {
    for (final locale in const [Locale('en'), Locale('de')]) {
      for (final brightness in Brightness.values) {
        testWidgets('${locale.languageCode}, ${brightness.name}: nothing '
            'overflows and the board stays usable', (tester) async {
          await pumpEntry(
            tester,
            locale: locale,
            brightness: brightness,
            textScale: 1.3,
            screen: kIphoneSe,
          );
          expect(
            Theme.of(tester.element(find.byType(BoardView))).brightness,
            brightness,
          );

          await playAll(tester, kRuyLopez);
          expect(tester.takeException(), isNull);
          expect(tester.entryPgn, kRuyLopezPgn);

          // The board is a square inside the screen, as wide as it can be.
          final board = tester.getRect(find.byType(BoardView));
          expect(board.width, board.height);
          expect(board.width, greaterThanOrEqualTo(320));
          expect(board.left, greaterThanOrEqualTo(0));
          expect(board.right, lessThanOrEqualTo(kIphoneSe.width));

          // Controls are on screen, below the board, and large enough.
          final undo = tester.getRect(tester.entryControl(EntryIds.undo));
          expect(undo.top, greaterThanOrEqualTo(board.bottom));
          expect(undo.bottom, lessThanOrEqualTo(kIphoneSe.height));
          expect(undo.height, greaterThanOrEqualTo(64));
          expect(undo.width, greaterThanOrEqualTo(180));
          for (final id in [EntryIds.redo, EntryIds.flip, EntryIds.done]) {
            final rect = tester.getRect(tester.entryControl(id));
            expect(rect.height, greaterThanOrEqualTo(44), reason: id);
            expect(rect.width, greaterThanOrEqualTo(44), reason: id);
          }

          // The sheet fits too.
          await tester.tapEntryControl(entryMoveIdentifier(2));
          await tester.playMove('b1c3');
          expect(tester.takeException(), isNull);
          final confirm = tester.getRect(
            tester.entryControl(EntryIds.overwriteConfirm),
          );
          final cancel = tester.getRect(
            tester.entryControl(EntryIds.overwriteCancel),
          );
          expect(confirm.top, greaterThanOrEqualTo(0));
          expect(cancel.bottom, lessThanOrEqualTo(kIphoneSe.height));
          await tester.tapEntryControl(EntryIds.overwriteCancel);
          await settleAutosave(tester);
        });
      }
    }

    testWidgets('on a current iPhone the board spans the full width', (
      tester,
    ) async {
      await pumpEntry(tester);

      final board = tester.getRect(find.byType(BoardView));
      expect(board.width, kIphone17Pro.width);
      expect(board.left, 0);
    });
  });

  group('the move list', () {
    testWidgets('keeps the current move in view in a long game', (
      tester,
    ) async {
      // Knights out and back, twenty times: 80 plies.
      final shuffle = [
        for (var i = 0; i < 20; i++) ...['g1f3', 'g8f6', 'f3g1', 'f6g8'],
      ];
      final store = RecordingDraftStore([draft(_pgnOf(shuffle))]);
      await pumpEntry(tester, store: store, draftId: 'draft-1');
      expect(tester.entryState.game.plyCount, 80);

      Rect rectOf(int ply) =>
          tester.getRect(tester.entryControl(entryMoveIdentifier(ply)));
      const screen = Rect.fromLTWH(0, 0, 402, 874);

      expect(screen.contains(rectOf(80).center), isTrue);
      expect(screen.contains(rectOf(1).center), isFalse);

      await tester.tapEntryControl(entryMoveIdentifier(0));
      expect(screen.contains(rectOf(1).center), isTrue);
      expect(screen.contains(rectOf(80).center), isFalse);

      // Stepping forward drags the list along.
      for (var i = 0; i < 30; i++) {
        await tester.tapEntryControl(EntryIds.redo);
      }
      expect(tester.entryState.game.cursor, 30);
      expect(screen.contains(rectOf(30).center), isTrue);
      expect(screen.contains(rectOf(1).center), isFalse);
      await settleAutosave(tester);
    });
  });
}

String _pgnOf(List<String> ucis) {
  Position position = Chess.initial;
  final buffer = StringBuffer();
  for (final (index, uci) in ucis.indexed) {
    final (next, san) = position.makeSan(NormalMove.fromUci(uci));
    if (index.isEven) buffer.write('${index ~/ 2 + 1}. ');
    buffer.write('$san ');
    position = next;
  }
  return buffer.toString().trim();
}
