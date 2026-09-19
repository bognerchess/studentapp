// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analysis/analysis_board_mapping.dart';
import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/analysis/analysis_view.dart';
import 'package:bogner_chess/core/chess/chess_models.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

import 'analysis_fixtures.dart';

void main() {
  late AnalysisDocument short;
  late AnalysisDocument forty;

  setUpAll(() {
    short = parseSupported(fixtureJson('short-game.json')).document;
    forty = parseSupported(fixtureJson('forty-move-game.json')).document;
  });

  group('evalSeries', () {
    test('is indexed by ply, starts with the start position', () {
      final series = short.evalSeries();
      expect(series, hasLength(22));
      expect(series.first, 35);
      expect(series[1], 37);
      expect(series[10], 90);
      expect(series[15], 190);
      // Mate for White from ply 16 on, checkmate at the end.
      expect(series.sublist(16), everyElement(1000));
    });

    test('clamps to the cap and maps mates to it', () {
      final series = forty.evalSeries(cap: 600);
      expect(series, hasLength(81));
      expect(series.every((v) => v >= -600 && v <= 600), isTrue);
      expect(series.last, 600);
      expect(series[29], -180);
      final wide = forty.evalSeries(cap: 100000);
      expect(wide[60], 100000, reason: 'mate in 8 for White');
      expect(wide[59], 938);
    });

    test('a mate for Black is the negative cap', () {
      final json = fixtureJson('short-game.json');
      rawNode(json, 4)['eval_after'] = {'mate': -5};
      rawNode(json, 5)['eval_before'] = {'mate': -5};
      expect(parseSupported(json).document.evalSeries()[4], -1000);
    });
  });

  group('glyphFor', () {
    test('by classification', () {
      expect(short.glyphFor(short.nodeAt(16)!), AnalysisGlyph.blunder);
      expect(short.glyphFor(short.nodeAt(10)!), AnalysisGlyph.mistake);
      expect(short.glyphFor(short.nodeAt(13)!), AnalysisGlyph.inaccuracy);
      expect(short.glyphFor(short.nodeAt(1)!), isNull, reason: 'book');
      expect(short.glyphFor(short.nodeAt(9)!), isNull, reason: 'good');
      expect(short.glyphFor(short.nodeAt(11)!), isNull, reason: 'best');
      expect(AnalysisGlyph.values.map((g) => g.symbol), ['!', '?!', '?', '??']);
    });

    test('"!" only for a positive moment', () {
      expect(forty.glyphFor(forty.nodeAt(34)!), AnalysisGlyph.good);
      final glyphs = {
        for (final node in forty.nodes) node.ply: ?forty.glyphFor(node),
      };
      expect(
        glyphs.entries
            .where((e) => e.value == AnalysisGlyph.good)
            .map((e) => e.key),
        [34],
      );
      // Every mistake and blunder has one, whether or not it is a moment.
      expect(
        glyphs.values.where((g) => g == AnalysisGlyph.blunder),
        hasLength(3),
      );
      expect(
        glyphs.values.where((g) => g == AnalysisGlyph.mistake),
        hasLength(6),
      );
      expect(
        glyphs.values.where((g) => g == AnalysisGlyph.inaccuracy),
        hasLength(11),
      );
    });

    test('a positive moment whose comment was dropped has no glyph', () {
      final json = fixtureJson('forty-move-game.json');
      rawComment(json, 34)['type'] = 'applause';
      final doc = parseSupported(json).document;
      expect(doc.nodeAt(34)!.isCritical, isTrue);
      expect(doc.glyphFor(doc.nodeAt(34)!), isNull);
    });
  });

  group('arrowsFor', () {
    test('best first, then played', () {
      final node = short.nodeAt(10)!;
      expect(arrowsFor(node), const [
        AnalysisArrow(
          from: Square.f6,
          to: Square.e4,
          kind: AnalysisArrowKind.best,
        ),
        AnalysisArrow(
          from: Square.e7,
          to: Square.e5,
          kind: AnalysisArrowKind.played,
        ),
      ]);
      expect(
        arrowsFor(node, showPlayed: false).single.kind,
        AnalysisArrowKind.best,
      );
      expect(
        arrowsFor(node, showBest: false).single.kind,
        AnalysisArrowKind.played,
      );
      expect(arrowsFor(node, showBest: false, showPlayed: false), isEmpty);
      expect(
        arrowsFor(node).every((a) => a.board == ArrowBoard.before),
        isTrue,
      );
    });

    test('no best arrow when the played move was the best', () {
      expect(
        arrowsFor(short.nodeAt(11)!).single.kind,
        AnalysisArrowKind.played,
      );
      expect(arrowsFor(short.nodeAt(11)!, showPlayed: false), isEmpty);
    });
  });

  group('arrowsForComment', () {
    test('all, and per board', () {
      final comment = short.commentsAt(10).single;
      expect(arrowsForComment(comment).map((a) => a.kind), [
        AnalysisArrowKind.played,
        AnalysisArrowKind.best,
        AnalysisArrowKind.threat,
      ]);
      expect(
        arrowsForComment(comment, board: ArrowBoard.before).map((a) => a.kind),
        [AnalysisArrowKind.played, AnalysisArrowKind.best],
      );
      final threat = arrowsForComment(comment, board: ArrowBoard.after).single;
      expect(threat.kind, AnalysisArrowKind.threat);
      expect((threat.from, threat.to), (Square.d4, Square.e5));
      expect(threat.board, ArrowBoard.after);
      expect(threat.toString(), 'AnalysisArrow(d4e5, threat)');
    });
  });

  group('comments and moments', () {
    test('commentsAt', () {
      expect(short.commentsAt(10).single.title, 'Opening the centre too early');
      expect(short.commentsAt(11), isEmpty);
      expect(short.commentsAt(0), isEmpty);
      expect(short.commentsAt(99), isEmpty);
      expect(short.commentsOf(short.nodeAt(12)!).single.ply, 12);
    });

    test('criticalPlies', () {
      expect(short.criticalPlies, [10, 12, 16]);
      expect(forty.criticalPlies, [6, 10, 18, 22, 30, 34, 36, 38]);
    });

    test('nextCritical and previousCritical', () {
      expect(short.nextCritical(0), 10);
      expect(short.nextCritical(9), 10);
      expect(short.nextCritical(10), 12);
      expect(short.nextCritical(15), 16);
      expect(short.nextCritical(16), isNull);
      expect(short.nextCritical(-5), 10);
      expect(short.previousCritical(0), isNull);
      expect(short.previousCritical(10), isNull);
      expect(short.previousCritical(11), 10);
      expect(short.previousCritical(16), 12);
      expect(short.previousCritical(21), 16);
      expect(short.previousCritical(1000), 16);
    });
  });

  group('classificationCounts', () {
    test('per side, every classification present, in table order', () {
      final white = short.classificationCounts(Side.white);
      final black = short.classificationCounts(Side.black);
      expect(white.keys, MoveClassification.values);
      expect(white, {
        MoveClassification.book: 4,
        MoveClassification.best: 5,
        MoveClassification.good: 1,
        MoveClassification.inaccuracy: 1,
        MoveClassification.mistake: 0,
        MoveClassification.blunder: 0,
        MoveClassification.unknown: 0,
      });
      expect(black, {
        MoveClassification.book: 4,
        MoveClassification.best: 3,
        MoveClassification.good: 0,
        MoveClassification.inaccuracy: 0,
        MoveClassification.mistake: 2,
        MoveClassification.blunder: 1,
        MoveClassification.unknown: 0,
      });
      expect(white.values.reduce((a, b) => a + b), 11);
      expect(black.values.reduce((a, b) => a + b), 10);
    });

    test('forty moves', () {
      final white = forty.classificationCounts(Side.white);
      final black = forty.classificationCounts(Side.black);
      expect(white[MoveClassification.best], 23);
      expect(white[MoveClassification.blunder], 1);
      expect(black[MoveClassification.blunder], 2);
      expect(black[MoveClassification.inaccuracy], 5);
      expect(forty.accuracyOf(Side.white), 91.6);
      expect(forty.accuracyOf(Side.black), 89.5);
    });
  });

  group('board mapping', () {
    test('glyphs', () {
      expect(AnalysisGlyph.good.toBoardGlyph(), BoardGlyph.good);
      expect(AnalysisGlyph.inaccuracy.toBoardGlyph(), BoardGlyph.inaccuracy);
      expect(AnalysisGlyph.mistake.toBoardGlyph(), BoardGlyph.mistake);
      expect(AnalysisGlyph.blunder.toBoardGlyph(), BoardGlyph.blunder);
      for (final glyph in AnalysisGlyph.values) {
        expect(glyph.toBoardGlyph().symbol, glyph.symbol);
      }
    });

    test('boardGlyphsFor puts the glyph on the destination square', () {
      expect(short.boardGlyphsFor(short.nodeAt(16)!), {
        Square.e4: BoardGlyph.blunder,
      });
      expect(short.boardGlyphFor(short.nodeAt(10)!), BoardGlyph.mistake);
      expect(short.boardGlyphsFor(short.nodeAt(1)!), isEmpty);
      expect(forty.boardGlyphsFor(forty.nodeAt(34)!), {
        Square.a8: BoardGlyph.good,
      });
    });

    test(
      'a castling move sent as king-takes-rook gets its glyph on the king',
      () {
        final json = fixtureJson('short-game.json');
        rawNode(json, 15)
          ..['uci'] = 'e1a1'
          ..['classification'] = 'inaccuracy';
        final doc = parseSupported(json).document;
        expect(doc.boardGlyphsFor(doc.nodeAt(15)!), {
          Square.c1: BoardGlyph.inaccuracy,
        });
      },
    );

    test('arrow styles: best green, played amber, threat red', () {
      final node = short.nodeAt(10)!;
      expect(boardArrowsFor(node), const [
        BoardArrow(from: Square.f6, to: Square.e4),
        BoardArrow(from: Square.e7, to: Square.e5, style: BoardArrowStyle.hint),
      ]);
      expect(boardArrowsFor(node, showPlayed: false), hasLength(1));
      final comment = short.commentsAt(10).single;
      expect(boardArrowsForComment(comment).map((a) => a.style), [
        BoardArrowStyle.hint,
        BoardArrowStyle.best,
        BoardArrowStyle.danger,
      ]);
      expect(boardArrowsForComment(comment, board: ArrowBoard.after), const [
        BoardArrow(
          from: Square.d4,
          to: Square.e5,
          style: BoardArrowStyle.danger,
        ),
      ]);
    });
  });
}
