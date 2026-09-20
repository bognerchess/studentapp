// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/analysis/analysis_view.dart';
import 'package:bogner_chess/core/chess/board_view.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/ui/widgets/error_retry.dart';
import 'package:bogner_chess/features/review/domain/review_controller.dart';
import 'package:bogner_chess/features/review/domain/review_repository.dart';
import 'package:bogner_chess/features/review/ui/coach_tab.dart';
import 'package:bogner_chess/features/review/ui/eval_graph.dart';
import 'package:bogner_chess/features/review/ui/moves_tab.dart';
import 'package:bogner_chess/features/review/ui/review_ids.dart';
import 'package:bogner_chess/features/review/ui/summary_tab.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/board_tester.dart';
import 'pump_review.dart';

BoardView _board(WidgetTester tester) =>
    tester.widget<BoardView>(find.byType(BoardView));

Set<BoardArrowStyle> _arrowStyles(WidgetTester tester) => {
  for (final arrow in _board(tester).arrows) arrow.style,
};

/// The row of the board-options menu with [label].
Finder _menuItem(String label) => find
    .ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is PopupMenuEntry),
    )
    .first;

void main() {
  setUp(() => Log.sink = (_) {});
  tearDown(Log.resetSink);

  group('header and start', () {
    testWidgets('players, result, accuracy; the coach invites to the moments', (
      tester,
    ) async {
      await pumpReview(tester);

      expect(find.text('Anna Beispiel – Bernd Muster'), findsOneWidget);
      expect(find.textContaining('1–0'), findsOneWidget);
      expect(find.text('92 %'), findsOneWidget); // 91.6
      expect(find.text('90 %'), findsOneWidget); // 89.5 rounds half up
      expect(
        tester
            .getSemantics(tester.reviewControl('review-accuracy-white'))
            .label,
        'Accuracy of White: 92 percent',
      );

      expect(find.byType(CoachTab), findsOneWidget);
      expect(find.text('Start position'), findsOneWidget);
      expect(find.text('The moments that mattered'), findsOneWidget);
      expect(tester.boardSquareLabel('e2'), 'e2, white pawn');

      await tester.tapReview(ReviewIds.coachNext);
      expect(tester.reviewState.ply, 6);
    });

    testWidgets('names fall back to the colours', (tester) async {
      await pumpReview(tester, header: const GameHeaderInfo());
      expect(find.text('White – Black'), findsOneWidget);
    });
  });

  group('stepping', () {
    testWidgets('the buttons move the board and know the ends', (tester) async {
      await pumpReview(tester);
      final semantics = tester.ensureSemantics();

      expect(
        tester.getSemantics(tester.reviewControl(ReviewIds.previous)),
        isSemantics(isButton: true, isEnabled: false, hasEnabledState: true),
      );
      await tester.tapReview(ReviewIds.next);
      expect(tester.reviewState.ply, 1);
      expect(tester.boardSquareLabel('e4'), 'e4, white pawn');
      expect(tester.boardSquareLabel('e2'), 'e2, empty');
      expect(find.text('1. e4'), findsWidgets);

      await tester.tapReview(ReviewIds.last);
      expect(tester.reviewState.ply, 80);
      expect(
        tester.getSemantics(tester.reviewControl(ReviewIds.next)),
        isSemantics(isButton: true, isEnabled: false, hasEnabledState: true),
      );
      await tester.tapReview(ReviewIds.first);
      expect(tester.reviewState.ply, 0);
      semantics.dispose();
    });

    testWidgets('key-moment buttons jump between the coach comments', (
      tester,
    ) async {
      await pumpReview(tester);
      await tester.tapReview(ReviewIds.nextMoment);
      expect(tester.reviewState.ply, 6);
      await tester.tapReview(ReviewIds.nextMoment);
      expect(tester.reviewState.ply, 10);
      await tester.tapReview(ReviewIds.previousMoment);
      expect(tester.reviewState.ply, 6);
    });
  });

  group('coach tab', () {
    testWidgets('a critical ply shows the comment, on the board too', (
      tester,
    ) async {
      await pumpReview(tester);
      await tester.tapReview(ReviewIds.nextMoment);

      expect(tester.reviewControl(ReviewIds.commentCard), findsOneWidget);
      expect(find.text('Let White take the centre'), findsOneWidget);
      expect(
        find.textContaining('b6 is slow', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('?  Mistake'), findsOneWidget);
      expect(find.text('Central break'), findsOneWidget);
      expect(find.text('AI-generated. May contain mistakes.'), findsOneWidget);
      // The card is one node for a screen reader, counter included.
      expect(
        tester.getSemantics(find.text('1/8')).label,
        contains('Key moment 1 of 8'),
      );
      // Status line: the move with its glyph, the evaluation in words.
      expect(find.text('3... b6?', findRichText: true), findsOneWidget);
      expect(find.text('White is clearly better'), findsOneWidget);
      expect(find.textContaining('+1.2'), findsNothing);

      final board = _board(tester);
      expect(board.glyphs.values.single, BoardGlyph.mistake);
      expect(_arrowStyles(tester), {
        BoardArrowStyle.best,
        BoardArrowStyle.danger,
      });
      expect(board.orientation.name, 'black');
    });

    testWidgets('the mentioned moves are emphasised', (tester) async {
      final spans = emphasizeMoves('After Nxe4 comes Qd8+, not Nxe', [
        'Nxe4',
        'Qd8+',
        'Nxe',
      ]);
      final bold = [
        for (final span in spans.cast<TextSpan>())
          if (span.style?.fontWeight == FontWeight.w700) span.text,
      ];
      expect(bold, ['Nxe4', 'Qd8+', 'Nxe']);
      expect(
        spans.cast<TextSpan>().map((s) => s.text).join(),
        'After Nxe4 '
        'comes Qd8+, not Nxe',
      );
      expect(emphasizeMoves('plain', const []), hasLength(1));
    });

    testWidgets('a ply without a comment: one engine fact and the way on', (
      tester,
    ) async {
      await pumpReview(tester);
      tester.reviewController.goTo(8);
      await tester.pumpAndSettle();

      expect(tester.reviewControl(ReviewIds.commentCard), findsNothing);
      expect(tester.reviewControl(ReviewIds.engineFact), findsOneWidget);
      expect(find.text('Next key moment'), findsOneWidget);
      await tester.tapReview(ReviewIds.coachNext);
      expect(tester.reviewState.ply, 10);
    });

    testWidgets('an inaccuracy without a comment names the better move', (
      tester,
    ) async {
      await pumpReview(tester);
      final document = tester.reviewController.document!;
      final node = document.nodes.firstWhere(
        (n) =>
            n.commentIds.isEmpty &&
            n.best != null &&
            n.best!.san != n.san &&
            document.glyphFor(n) != null,
      );
      tester.reviewController.goTo(node.ply);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Better was ${node.best!.san}.'),
        findsOneWidget,
      );
    });

    testWidgets('after the last moment the way on is the summary', (
      tester,
    ) async {
      await pumpReview(tester);
      tester.reviewController.goTo(50);
      await tester.pumpAndSettle();
      expect(find.text('See your lessons'), findsOneWidget);
      await tester.tapReview(ReviewIds.coachNext);
      expect(tester.reviewState.tab, ReviewTab.summary);
      expect(find.byType(SummaryTab), findsOneWidget);
    });

    testWidgets('a swipe moves between key moments', (tester) async {
      await pumpReview(tester);
      await tester.fling(find.byType(CoachTab), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();
      expect(tester.reviewState.ply, 6);
      await tester.fling(find.byType(CoachTab), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();
      expect(tester.reviewState.ply, 10);
      await tester.fling(find.byType(CoachTab), const Offset(200, 0), 1000);
      await tester.pumpAndSettle();
      expect(tester.reviewState.ply, 6);
      // A slow drag is not a swipe.
      await tester.drag(find.byType(CoachTab), const Offset(-30, 0));
      await tester.pumpAndSettle();
      expect(tester.reviewState.ply, 6);
    });

    testWidgets('a fallback comment looks like any other', (tester) async {
      await pumpReview(tester, fixture: kFallbackCase);
      tester.reviewController.goTo(18);
      await tester.pumpAndSettle();

      expect(find.text('Mistake on move 9'), findsOneWidget);
      expect(tester.reviewControl(ReviewIds.thumbUp), findsOneWidget);
      expect(
        tester.reviewControl(ReviewIds.commentLine('v18-best')),
        findsOneWidget,
      );
      expect(find.text('AI-generated. May contain mistakes.'), findsOneWidget);
      // Its theme is "unknown": no chip rather than a raw code.
      expect(find.text('unknown'), findsNothing);
      for (final word in ['fallback', 'template', 'gpt', 'azure']) {
        expect(find.textContaining(word), findsNothing);
      }
    });

    testWidgets('a document with unknown fields and values still reviews', (
      tester,
    ) async {
      await pumpReview(tester, fixture: kWithUnknowns);
      while (tester.reviewController.nextMoment()) {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.tapReview(ReviewIds.tabSummary);
      await tester.tapReview(ReviewIds.tabMoves);
      expect(tester.takeException(), isNull);
    });
  });

  group('line viewer', () {
    testWidgets('show line plays it on the board; back to game restores', (
      tester,
    ) async {
      await pumpReview(tester);
      await tester.tapReview(ReviewIds.nextMoment);
      expect(tester.boardSquareLabel('b6'), 'b6, black pawn');
      expect(tester.boardSquareLabel('d5'), 'd5, empty');

      expect(
        tester
            .getSemantics(
              tester.reviewControl(ReviewIds.commentLine('v6-best')),
            )
            .label,
        'Show line: Better, d5',
      );
      await tester.tapReview(ReviewIds.commentLine('v6-best'));

      // The better move is on the board instead of the played one.
      expect(tester.boardSquareLabel('d5'), 'd5, black pawn');
      expect(tester.boardSquareLabel('d7'), 'd7, empty');
      expect(tester.boardSquareLabel('b6'), 'b6, empty');
      expect(tester.boardSquareLabel('b7'), 'b7, black pawn');
      expect(_board(tester).glyphs, isEmpty);
      expect(tester.reviewControl(ReviewIds.commentCard), findsNothing);
      expect(
        find.text('Better  Best continuation', findRichText: true),
        findsOneWidget,
      );
      expect(tester.reviewControl(ReviewIds.next), findsNothing);

      // Where the line ends up: in words, with the number small beside it.
      expect(
        find.textContaining('White is slightly better', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('+0.4', findRichText: true), findsOneWidget);

      await tester.tapReview(ReviewIds.lineNext);
      expect(tester.boardSquareLabel('d5'), 'd5, white pawn'); // exd5
      await tester.tapReview(ReviewIds.lineNext);
      expect(tester.boardSquareLabel('d5'), 'd5, black queen'); // Qxd5
      await tester.tapReview(ReviewIds.linePrevious);
      expect(tester.boardSquareLabel('d5'), 'd5, white pawn');

      await tester.tapReview(ReviewIds.lineMove(6));
      expect(tester.reviewState.line!.index, 6);
      expect(tester.boardSquareLabel('d2'), 'd2, white knight'); // Nbd2
      expect(
        tester.getSemantics(tester.reviewControl(ReviewIds.lineNext)),
        isSemantics(isButton: true, isEnabled: false, hasEnabledState: true),
      );

      await tester.tapReview(ReviewIds.lineExit);
      expect(tester.reviewState.line, isNull);
      expect(tester.boardSquareLabel('b6'), 'b6, black pawn');
      expect(tester.boardSquareLabel('d5'), 'd5, empty');
      expect(tester.reviewControl(ReviewIds.commentCard), findsOneWidget);
    });

    testWidgets('the punishment starts after the played move', (tester) async {
      await pumpReview(tester);
      await tester.tapReview(ReviewIds.nextMoment);
      await tester.tapReview(ReviewIds.commentLine('v6-refutation'));
      expect(tester.boardSquareLabel('b6'), 'b6, black pawn');
      expect(tester.boardSquareLabel('d4'), 'd4, white pawn');
      expect(
        find.textContaining('Why the move fails', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('a tap on the graph leaves the line', (tester) async {
      await pumpReview(tester);
      await tester.tapReview(ReviewIds.nextMoment);
      await tester.tapReview(ReviewIds.commentLine('v6-best'));
      await tester.tapAt(tester.getCenter(find.byType(EvalGraph)));
      await tester.pumpAndSettle();
      expect(tester.reviewState.line, isNull);
      expect(tester.reviewState.ply, 40);
    });
  });

  group('feedback', () {
    testWidgets('thumbs call the sink and toggle', (tester) async {
      final harness = await pumpReview(tester);
      final semantics = tester.ensureSemantics();
      await tester.tapReview(ReviewIds.nextMoment);
      final id = tester.reviewController.document!.nodeAt(6)!.commentIds.single;

      expect(
        tester.getSemantics(tester.reviewControl(ReviewIds.thumbUp)),
        isSemantics(
          label: 'Helpful',
          isButton: true,
          hasToggledState: true,
          isToggled: false,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );

      await tester.tapReview(ReviewIds.thumbUp);
      expect(harness.sink.calls, [(id, CommentRating.up)]);
      expect(
        tester.getSemantics(tester.reviewControl(ReviewIds.thumbUp)),
        isSemantics(
          label: 'Helpful',
          isButton: true,
          hasToggledState: true,
          isToggled: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      expect(find.byIcon(Icons.thumb_up), findsOneWidget);

      await tester.tapReview(ReviewIds.thumbDown);
      expect(harness.sink.calls.last, (id, CommentRating.down));
      expect(find.byIcon(Icons.thumb_up), findsNothing);
      expect(find.byIcon(Icons.thumb_down), findsOneWidget);

      await tester.tapReview(ReviewIds.thumbDown);
      expect(harness.sink.calls.last, (id, null));
      expect(find.byIcon(Icons.thumb_down), findsNothing);
      semantics.dispose();
    });

    testWidgets('ratings from the repository are shown', (tester) async {
      final result = parseFixture(kFortyMoveGame);
      final id = (result as AnalysisSupported).document
          .nodeAt(6)!
          .commentIds
          .single;
      await pumpReview(
        tester,
        result: result,
        myFeedback: {id: CommentRating.down},
      );
      await tester.tapReview(ReviewIds.nextMoment);
      expect(find.byIcon(Icons.thumb_down), findsOneWidget);
    });

    testWidgets('a failing sink rolls the thumb back and says so', (
      tester,
    ) async {
      final harness = await pumpReview(tester);
      harness.sink.failWith = StateError('offline');
      await tester.tapReview(ReviewIds.nextMoment);

      await tester.tapReview(ReviewIds.thumbUp);
      expect(find.byIcon(Icons.thumb_up), findsNothing);
      expect(find.text('Your rating could not be saved.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('moves tab', () {
    testWidgets('two columns with glyphs and comment markers; a tap jumps', (
      tester,
    ) async {
      await pumpReview(tester);
      await tester.tapReview(ReviewIds.tabMoves);
      expect(find.byType(MovesTab), findsOneWidget);

      expect(
        tester.getSemantics(tester.reviewControl(ReviewIds.move(6))).label,
        '3... b6, Mistake, with coach comment',
      );
      expect(
        tester.getSemantics(tester.reviewControl(ReviewIds.move(1))).label,
        '1. e4, Book move',
      );
      expect(find.text('b6?', findRichText: true), findsOneWidget);

      await tester.tapReview(ReviewIds.move(6));
      expect(tester.reviewState.ply, 6);
      expect(tester.reviewState.tab, ReviewTab.moves);
      expect(tester.boardSquareLabel('b6'), 'b6, black pawn');
      expect(
        tester.getSemantics(tester.reviewControl(ReviewIds.move(6))),
        isSemantics(
          label: '3... b6, Mistake, with coach comment',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
    });

    testWidgets('a praised move carries "!"', (tester) async {
      await pumpReview(tester);
      await tester.tapReview(ReviewIds.tabMoves);
      expect(
        tester.getSemantics(tester.reviewControl(ReviewIds.move(34))).label,
        '17... Ba8, Strong move, with coach comment',
      );
    });

    testWidgets('the current move is scrolled into view', (tester) async {
      await pumpReview(tester);
      tester.reviewController.goTo(78);
      await tester.tapReview(ReviewIds.tabMoves);
      final panel = tester.getRect(find.byType(MovesTab));
      final cell = tester.getRect(tester.reviewControl(ReviewIds.move(78)));
      expect(panel.contains(cell.center), isTrue);

      // Stepping keeps it in view.
      await tester.tapReview(ReviewIds.first);
      final first = tester.getRect(tester.reviewControl(ReviewIds.move(1)));
      expect(panel.contains(first.center), isTrue);
    });
  });

  group('summary tab', () {
    testWidgets('three lessons, the table, and chips that jump', (
      tester,
    ) async {
      await pumpReview(tester);
      await tester.tapReview(ReviewIds.tabSummary);

      expect(find.text('What to take away'), findsOneWidget);
      for (final number in [1, 2, 3]) {
        expect(tester.reviewControl(ReviewIds.lesson(number)), findsOneWidget);
      }
      expect(find.text('Fight for the centre early'), findsOneWidget);
      expect(find.text('Move 3... b6'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Blunder'),
        200,
        scrollable: find.descendant(
          of: find.byType(SummaryTab),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Move quality'), findsOneWidget);
      expect(find.text('91.6 %'), findsOneWidget);
      expect(find.text('89.5 %'), findsOneWidget);

      await tester.tapReview(ReviewIds.lessonEvidence(3, 36));
      expect(tester.reviewState.ply, 36);
      expect(tester.reviewState.tab, ReviewTab.coach);
      expect(find.text('Recapture first'), findsOneWidget);
    });
  });

  group('graph', () {
    testWidgets('a tap and a drag jump to the ply under the finger', (
      tester,
    ) async {
      await pumpReview(tester);
      final rect = tester.getRect(find.byType(EvalGraph));
      Offset at(int ply) =>
          Offset(rect.left + rect.width * ply / 80, rect.center.dy);

      await tester.tapAt(at(22));
      await tester.pumpAndSettle();
      expect(tester.reviewState.ply, 22);
      expect(find.text('A cramping pawn push was on'), findsOneWidget);

      await tester.tapAt(at(80) - const Offset(1, 0));
      await tester.pumpAndSettle();
      expect(tester.reviewState.ply, 80);

      await tester.dragFrom(at(60), at(10) - at(60));
      await tester.pumpAndSettle();
      expect(tester.reviewState.ply, 10);
    });

    testWidgets('maps offsets to plies', (tester) async {
      expect(EvalGraph.plyAt(0, 300, 80), 0);
      expect(EvalGraph.plyAt(300, 300, 80), 80);
      expect(EvalGraph.plyAt(150, 300, 80), 40);
      expect(EvalGraph.plyAt(-20, 300, 80), 0);
      expect(EvalGraph.plyAt(900, 300, 80), 80);
      expect(EvalGraph.plyAt(10, 0, 80), 0);
      expect(EvalGraph.plyAt(10, 300, 0), 0);
    });

    testWidgets('a screen reader gets words and can step', (tester) async {
      await pumpReview(tester);
      final semantics = tester.ensureSemantics();
      tester.reviewController.goTo(6);
      await tester.pumpAndSettle();
      final node = tester.getSemantics(tester.reviewControl(ReviewIds.graph));
      expect(node.label, 'Evaluation graph');
      expect(node.value, '3... b6, White is clearly better');
      expect(node.increasedValue, startsWith('4. '));
      semantics.dispose();
    });
  });

  group('board options', () {
    testWidgets('arrows can be switched, the board can be flipped', (
      tester,
    ) async {
      await pumpReview(tester);
      await tester.tapReview(ReviewIds.nextMoment);
      expect(_arrowStyles(tester), contains(BoardArrowStyle.best));

      await tester.tap(find.byTooltip('Board options'));
      await tester.pumpAndSettle();
      await tester.tap(_menuItem('Show best move'));
      await tester.pumpAndSettle();
      expect(_arrowStyles(tester), {BoardArrowStyle.danger});

      await tester.tap(find.byTooltip('Board options'));
      await tester.pumpAndSettle();
      await tester.tap(_menuItem('Show played move'));
      await tester.pumpAndSettle();
      expect(_arrowStyles(tester), {
        BoardArrowStyle.danger,
        BoardArrowStyle.hint,
      });

      await tester.tap(find.byTooltip('Board options'));
      await tester.pumpAndSettle();
      await tester.tap(_menuItem('Flip board'));
      await tester.pumpAndSettle();
      expect(_board(tester).orientation.name, 'white');
    });
  });

  group('other states', () {
    testWidgets('newer major version: board and moves with a banner', (
      tester,
    ) async {
      await pumpReview(tester, fixture: kNewerMajor);

      expect(tester.reviewControl(ReviewIds.updateBanner), findsOneWidget);
      expect(find.text('Update the app to see this analysis.'), findsOneWidget);
      expect(find.byType(BoardView), findsOneWidget);
      expect(find.byType(MovesTab), findsOneWidget);
      expect(find.byType(EvalGraph), findsNothing);
      expect(tester.reviewControl(ReviewIds.tabCoach), findsNothing);
      expect(tester.reviewControl(ReviewIds.nextMoment), findsNothing);

      await tester.tapReview(ReviewIds.next);
      expect(tester.reviewState.ply, 1);
      await tester.tapReview(ReviewIds.move(3));
      expect(tester.reviewState.ply, 3);
      expect(
        _board(tester).position.fen,
        tester.reviewController.partial!.moves[2].positionAfter.fen,
      );
    });

    testWidgets('an invalid document is an error with retry', (tester) async {
      final harness = await pumpReview(
        tester,
        patch: (json) => json['schema'] = 'something.else',
      );
      expect(find.byType(ErrorRetry), findsOneWidget);
      expect(find.text('This analysis could not be read.'), findsOneWidget);
      expect(find.byType(BoardView), findsNothing);

      harness.repository.data = ReviewData(result: parseFixture(kShortGame));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(BoardView), findsOneWidget);
      expect(harness.repository.loads, hasLength(2));
    });

    testWidgets('a load error is an error with retry', (tester) async {
      final harness = await pumpReview(
        tester,
        loadError: StateError('offline'),
      );
      expect(find.byType(ErrorRetry), findsOneWidget);
      expect(find.byType(BoardView), findsNothing);

      harness.repository.error = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorRetry), findsNothing);
      expect(find.byType(CoachTab), findsOneWidget);
    });

    testWidgets('a game that ends in mate says so in words', (tester) async {
      await pumpReview(tester, fixture: kShortGame);
      await tester.tapReview(ReviewIds.last);
      expect(find.text('Checkmate. White wins'), findsOneWidget);
      tester.reviewController.goTo(16);
      await tester.pumpAndSettle();
      expect(find.text('Mate in 3 for White'), findsOneWidget);
      expect(find.text('??  Blunder'), findsOneWidget);
    });
  });
}
