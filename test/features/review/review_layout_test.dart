// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/chess/board_view.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/features/review/domain/review_controller.dart';
import 'package:bogner_chess/features/review/domain/review_repository.dart';
import 'package:bogner_chess/features/review/ui/review_ids.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/board_tester.dart';
import '../../helpers/pump_app.dart';
import 'pump_review.dart';

/// Walks through every state of the screen. A RenderFlex overflow is a
/// FlutterError and fails the test on its own; takeException makes the
/// intent explicit.
Future<void> _walk(WidgetTester tester) async {
  Future<void> check(String where) async {
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: where);
  }

  final controller = tester.reviewController;
  await check('start position');

  // Every key moment, its comment scrolled to the end, and each of its lines.
  while (controller.nextMoment()) {
    await check('moment ${controller.state.ply}');
    final node = controller.document!.nodeAt(controller.state.ply)!;
    for (final variation in node.variations) {
      final button = tester.reviewControl(ReviewIds.commentLine(variation.id));
      if (button.evaluate().isEmpty) continue;
      await tester.tapReview(ReviewIds.commentLine(variation.id));
      await check('line ${variation.id}');
      controller.lineGoTo(variation.moves.length);
      await check('end of line ${variation.id}');
      await tester.tapReview(ReviewIds.lineExit);
    }
    await tester.tapReview(ReviewIds.thumbUp);
    await check('rated ${controller.state.ply}');
  }

  // Moves without a comment: a plain one, the last one.
  controller.goTo(1);
  await check('ply 1');
  controller.last();
  await check('last ply');

  await tester.tapReview(ReviewIds.tabMoves);
  await check('moves tab');
  controller.first();
  await check('moves tab, start');

  await tester.tapReview(ReviewIds.tabSummary);
  await check('summary tab');
  final scrollable = find
      .descendant(
        of: find.bySemanticsIdentifier(ReviewIds.lesson(1)),
        matching: find.byType(Text),
      )
      .first;
  await tester.dragFrom(tester.getCenter(scrollable), const Offset(0, -2000));
  await check('summary tab, scrolled');
}

void main() {
  setUp(() => Log.sink = (_) {});
  tearDown(Log.resetSink);

  group('no overflow on the smallest iPhone at text scale 1.3', () {
    for (final brightness in Brightness.values) {
      testWidgets('German, texts of maximum length, ${brightness.name}', (
        tester,
      ) async {
        await pumpReview(
          tester,
          patch: stretchTexts,
          header: const GameHeaderInfo(
            white: 'Maximilian Hohenzollern-Sigmaringen',
            black: 'Friederike von Schwarzenberg',
            result: '1/2-1/2',
          ),
          locale: const Locale('de'),
          brightness: brightness,
          textScale: 1.3,
          screen: kIphoneSe,
        );
        await _walk(tester);
      });
    }

    testWidgets('English, the real fixture', (tester) async {
      await pumpReview(tester, textScale: 1.3, screen: kIphoneSe);
      await _walk(tester);
    });

    testWidgets('newer major version, German', (tester) async {
      await pumpReview(
        tester,
        fixture: kNewerMajor,
        locale: const Locale('de'),
        textScale: 1.3,
        screen: kIphoneSe,
      );
      expect(
        find.text('Aktualisiere die App, um diese Analyse zu sehen.'),
        findsOneWidget,
      );
      tester.reviewController.last();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('even at text scale 2.0', (tester) async {
      await pumpReview(
        tester,
        patch: stretchTexts,
        locale: const Locale('de'),
        textScale: 2,
        screen: kIphoneSe,
      );
      await _walk(tester);
    });
  });

  group('layout', () {
    testWidgets('the board fills the width of a current iPhone', (
      tester,
    ) async {
      await pumpReview(tester);
      final board = tester.getSize(find.byType(BoardView));
      expect(board.width, board.height);
      expect(board.width, greaterThan(kIphone17Pro.width * 0.9));
    });

    testWidgets('on the smallest iPhone it gives height to the coach', (
      tester,
    ) async {
      await pumpReview(tester, screen: kIphoneSe);
      final board = tester.getSize(find.byType(BoardView));
      expect(board.width, inInclusiveRange(280, kIphoneSe.width));
      tester.reviewController.nextMoment();
      await tester.pumpAndSettle();
      final card = tester.getRect(tester.reviewControl(ReviewIds.commentCard));
      final controls = tester.getRect(tester.reviewControl(ReviewIds.next));
      // Title and the first lines of the comment are above the controls.
      expect(controls.top - card.top, greaterThan(140));
      // The thumbs are on screen without scrolling.
      expect(
        tester.getRect(tester.reviewControl(ReviewIds.thumbUp)).bottom,
        lessThan(controls.top),
      );
    });

    testWidgets('the step buttons are at the bottom edge, 44 points or more', (
      tester,
    ) async {
      await pumpReview(tester);
      for (final id in [
        ReviewIds.previousMoment,
        ReviewIds.first,
        ReviewIds.previous,
        ReviewIds.next,
        ReviewIds.last,
        ReviewIds.nextMoment,
      ]) {
        final rect = tester.getRect(tester.reviewControl(id));
        expect(rect.width, greaterThanOrEqualTo(44), reason: id);
        expect(rect.height, greaterThanOrEqualTo(44), reason: id);
        expect(rect.bottom, greaterThan(kIphone17Pro.height - 60), reason: id);
      }
    });
  });

  group('German', () {
    testWidgets('the whole screen speaks German', (tester) async {
      await pumpReview(tester, locale: const Locale('de'));
      expect(find.text('Coach'), findsOneWidget);
      expect(find.text('Züge'), findsOneWidget);
      expect(find.text('Fazit'), findsOneWidget);
      expect(find.text('Ausgangsstellung'), findsOneWidget);
      expect(find.text('Erster Schlüsselmoment'), findsOneWidget);
      expect(tester.boardSquareLabel('e2'), 'e2, weisser Bauer');

      await tester.tapReview(ReviewIds.nextMoment);
      expect(find.text('?  Fehler'), findsOneWidget);
      expect(find.text('Zentrumshebel'), findsOneWidget);
      expect(find.text('Weiss steht klar besser'), findsOneWidget);
      expect(find.text('KI-generiert. Kann Fehler enthalten.'), findsOneWidget);
      expect(
        tester.getSemantics(tester.reviewControl(ReviewIds.thumbDown)).label,
        'Nicht hilfreich',
      );

      await tester.tapReview(ReviewIds.commentLine('v6-best'));
      expect(find.text('Zurück zur Partie'), findsOneWidget);
      expect(
        find.textContaining('Beste Fortsetzung', findRichText: true),
        findsOneWidget,
      );
      await tester.tapReview(ReviewIds.lineExit);

      await tester.tapReview(ReviewIds.tabSummary);
      expect(find.text('Das nimmst du mit'), findsOneWidget);
      expect(find.text('Zug 3... b6'), findsOneWidget);
      expect(tester.reviewState.tab, ReviewTab.summary);
    });
  });
}
