// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analysis/analysis_document.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EvalScore', () {
    test('centipawns', () {
      const score = EvalScore.cp(35);
      expect(score.cp, 35);
      expect(score.mate, isNull);
      expect(score.isMate, isFalse);
      expect(score.isCheckmate, isFalse);
      expect(score.mateWinner, isNull);
      expect(score.pawns, 0.35);
    });

    test('mate', () {
      expect(const EvalScore.mate(3).mateWinner, Side.white);
      expect(const EvalScore.mate(-3).mateWinner, Side.black);
      expect(const EvalScore.mate(3).isMate, isTrue);
      expect(const EvalScore.mate(3).isCheckmate, isFalse);
      expect(const EvalScore.mate(3).pawns, isNull);
    });

    test('mate 0 takes its winner from the move that delivered it', () {
      const byBlack = EvalScore.mate(0, deliveredBy: Side.black);
      expect(byBlack.isCheckmate, isTrue);
      expect(byBlack.mateWinner, Side.black);
      expect(byBlack.whitePovCentipawnsClamped(), -1000);
      expect(const EvalScore.mate(0).mateWinner, isNull);
      expect(const EvalScore.mate(0).whitePovCentipawnsClamped(), 0);
      // The sign wins over the hint for a real mate distance.
      expect(
        const EvalScore.mate(2, deliveredBy: Side.black).mateWinner,
        Side.white,
      );
    });

    test('whitePovCentipawnsClamped', () {
      expect(const EvalScore.cp(35).whitePovCentipawnsClamped(), 35);
      expect(const EvalScore.cp(-35).whitePovCentipawnsClamped(), -35);
      expect(const EvalScore.cp(1000).whitePovCentipawnsClamped(), 1000);
      expect(const EvalScore.cp(4213).whitePovCentipawnsClamped(), 1000);
      expect(const EvalScore.cp(-4213).whitePovCentipawnsClamped(), -1000);
      expect(const EvalScore.cp(4213).whitePovCentipawnsClamped(cap: 500), 500);
      expect(const EvalScore.mate(7).whitePovCentipawnsClamped(), 1000);
      expect(const EvalScore.mate(-1).whitePovCentipawnsClamped(), -1000);
      expect(
        const EvalScore.mate(-1).whitePovCentipawnsClamped(cap: 800),
        -800,
      );
    });

    test('displayText', () {
      expect(const EvalScore.cp(0).displayText, '0.0');
      expect(const EvalScore.cp(4).displayText, '0.0');
      expect(const EvalScore.cp(-4).displayText, '0.0');
      expect(const EvalScore.cp(5).displayText, '+0.1');
      expect(const EvalScore.cp(35).displayText, '+0.4');
      expect(const EvalScore.cp(-35).displayText, '-0.4');
      expect(const EvalScore.cp(-120).displayText, '-1.2');
      expect(const EvalScore.cp(996).displayText, '+10.0');
      expect(const EvalScore.cp(1234).displayText, '+12.3');
      expect(const EvalScore.mate(3).displayText, 'M3');
      expect(const EvalScore.mate(-12).displayText, '-M12');
      expect(const EvalScore.mate(0, deliveredBy: Side.white).displayText, '#');
    });

    test('equality', () {
      expect(const EvalScore.cp(10), const EvalScore.cp(10));
      expect(const EvalScore.cp(10).hashCode, const EvalScore.cp(10).hashCode);
      expect(const EvalScore.cp(10), isNot(const EvalScore.cp(11)));
      expect(const EvalScore.cp(1), isNot(const EvalScore.mate(1)));
      expect(
        const EvalScore.mate(0, deliveredBy: Side.white),
        isNot(const EvalScore.mate(0, deliveredBy: Side.black)),
      );
      expect(const EvalScore.mate(2).toString(), 'EvalScore(M2)');
    });
  });

  group('open enums', () {
    test('known wire values', () {
      expect(MoveClassification.fromWire('book'), MoveClassification.book);
      expect(
        MoveClassification.fromWire('blunder'),
        MoveClassification.blunder,
      );
      expect(VariationKind.fromWire('best_line'), VariationKind.bestLine);
      expect(VariationKind.fromWire('refutation'), VariationKind.refutation);
      expect(VariationKind.fromWire('alternative'), VariationKind.alternative);
      expect(
        CommentType.fromWire('critical_moment'),
        CommentType.criticalMoment,
      );
      expect(
        CommentType.fromWire('positive_moment'),
        CommentType.positiveMoment,
      );
      expect(SquareRole.fromWire('key'), SquareRole.key);
      expect(ArrowRole.fromWire('threat'), ArrowRole.threat);
      expect(
        VerificationStatus.fromWire('fallback'),
        VerificationStatus.fallback,
      );
      expect(AnalysisPerspective.fromWire('white'), AnalysisPerspective.white);
      expect(GameResult.fromWire('1/2-1/2'), GameResult.draw);
      expect(GameResult.fromWire('0-1'), GameResult.blackWins);
    });

    test('wire values round-trip', () {
      for (final value in MoveClassification.values) {
        if (value == MoveClassification.unknown) continue;
        expect(MoveClassification.fromWire(value.wire), value);
      }
    });

    test('anything else is the catch-all, never an exception', () {
      for (final junk in <Object?>[
        null,
        '',
        'Book',
        'BLUNDER',
        7,
        <int>[],
        'unknown',
      ]) {
        expect(MoveClassification.fromWire(junk), MoveClassification.unknown);
        expect(VariationKind.fromWire(junk), VariationKind.unknown);
        expect(CommentType.fromWire(junk), CommentType.unknown);
        expect(SquareRole.fromWire(junk), SquareRole.unknown);
        expect(ArrowRole.fromWire(junk), ArrowRole.unknown);
        expect(VerificationStatus.fromWire(junk), VerificationStatus.unknown);
        expect(AnalysisPerspective.fromWire(junk), AnalysisPerspective.both);
        expect(GameResult.fromWire(junk), GameResult.unfinished);
      }
    });
  });
}
