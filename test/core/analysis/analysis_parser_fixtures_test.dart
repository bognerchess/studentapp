// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/analysis/analysis_view.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

import 'analysis_fixtures.dart';

void main() {
  group('short-game.json', () {
    late AnalysisSupported result;
    late AnalysisDocument doc;

    setUpAll(() {
      result = parseSupported(fixtureJson('short-game.json'));
      doc = result.document;
    });

    test('envelope', () {
      expect(result.warnings, isEmpty);
      expect(doc.schemaVersion, 1);
      expect(doc.schemaMinor, 0);
      expect(doc.analysisId, 'e88b7591-31db-4e32-98dc-b35f94c662cd');
      expect(doc.generatedAt, DateTime.utc(2026, 9, 19, 9, 12, 41));
      expect(doc.language, 'en');
      expect(doc.perspective, AnalysisPerspective.black);
      expect(doc.ratingBand, '1000-1200');
      expect(doc.engine.name, 'Stockfish 19');
      expect(doc.engine.humanModel, 'maia2-rapid');
      expect(doc.engine.hasHumanModel, isTrue);
      expect(doc.engine.pass1Nodes, 400000);
      expect(doc.engine.pass2Nodes, 3000000);
      expect(doc.engine.pass2MultiPv, 3);
      expect(doc.coach.model, 'gpt-4.1');
      expect(doc.coach.promptVersion, '1.0.0+3fa9c1d2');
      expect(doc.coach.promptSet, 'mobile-coach');
      expect(doc.result, GameResult.whiteWins);
      expect(doc.startFen, isNull);
      expect(doc.startPosition, Chess.initial);
      expect(doc.plyCount, 21);
      expect(doc.accuracyWhite, 97.2);
      expect(doc.accuracyBlack, 85.0);
    });

    test('a quiet node', () {
      final node = doc.nodeAt(1)!;
      expect(node.ply, 1);
      expect(node.moveNumber, 1);
      expect(node.side, Side.white);
      expect(node.san, 'e4');
      expect(node.uci, 'e2e4');
      expect(node.move, const NormalMove(from: Square.e2, to: Square.e4));
      expect(node.moveLabel, '1. e4');
      expect(node.evalBefore, const EvalScore.cp(35));
      expect(node.evalAfter, const EvalScore.cp(37));
      expect(node.winPctBefore, 54.7);
      expect(node.winPctAfter, 55.0);
      expect(node.winPctLoss, 0.0);
      expect(node.classification, MoveClassification.book);
      expect(node.isCritical, isFalse);
      expect(node.best, isNull);
      expect(node.human, isNull);
      expect(node.variations, isEmpty);
      expect(node.commentIds, isEmpty);
      expect(node.positionBefore, Chess.initial);
      expect(node.positionAfter.fen, node.fenAfter);
    });

    test('a critical node with best move, human stats and variations', () {
      final node = doc.nodeAt(10)!;
      expect(node.moveLabel, '5... e5');
      expect(node.side, Side.black);
      expect(node.classification, MoveClassification.mistake);
      expect(node.classificationRaw, 'mistake');
      expect(node.isCritical, isTrue);
      expect(node.winPctLoss, 9.7);
      expect(node.best!.san, 'Nxe4');
      expect(node.best!.move, const NormalMove(from: Square.f6, to: Square.e4));
      expect(node.best!.eval, const EvalScore.cp(17));
      expect(node.human!.playedProb, 0.42);
      expect(node.human!.bestProb, 0.26);
      expect(node.commentIds, ['5bd21b6a-ec89-47a6-8a0a-c984f71ab247']);

      expect(node.variations.map((v) => v.id), [
        'v10-best',
        'v10-refutation',
        'v10-alt1',
      ]);
      expect(node.variations.map((v) => v.kind), [
        VariationKind.bestLine,
        VariationKind.refutation,
        VariationKind.alternative,
      ]);
      final best = node.variationById('v10-best')!;
      expect(best.startFen, node.fenBefore);
      expect(best.startPosition, node.positionBefore);
      expect(best.sans, ['Nxe4', 'Qxe4', 'Qd5', 'Qe3', 'Bf5', 'c4']);
      expect(best.eval, const EvalScore.cp(17));
      final refutation = node.variationById('v10-refutation')!;
      expect(refutation.startFen, node.fenAfter);
      expect(refutation.startPosition, node.positionAfter);
      expect(refutation.moves.first.san, 'dxe5');
      expect(node.variationById('nope'), isNull);
    });

    test('a comment', () {
      expect(doc.comments.map((c) => c.ply), [10, 12, 16]);
      expect(doc.commentsById.keys, doc.comments.map((c) => c.id));
      final comment = doc.comments.first;
      expect(comment.type, CommentType.criticalMoment);
      expect(comment.isPositive, isFalse);
      expect(comment.title, 'Opening the centre too early');
      expect(comment.text, startsWith('Playing e5 opens the position'));
      expect(comment.theme, 'king_safety');
      expect(comment.squares.map((s) => (s.square, s.role)), [
        (Square.e8, SquareRole.weak),
        (Square.e5, SquareRole.target),
      ]);
      expect(comment.arrows.map((a) => (a.from, a.to, a.role)), [
        (Square.e7, Square.e5, ArrowRole.played),
        (Square.f6, Square.e4, ArrowRole.best),
        (Square.d4, Square.e5, ArrowRole.threat),
      ]);
      expect(comment.lines.map((l) => (l.variationId, l.label)), [
        ('v10-best', 'Better'),
        ('v10-refutation', 'Punishment'),
      ]);
      expect(comment.movesMentioned, [
        'e5',
        'dxe5',
        'Nxe4',
        'Qxe4',
        'Qd5',
        'Bf5',
      ]);
      expect(comment.verificationStatus, VerificationStatus.passed);
      expect(comment.isFallback, isFalse);
    });

    test('lessons', () {
      expect(doc.lessons, hasLength(3));
      final lesson = doc.lessons.first;
      expect(lesson.id, 'c87383f4-b142-4de1-bc47-571849dc9b34');
      expect(lesson.title, 'Castle before you open the centre');
      expect(lesson.text, startsWith('Both big losses'));
      expect(lesson.evidencePlies, [10, 16]);
      expect(lesson.theme, 'king_safety');
    });

    test('mate scores, and mate 0 knows who delivered it', () {
      expect(doc.nodeAt(16)!.evalAfter, const EvalScore.mate(3));
      final last = doc.nodes.last;
      expect(last.san, 'Bd8#');
      expect(last.positionAfter.isCheckmate, isTrue);
      expect(last.evalAfter.isCheckmate, isTrue);
      expect(last.evalAfter.mateWinner, Side.white);
      expect(last.evalAfter.whitePovCentipawnsClamped(), 1000);
    });

    test('castling keeps the UCI form of the document and is playable', () {
      final node = doc.nodeAt(15)!;
      expect(node.san, 'O-O-O');
      expect(node.uci, 'e1c1');
      expect(node.move, const NormalMove(from: Square.e1, to: Square.c1));
      expect(node.positionBefore.play(node.move), node.positionAfter);
      expect(node.positionAfter.board.kingOf(Side.white), Square.c1);
    });

    test('the model is immutable', () {
      expect(() => doc.nodes.removeLast(), throwsUnsupportedError);
      expect(() => doc.comments.clear(), throwsUnsupportedError);
      expect(() => doc.commentsById.clear(), throwsUnsupportedError);
      expect(() => doc.lessons.clear(), throwsUnsupportedError);
      expect(() => doc.nodeAt(10)!.variations.clear(), throwsUnsupportedError);
      expect(() => doc.nodeAt(10)!.commentIds.clear(), throwsUnsupportedError);
      expect(
        () => doc.nodeAt(10)!.variations.first.moves.clear(),
        throwsUnsupportedError,
      );
      expect(() => doc.comments.first.arrows.clear(), throwsUnsupportedError);
      expect(
        () => doc.lessons.first.evidencePlies.clear(),
        throwsUnsupportedError,
      );
      expect(() => result.warnings.add('x'), throwsUnsupportedError);
    });

    test('positionAt clamps', () {
      expect(doc.positionAt(-3), doc.startPosition);
      expect(doc.positionAt(0), doc.startPosition);
      expect(doc.positionAt(1), doc.nodes.first.positionAfter);
      expect(doc.positionAt(99), doc.nodes.last.positionAfter);
      expect(doc.nodeAt(0), isNull);
      expect(doc.nodeAt(22), isNull);
    });
  });

  group('forty-move-game.json', () {
    late AnalysisDocument doc;

    setUpAll(() {
      final result = parseSupported(fixtureJson('forty-move-game.json'));
      expect(result.warnings, isEmpty);
      doc = result.document;
    });

    test('shape', () {
      expect(doc.plyCount, 80);
      expect(doc.comments, hasLength(8));
      expect(doc.ratingBand, '1200-1400');
      expect(doc.result, GameResult.whiteWins);
      expect(doc.nodes.where((n) => n.human != null), hasLength(75));
      expect(doc.nodes.where((n) => n.best == null), hasLength(26));
      expect(doc.nodes.expand((n) => n.variations), hasLength(24));
      // Resignation: the last eval is a mate distance, not mate 0.
      expect(doc.nodes.last.evalAfter, const EvalScore.mate(2));
      expect(doc.nodes.last.positionAfter.isCheckmate, isFalse);
    });

    test('the positive moment', () {
      final node = doc.nodeAt(34)!;
      expect(node.isCritical, isTrue);
      expect(node.classification, MoveClassification.best);
      expect(node.best, isNull);
      final comment = doc.commentsAt(34).single;
      expect(comment.type, CommentType.positiveMoment);
      expect(comment.isPositive, isTrue);
      // Its best line starts with the played move.
      final best = node.variationById('v34-best')!;
      expect(best.kind, VariationKind.bestLine);
      expect(best.moves.first.san, node.san);
      expect(comment.lines.map((l) => l.label), [
        'Played',
        'Tempting',
        'Natural',
      ]);
      expect(comment.arrows.single.role, ArrowRole.played);
    });

    test('both sides castle short with e1g1 and e8g8', () {
      expect(doc.nodeAt(9)!.uci, 'e1g1');
      expect(doc.nodeAt(9)!.positionAfter.board.kingOf(Side.white), Square.g1);
      expect(doc.nodeAt(32)!.uci, 'e8g8');
      expect(doc.nodeAt(32)!.positionAfter.board.kingOf(Side.black), Square.g8);
    });
  });

  group('fallback-case.json', () {
    late AnalysisDocument doc;

    setUpAll(() {
      final result = parseSupported(fixtureJson('fallback-case.json'));
      expect(result.warnings, isEmpty);
      doc = result.document;
    });

    test('no human model', () {
      expect(doc.plyCount, 33);
      expect(doc.engine.humanModel, 'unavailable');
      expect(doc.engine.hasHumanModel, isFalse);
      expect(doc.nodes.where((n) => n.human != null), isEmpty);
    });

    test('verification statuses', () {
      expect(doc.comments.map((c) => (c.ply, c.verificationStatus)), [
        (8, VerificationStatus.passed),
        (12, VerificationStatus.regenerated),
        (18, VerificationStatus.fallback),
      ]);
      expect(doc.commentsAt(18).single.isFallback, isTrue);
      expect(doc.commentsAt(12).single.isFallback, isFalse);
      // A fallback text is a full comment: it has a text and its lines.
      expect(doc.commentsAt(18).single.text, isNotEmpty);
    });
  });

  group('every official fixture', () {
    for (final name in officialFixtures) {
      group(name, () {
        late Map<String, dynamic> json;
        late AnalysisDocument doc;

        setUpAll(() {
          json = fixtureJson(name);
          final result = parseSupported(json);
          expect(result.warnings, isEmpty, reason: 'nothing may be dropped');
          doc = result.document;
        });

        test('nothing was dropped', () {
          final rawNodes = (json['nodes'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
          expect(doc.nodes, hasLength(rawNodes.length));
          for (final raw in rawNodes) {
            final node = doc.nodeAt(raw['ply'] as int)!;
            expect(
              node.variations.map((v) => v.id),
              (raw['variations'] as List<dynamic>).map(
                (v) => (v as Map<String, dynamic>)['id'],
              ),
            );
            expect(node.commentIds, raw['comment_ids']);
            expect(node.best == null, raw['best'] == null);
            expect(node.moveNumber, raw['move_number']);
            expect(node.side.name, raw['color']);
            expect(node.classification, isNot(MoveClassification.unknown));
          }
          final rawComments = (json['comments'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
          expect(
            doc.comments.map((c) => c.id),
            rawComments.map((c) => c['id']),
          );
          for (final raw in rawComments) {
            final comment = doc.commentsById[raw['id']]!;
            expect(comment.arrows, hasLength((raw['arrows'] as List).length));
            expect(comment.squares, hasLength((raw['squares'] as List).length));
            expect(comment.lines, hasLength((raw['lines'] as List).length));
            expect(comment.movesMentioned, raw['moves_mentioned']);
            expect(comment.type, isNot(CommentType.unknown));
          }
          expect(doc.lessons, hasLength(3));
        });

        test('the main line replays legally, FEN for FEN', () {
          Position position = Chess.initial;
          for (final node in doc.nodes) {
            expect(position.fen, node.fenBefore);
            expect(position.isLegal(node.move), isTrue);
            expect(position.parseSan(node.san), isNotNull);
            position = position.play(node.move);
            expect(position.fen, node.fenAfter);
            expect(position, node.positionAfter);
          }
        });

        test('every variation replays legally from its start_fen', () {
          var count = 0;
          for (final node in doc.nodes) {
            for (final variation in node.variations) {
              count++;
              Position position = Chess.fromSetup(
                Setup.parseFen(variation.startFen),
              );
              expect(
                variation.startFen,
                variation.kind == VariationKind.refutation
                    ? node.fenAfter
                    : node.fenBefore,
              );
              expect(variation.moves, isNotEmpty);
              for (final move in variation.moves) {
                expect(position.isLegal(move.move), isTrue, reason: move.uci);
                final (after, san) = position.makeSan(move.move);
                expect(san, move.san);
                expect(after.fen, move.fenAfter);
                expect(move.positionAfter.fen, move.fenAfter);
                position = after;
              }
            }
          }
          expect(count, greaterThan(0));
        });

        test('every comment line resolves on the comment\'s node', () {
          for (final comment in doc.comments) {
            final node = doc.nodeAt(comment.ply)!;
            expect(node.isCritical, isTrue);
            expect(node.commentIds, contains(comment.id));
            expect(comment.lines, isNotEmpty);
            for (final line in comment.lines) {
              expect(node.variationById(line.variationId), isNotNull);
            }
          }
          for (final node in doc.nodes) {
            expect(node.isCritical, node.commentIds.isNotEmpty);
            for (final id in node.commentIds) {
              expect(doc.commentsById[id]!.ply, node.ply);
            }
          }
        });

        test(
          'evals chain: eval_after of ply n is eval_before of ply n + 1',
          () {
            for (var i = 0; i + 1 < doc.nodes.length; i++) {
              expect(doc.nodes[i].evalAfter, doc.nodes[i + 1].evalBefore);
            }
            expect(doc.evalSeries(), hasLength(doc.plyCount + 1));
          },
        );

        test('lesson evidence points at existing plies', () {
          for (final lesson in doc.lessons) {
            expect(lesson.evidencePlies, isNotEmpty);
            for (final ply in lesson.evidencePlies) {
              expect(doc.nodeAt(ply), isNotNull);
            }
          }
        });

        test('parseString gives the same document', () {
          final result = AnalysisParser.parseString(fixtureString(name));
          expect(result, isA<AnalysisSupported>());
          final other = (result as AnalysisSupported).document;
          expect(other.analysisId, doc.analysisId);
          expect(other.nodes.map((n) => n.uci), doc.nodes.map((n) => n.uci));
        });
      });
    }
  });

  group('v1-with-unknowns.json (a newer minor)', () {
    late AnalysisSupported result;
    late AnalysisDocument doc;

    setUpAll(() {
      result = parseSupported(
        fixtureJson('v1-with-unknowns.json', dir: forwardCompatDir),
      );
      doc = result.document;
    });

    test('is supported, whatever the minor', () {
      expect(doc.schemaVersion, 1);
      expect(doc.schemaMinor, 7);
      expect(doc.plyCount, 21);
      expect(doc.engine.humanModel, 'maia3-blitz');
      expect(doc.engine.hasHumanModel, isTrue);
    });

    test('unknown classification becomes unknown and has no glyph', () {
      final node = doc.nodeAt(3)!;
      expect(node.classification, MoveClassification.unknown);
      expect(node.classificationRaw, 'brilliant');
      expect(doc.glyphFor(node), isNull);
      expect(
        doc.classificationCounts(Side.white)[MoveClassification.unknown],
        1,
      );
    });

    test('a comment of an unknown type is skipped and unlinked', () {
      expect(doc.comments.map((c) => c.ply), [10, 12, 16]);
      expect(doc.nodeAt(2)!.commentIds, isEmpty);
      expect(doc.commentsAt(2), isEmpty);
      expect(
        result.warnings.single,
        allOf(contains('opening_note'), contains('skipped')),
      );
    });

    test('keepUnknownCommentTypes keeps it as a neutral comment', () {
      final kept = parseSupported(
        fixtureJson('v1-with-unknowns.json', dir: forwardCompatDir),
        keepUnknownCommentTypes: true,
      );
      expect(kept.warnings, isEmpty);
      final comment = kept.document.commentsAt(2).single;
      expect(comment.type, CommentType.unknown);
      expect(comment.typeRaw, 'opening_note');
      expect(comment.movesMentioned, ['c6']);
      expect(kept.document.comments.map((c) => c.ply), [2, 10, 12, 16]);
      // Not a moment: the node is not critical, so navigation skips it.
      expect(kept.document.criticalPlies, [10, 12, 16]);
    });

    test('a variation of an unknown kind is a plain line from start_fen', () {
      final node = doc.nodeAt(12)!;
      final plan = node.variationById('v12-plan')!;
      expect(plan.kind, VariationKind.unknown);
      expect(plan.kindRaw, 'plan');
      expect(plan.startFen, node.fenBefore);
      expect(plan.sans, node.variationById('v12-best')!.sans);
      expect(doc.commentsAt(12).single.lines.map((l) => l.variationId), [
        'v12-best',
        'v12-refutation',
        'v12-plan',
      ]);
    });

    test('unknown theme, roles and verification status are kept as such', () {
      final comment = doc.commentsAt(10).single;
      expect(comment.theme, 'zwischenzug');
      expect(comment.squares.first.role, SquareRole.unknown);
      expect(comment.squares.first.roleRaw, 'outpost');
      expect(comment.squares.first.square, Square.e8);
      expect(comment.arrows, hasLength(4));
      expect(comment.arrows.last.role, ArrowRole.unknown);
      expect(comment.arrows.last.roleRaw, 'plan');
      // An arrow of an unknown role is not drawn.
      expect(arrowsForComment(comment), hasLength(3));
      expect(
        doc.commentsAt(16).single.verificationStatus,
        VerificationStatus.unknown,
      );
      expect(doc.commentsAt(16).single.isFallback, isFalse);
      expect(doc.lessons[1].theme, 'time_management');
    });

    test('extra fields change nothing else', () {
      final plain = parseSupported(fixtureJson('short-game.json')).document;
      expect(doc.evalSeries(), plain.evalSeries());
      expect(doc.nodes.map((n) => n.uci), plain.nodes.map((n) => n.uci));
      expect(doc.nodeAt(10)!.evalBefore, const EvalScore.cp(16));
      expect(doc.nodeAt(10)!.best!.uci, 'f6e4');
      expect(doc.nodeAt(10)!.human!.playedProb, 0.42);
      expect(doc.lessons.map((l) => l.id), plain.lessons.map((l) => l.id));
    });
  });

  group('v2-major.json (a newer major)', () {
    late Map<String, dynamic> json;

    setUp(() => json = fixtureJson('v2-major.json', dir: forwardCompatDir));

    test('yields the board and the moves, nothing else', () {
      final result = AnalysisParser.parse(json);
      expect(result, isA<AnalysisNewerMajor>());
      final partial = (result as AnalysisNewerMajor).partial;
      expect(result.warnings, isEmpty);
      expect(partial.schemaVersion, 2);
      expect(partial.schemaMinor, 0);
      expect(partial.analysisId, 'e88b7591-31db-4e32-98dc-b35f94c662cd');
      expect(partial.startFen, isNull);
      expect(partial.startPosition, Chess.initial);
      expect(partial.result, GameResult.whiteWins);
      expect(
        partial.moves.map((m) => m.san).join(' '),
        'e4 c6 d4 d5 Nc3 dxe4 Nxe4 Nf6 Qd3 e5 dxe5 Qa5+ Bd2 Qxe5 O-O-O Nxe4 '
        'Qd8+ Kxd8 Bg5+ Kc7 Bd8#',
      );
      final v1 = parseSupported(fixtureJson('short-game.json')).document;
      for (final move in partial.moves) {
        final node = v1.nodeAt(move.ply)!;
        expect(move.uci, node.uci);
        expect(move.fenAfter, node.fenAfter);
        expect(move.positionAfter, node.positionAfter);
        expect(move.side, node.side);
        expect(move.moveNumber, node.moveNumber);
      }
      expect(partial.positionAt(0), Chess.initial);
      expect(partial.positionAt(99).isCheckmate, isTrue);
      expect(partial.moves.clear, throwsUnsupportedError);
    });

    test('a build that claims major 2 is not fooled by the v1 reader', () {
      // The gate is the only thing that protects the v1 reader from a v2
      // document; without it the changed node shape is invalid.
      expect(
        AnalysisParser.parse(json, maxSupportedMajor: 2),
        isA<AnalysisInvalid>(),
      );
    });

    test('moves that moved elsewhere give an empty partial', () {
      json['moves'] = 'e4 c6 d4 d5';
      json.remove('nodes');
      final result = AnalysisParser.parse(json) as AnalysisNewerMajor;
      expect(result.partial.moves, isEmpty);
      expect(result.partial.positionAt(5), Chess.initial);
      expect(result.warnings.single, contains('nodes'));
    });

    test('the partial stops at the first move that is not legal', () {
      rawNode(json, 5)
        ..['uci'] = 'b1b3'
        ..['san'] = 'Nb3';
      final result = AnalysisParser.parse(json) as AnalysisNewerMajor;
      expect(result.partial.moves.map((m) => m.san), ['e4', 'c6', 'd4', 'd5']);
      expect(result.warnings.single, contains('nodes[4]'));
    });

    test('SAN alone is enough, and so is UCI alone', () {
      for (final node
          in (json['nodes'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        node.remove(node['ply'] as int < 10 ? 'uci' : 'san');
      }
      final result = AnalysisParser.parse(json) as AnalysisNewerMajor;
      expect(result.partial.moves, hasLength(21));
      expect(result.partial.moves[0].uci, 'e2e4');
      expect(result.partial.moves[20].san, 'Bd8#');
    });

    test('an unreadable start position gives an empty partial', () {
      (json['game'] as Map<String, dynamic>)['start_fen'] = 'not a fen';
      final result = AnalysisParser.parse(json) as AnalysisNewerMajor;
      expect(result.partial.moves, isEmpty);
      expect(result.partial.startPosition, Chess.initial);
      expect(result.partial.startFen, isNull);
    });

    test('a v1 document is "newer" for a build that supports nothing', () {
      final result = AnalysisParser.parse(
        fixtureJson('short-game.json'),
        maxSupportedMajor: 0,
      );
      expect(result, isA<AnalysisNewerMajor>());
      expect((result as AnalysisNewerMajor).partial.moves, hasLength(21));
    });
  });

  test('the forty-move game parses in well under 50 ms', () {
    final payload = fixtureString('forty-move-game.json');
    // Warm up the JIT, then take the best of a few runs: the bound is about
    // the algorithm, not about a busy CI machine.
    AnalysisParser.parseString(payload);
    var best = const Duration(days: 1);
    for (var i = 0; i < 5; i++) {
      final watch = Stopwatch()..start();
      final result = AnalysisParser.parseString(payload);
      watch.stop();
      expect(result, isA<AnalysisSupported>());
      if (watch.elapsed < best) best = watch.elapsed;
    }
    expect(best.inMilliseconds, lessThan(50), reason: 'best of 5: $best');
  });
}
