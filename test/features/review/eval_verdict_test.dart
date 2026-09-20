// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/l10n/generated/app_localizations.dart';
import 'package:bogner_chess/features/review/domain/eval_verdict.dart';
import 'package:bogner_chess/features/review/ui/review_l10n.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EvalVerdict', () {
    test('centipawn thresholds, for both sides', () {
      EvalVerdict of(int cp) => EvalVerdict.of(EvalScore.cp(cp));

      expect(of(0), const EvalVerdict(EvalLevel.equal));
      expect(of(40), const EvalVerdict(EvalLevel.equal));
      expect(of(-40), const EvalVerdict(EvalLevel.equal));
      expect(of(41), const EvalVerdict(EvalLevel.slight, side: Side.white));
      expect(of(-120), const EvalVerdict(EvalLevel.slight, side: Side.black));
      expect(of(121), const EvalVerdict(EvalLevel.clear, side: Side.white));
      expect(of(-300), const EvalVerdict(EvalLevel.clear, side: Side.black));
      expect(of(301), const EvalVerdict(EvalLevel.winning, side: Side.white));
      expect(of(-2500), const EvalVerdict(EvalLevel.winning, side: Side.black));
    });

    test('mate and checkmate', () {
      expect(
        EvalVerdict.of(const EvalScore.mate(3)),
        const EvalVerdict(EvalLevel.mate, side: Side.white, mateIn: 3),
      );
      expect(
        EvalVerdict.of(const EvalScore.mate(-1)),
        const EvalVerdict(EvalLevel.mate, side: Side.black, mateIn: 1),
      );
      expect(
        EvalVerdict.of(const EvalScore.mate(0, deliveredBy: Side.black)),
        const EvalVerdict(EvalLevel.checkmate, side: Side.black),
      );
      expect(
        EvalVerdict.of(const EvalScore.mate(0)),
        const EvalVerdict(EvalLevel.checkmate),
      );
    });

    test('the graph value is odd, monotonic and inside -1..1', () {
      expect(graphValueOf(0), 0);
      expect(graphValueOf(-250), closeTo(-graphValueOf(250), 1e-12));
      var last = -1.0;
      for (var cp = -1000; cp <= 1000; cp += 50) {
        final value = graphValueOf(cp);
        expect(value, greaterThan(last));
        expect(value.abs(), lessThan(1));
        last = value;
      }
      // A pawn is visible, ten pawns is nearly the edge.
      expect(graphValueOf(100), greaterThan(0.15));
      expect(graphValueOf(1000), greaterThan(0.9));
    });
  });

  group('words', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final de = lookupAppLocalizations(const Locale('de'));

    test('evaluations never show centipawns', () {
      expect(en.evalWords(const EvalScore.cp(12)), 'Equal position');
      expect(en.evalWords(const EvalScore.cp(80)), 'White is slightly better');
      expect(en.evalWords(const EvalScore.cp(-200)), 'Black is clearly better');
      expect(en.evalWords(const EvalScore.cp(900)), 'White is winning');
      expect(en.evalWords(const EvalScore.mate(3)), 'Mate in 3 for White');
      expect(en.evalWords(const EvalScore.mate(-2)), 'Mate in 2 for Black');
      expect(
        en.evalWords(const EvalScore.mate(0, deliveredBy: Side.white)),
        'Checkmate. White wins',
      );
      expect(en.evalWords(const EvalScore.mate(0)), 'Checkmate');

      expect(de.evalWords(const EvalScore.cp(12)), 'Ausgeglichene Stellung');
      expect(
        de.evalWords(const EvalScore.cp(-80)),
        'Schwarz steht etwas besser',
      );
      expect(de.evalWords(const EvalScore.cp(200)), 'Weiss steht klar besser');
      expect(
        de.evalWords(const EvalScore.cp(-900)),
        'Schwarz steht auf Gewinn',
      );
      expect(de.evalWords(const EvalScore.mate(3)), 'Matt in 3 für Weiss');
    });

    test('classifications, praised moves and themes', () {
      expect(en.classificationWords(MoveClassification.blunder), 'Blunder');
      expect(de.classificationWords(MoveClassification.blunder), 'Patzer');
      expect(de.classificationWords(MoveClassification.book), 'Theoriezug');
      expect(
        en.classificationWords(MoveClassification.best, praised: true),
        'Strong move',
      );
      expect(en.classificationWords(MoveClassification.unknown), 'Move');

      expect(en.themeWords('king_safety'), 'King safety');
      expect(de.themeWords('central_break'), 'Zentrumshebel');
      // No chip at all rather than English snake case.
      expect(en.themeWords('unknown'), isNull);
      expect(de.themeWords('zugzwang_v2'), isNull);
    });

    test('every theme of the contract has a word in both languages', () {
      const themes = [
        'opening', 'development', 'central_break', 'king_safety', 'tactics',
        'hanging_piece', 'calculation', 'piece_activity', 'pawn_structure',
        'endgame', 'material_conversion', //
      ];
      for (final theme in themes) {
        expect(en.themeWords(theme), isNot(anyOf(isNull, 'Chess')));
        expect(de.themeWords(theme), isNot(anyOf(isNull, 'Schach')));
      }
    });

    test('results', () {
      expect(en.resultWords('1-0', GameResult.unfinished), '1–0');
      expect(en.resultWords('1/2-1/2', GameResult.unfinished), '½–½');
      expect(en.resultWords(null, GameResult.blackWins), '0–1');
      expect(en.resultWords('*', GameResult.unfinished), isNull);
    });
  });
}
