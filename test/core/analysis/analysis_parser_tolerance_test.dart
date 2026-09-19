// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/analysis/analysis_view.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

import 'analysis_fixtures.dart';

/// Every test breaks a fresh copy of short-game.json in one way.
void main() {
  late Map<String, dynamic> json;

  setUp(() => json = fixtureJson('short-game.json'));

  List<Map<String, dynamic>> listOf(Map<String, dynamic> owner, String key) =>
      (owner[key] as List<dynamic>).cast<Map<String, dynamic>>();

  group('envelope', () {
    test('broken JSON, a JSON array and a JSON scalar are invalid', () {
      for (final payload in ['', '{"schema": ', '[1, 2]', '"text"', 'null']) {
        expect(
          AnalysisParser.parseString(payload),
          isA<AnalysisInvalid>(),
          reason: payload,
        );
      }
    });

    test('a foreign or missing schema name is invalid', () {
      json['schema'] = 'bognerchess.something-else';
      expect(parseInvalid(json), contains('something-else'));
      json.remove('schema');
      expect(parseInvalid(json), contains('schema'));
      expect(parseInvalid({}), contains('schema'));
    });

    test('schema_version has to be a positive integer', () {
      for (final value in [null, '1', 0, -1, 1.5, true]) {
        json['schema_version'] = value;
        expect(
          parseInvalid(json),
          contains('schema_version'),
          reason: '$value',
        );
      }
      json['schema_version'] = 1.0;
      expect(parseSupported(json).document.schemaVersion, 1);
    });

    test('a higher major is "newer", any minor is fine', () {
      json['schema_version'] = 3;
      expect(AnalysisParser.parse(json), isA<AnalysisNewerMajor>());
      json['schema_version'] = 1;
      json['schema_minor'] = 4711;
      expect(parseSupported(json).document.schemaMinor, 4711);
      json.remove('schema_minor');
      expect(parseSupported(json).document.schemaMinor, 0);
    });

    test('the default gate is kMaxSupportedAnalysisSchema', () {
      json['schema_version'] = kMaxSupportedAnalysisSchema + 1;
      expect(AnalysisParser.parse(json), isA<AnalysisNewerMajor>());
      json['schema_version'] = kMaxSupportedAnalysisSchema;
      expect(AnalysisParser.parse(json), isA<AnalysisSupported>());
    });

    test('missing envelope details get defaults', () {
      for (final key in [
        'analysis_id',
        'generated_at',
        'language',
        'perspective',
        'engine',
        'coach',
        'accuracy',
        'summary',
        'comments',
      ]) {
        json.remove(key);
      }
      for (final node in listOf(json, 'nodes')) {
        node['comment_ids'] = <String>[];
      }
      final doc = parseSupported(json).document;
      expect(doc.analysisId, '');
      expect(doc.generatedAt, isNull);
      expect(doc.language, 'en');
      expect(doc.perspective, AnalysisPerspective.both);
      expect(doc.ratingBand, 'unknown');
      expect(doc.engine.name, '');
      expect(doc.engine.hasHumanModel, isFalse);
      expect(doc.coach.model, '');
      expect(doc.coach.promptVersion, '');
      expect(doc.accuracyWhite, isNull);
      expect(doc.accuracyOf(Side.black), isNull);
      expect(doc.comments, isEmpty);
      expect(doc.lessons, isEmpty);
      expect(doc.plyCount, 21);
    });

    test('closed enums with a surprising value fall back', () {
      (json['perspective'] as Map<String, dynamic>)['color'] = 'observer';
      (json['game'] as Map<String, dynamic>)['result'] = 'abandoned';
      final doc = parseSupported(json).document;
      expect(doc.perspective, AnalysisPerspective.both);
      expect(doc.result, GameResult.unfinished);
    });

    test('a wrong ply_count is a warning, the nodes count', () {
      (json['game'] as Map<String, dynamic>)['ply_count'] = 40;
      final result = parseSupported(json);
      expect(result.document.plyCount, 21);
      expect(result.warnings.single, contains('ply_count'));
    });
  });

  group('main line (core: a fault is invalid)', () {
    test('nodes missing, empty or not a list', () {
      for (final value in [null, <dynamic>[], 'e4 e5', 7]) {
        json['nodes'] = value;
        expect(parseInvalid(json), contains('nodes'), reason: '$value');
      }
    });

    test('a node that is not an object', () {
      (json['nodes'] as List<dynamic>)[4] = 'Nc3';
      expect(parseInvalid(json), contains('nodes[4]'));
    });

    for (final key in [
      'ply',
      'san',
      'uci',
      'fen_before',
      'fen_after',
      'eval_before',
      'eval_after',
      'win_pct_before',
      'win_pct_after',
      'classification',
    ]) {
      test('a node without $key', () {
        rawNode(json, 7).remove(key);
        expect(parseInvalid(json), allOf(contains('nodes[6]'), contains(key)));
      });

      test('a node with a malformed $key', () {
        rawNode(json, 7)[key] = <String>['?'];
        expect(parseInvalid(json), contains('nodes[6]'));
      });
    }

    test('plies have to count up from 1', () {
      rawNode(json, 7)['ply'] = 8;
      expect(parseInvalid(json), contains('expected 7'));
    });

    test('an illegal move', () {
      rawNode(json, 5)
        ..['uci'] = 'b1b3'
        ..['san'] = 'Nb3';
      expect(
        parseInvalid(json),
        allOf(contains('nodes[4]'), contains('legal')),
      );
    });

    test('garbage instead of UCI', () {
      for (final uci in ['', 'e', 'e2e9', 'e2-e4', 'E2E4', 'e7e8k', 'P@e4']) {
        rawNode(json, 1)['uci'] = uci;
        expect(parseInvalid(json), contains('nodes[0]'), reason: uci);
      }
    });

    test('SAN and UCI that name different moves', () {
      rawNode(json, 1)['san'] = 'd4';
      expect(parseInvalid(json), contains('nodes[0]'));
    });

    test('SAN that names no move', () {
      rawNode(json, 1)['san'] = 'Qh5';
      expect(parseInvalid(json), contains('nodes[0]'));
    });

    test('a fen_after that contradicts the replay', () {
      rawNode(json, 3)['fen_after'] = rawNode(json, 1)['fen_after'];
      expect(parseInvalid(json), contains('nodes[2].fen_after'));
    });

    test('a fen_before that contradicts the replay', () {
      rawNode(json, 3)['fen_before'] = 'not a fen';
      expect(parseInvalid(json), contains('nodes[2].fen_before'));
    });

    test('an eval with both cp and mate, or with neither', () {
      rawNode(json, 2)['eval_after'] = {'cp': 10, 'mate': 2};
      expect(parseInvalid(json), contains('eval_after'));
      json = fixtureJson('short-game.json');
      rawNode(json, 2)['eval_before'] = {'depth': 20};
      expect(parseInvalid(json), contains('eval_before'));
    });

    test('whole-number doubles are accepted where integers are expected', () {
      rawNode(json, 2)
        ..['ply'] = 2.0
        ..['eval_after'] = {'cp': 28.0};
      expect(
        parseSupported(json).document.nodeAt(2)!.evalAfter,
        const EvalScore.cp(28),
      );
    });

    test('win_pct_loss is computed when missing, percentages are clamped', () {
      rawNode(json, 10).remove('win_pct_loss');
      rawNode(json, 11)['win_pct_after'] = 140;
      final doc = parseSupported(json).document;
      expect(doc.nodeAt(10)!.winPctLoss, closeTo(9.7, 1e-9));
      expect(doc.nodeAt(11)!.winPctAfter, 100.0);
    });

    test('move number and colour come from the replay, not from the JSON', () {
      rawNode(json, 10)
        ..['move_number'] = 99
        ..['color'] = 'white';
      final node = parseSupported(json).document.nodeAt(10)!;
      expect(node.moveNumber, 5);
      expect(node.side, Side.black);
    });

    test('mate 0 on a position that is not checkmate is only a warning', () {
      rawNode(json, 1)['eval_after'] = {'mate': 0};
      rawNode(json, 2)['eval_before'] = {'mate': 0};
      final result = parseSupported(json);
      expect(result.warnings.single, contains('mate 0'));
      expect(result.document.nodeAt(1)!.evalAfter.mateWinner, Side.white);
      expect(result.document.nodeAt(2)!.evalBefore.mateWinner, Side.white);
    });

    group('game.start_fen', () {
      /// The short game from [firstPly] on, as a game with a start position.
      Map<String, dynamic> tail(int firstPly) {
        final shift = firstPly - 1;
        final nodes = listOf(json, 'nodes').sublist(shift);
        for (final node in nodes) {
          node['ply'] = (node['ply'] as int) - shift;
        }
        for (final comment in listOf(json, 'comments')) {
          comment['ply'] = (comment['ply'] as int) - shift;
        }
        json['nodes'] = nodes;
        (json['game'] as Map<String, dynamic>)
          ..['start_fen'] = nodes.first['fen_before']
          ..['ply_count'] = nodes.length;
        return json;
      }

      test('a game that starts with White at move 2', () {
        final result = parseSupported(tail(3));
        expect(result.warnings, isEmpty);
        final doc = result.document;
        expect(doc.startFen, startsWith('rnbqkbnr/pp1ppppp/2p5'));
        expect(doc.startPosition.fen, doc.startFen);
        expect(doc.plyCount, 19);
        expect(doc.nodeAt(1)!.moveLabel, '2. d4');
        expect(doc.criticalPlies, [8, 10, 14]);
        expect(doc.commentsAt(8).single.lines, hasLength(2));
      });

      test('a game that starts with Black to move', () {
        final doc = parseSupported(tail(2)).document;
        expect(doc.nodeAt(1)!.side, Side.black);
        expect(doc.nodeAt(1)!.moveLabel, '1... c6');
        expect(doc.nodeAt(2)!.moveLabel, '2. d4');
        expect(doc.evalSeries(), hasLength(21));
      });

      test('an unreadable or impossible start position is invalid', () {
        final game = json['game'] as Map<String, dynamic>;
        game['start_fen'] = 'not a fen';
        expect(parseInvalid(json), contains('start_fen'));
        game['start_fen'] = '8/8/8/8/8/8/8/8 w - - 0 1';
        expect(parseInvalid(json), contains('start_fen'));
        game['start_fen'] = 17;
        expect(parseInvalid(json), contains('start_fen'));
      });

      test('a start position the moves do not fit is invalid', () {
        (json['game'] as Map<String, dynamic>)['start_fen'] = rawNode(
          json,
          3,
        )['fen_before'];
        expect(parseInvalid(json), contains('nodes[0]'));
      });
    });
  });

  group('best move (dropped, never fatal)', () {
    test('illegal', () {
      (rawNode(json, 10)['best'] as Map<String, dynamic>)
        ..['uci'] = 'f6f3'
        ..['san'] = 'Nf3';
      final result = parseSupported(json);
      expect(result.document.nodeAt(10)!.best, isNull);
      expect(result.warnings, contains(contains('nodes[9].best')));
      expect(arrowsFor(result.document.nodeAt(10)!), hasLength(1));
    });

    test('malformed', () {
      rawNode(json, 10)['best'] = 'Nxe4';
      rawNode(json, 12)['best'] = {'san': 'Qxd3', 'uci': 'd8d3'};
      final result = parseSupported(json);
      expect(result.document.nodeAt(10)!.best, isNull);
      expect(result.document.nodeAt(12)!.best, isNull);
      // "Nxe4" and "Qxd3" are still moves of their variations.
      expect(result.warnings, hasLength(2));
    });
  });

  group('variations (dropped one by one, never fatal)', () {
    AnalysisSupported expectDropped(String id) {
      final result = parseSupported(json);
      final node = result.document.nodeAt(10)!;
      expect(node.variationById(id), isNull);
      expect(node.variations, hasLength(2), reason: 'the others stay');
      expect(result.warnings, isNotEmpty);
      return result;
    }

    test('an illegal move drops the line and the references to it', () {
      final moves = listOf(rawVariation(json, 10, 'v10-refutation'), 'moves');
      moves[2]
        ..['uci'] = 'f1e2'
        ..['san'] = 'Be2';
      final result = expectDropped('v10-refutation');
      final comment = result.document.commentsAt(10).single;
      expect(comment.lines.map((l) => l.variationId), ['v10-best']);
      // dxe5 was only a move of the dropped line: no longer tappable.
      expect(comment.movesMentioned, ['e5', 'Nxe4', 'Qxe4', 'Qd5', 'Bf5']);
      expect(
        result.warnings,
        containsAll([
          contains('v10-refutation'),
          contains('comments[0].lines[1]'),
          contains('"dxe5"'),
        ]),
      );
      // The comment itself, its arrows and the node survive.
      expect(comment.arrows, hasLength(3));
      expect(result.document.nodeAt(10)!.isCritical, isTrue);
    });

    test('SAN that does not match the UCI move', () {
      listOf(rawVariation(json, 10, 'v10-best'), 'moves')[1]['san'] = 'Qe2';
      expectDropped('v10-best');
    });

    test('a fen_after that contradicts the replay', () {
      final moves = listOf(rawVariation(json, 10, 'v10-alt1'), 'moves');
      moves[3]['fen_after'] = moves[2]['fen_after'];
      expectDropped('v10-alt1');
    });

    test('a known kind that starts from the wrong position', () {
      // A refutation starts at fen_after; this one claims fen_before, where
      // its first move (White's) would not even be on turn.
      rawVariation(json, 10, 'v10-refutation')['start_fen'] = rawNode(
        json,
        10,
      )['fen_before'];
      expectDropped('v10-refutation');
      json = fixtureJson('short-game.json');
      rawVariation(json, 10, 'v10-best')['start_fen'] = rawNode(
        json,
        1,
      )['fen_before'];
      expectDropped('v10-best');
    });

    test(
      'malformed: no moves, no eval, no id, no start_fen, not an object',
      () {
        for (final breakIt in <void Function(Map<String, dynamic>)>[
          (v) => v['moves'] = <dynamic>[],
          (v) => v['moves'] = 'Nxe4 Qxe4',
          (v) => v['eval'] = {'cp': 1, 'mate': 1},
          (v) => v.remove('eval'),
          (v) => v['id'] = '',
          (v) => v.remove('start_fen'),
          (v) => (v['moves'] as List<dynamic>)[0] = 'Nxe4',
          (v) => listOf(v, 'moves')[0].remove('fen_after'),
        ]) {
          json = fixtureJson('short-game.json');
          breakIt(rawVariation(json, 10, 'v10-best'));
          final result = parseSupported(json);
          expect(result.document.nodeAt(10)!.variations, hasLength(2));
          expect(result.warnings, isNotEmpty);
        }
        json = fixtureJson('short-game.json');
        (rawNode(json, 10)['variations'] as List<dynamic>)[0] = 42;
        expectDropped('v10-best');
      },
    );

    test('variations that is not a list', () {
      rawNode(json, 10)['variations'] = {'v10-best': 1};
      final result = parseSupported(json);
      expect(result.document.nodeAt(10)!.variations, isEmpty);
      expect(result.document.commentsAt(10).single.lines, isEmpty);
    });

    test('a duplicate id, even on another node', () {
      rawVariation(json, 12, 'v12-best')['id'] = 'v10-best';
      final result = parseSupported(json);
      expect(result.document.nodeAt(10)!.variationById('v10-best'), isNotNull);
      expect(result.document.nodeAt(12)!.variations, hasLength(2));
      expect(result.warnings, contains(contains('duplicate id v10-best')));
    });

    group('unknown kind', () {
      Map<String, dynamic> promotion({required String uci}) => {
        'id': 'v10-study',
        'kind': 'study',
        'eval': {'cp': 900},
        'start_fen': '8/P7/8/8/8/8/8/1k5K w - - 0 1',
        'moves': [
          {
            'san': 'a8=Q',
            'uci': uci,
            'fen_after': 'Q7/8/8/8/8/8/8/1k5K b - - 0 1',
          },
        ],
      };

      test('may start anywhere, as long as the position is legal', () {
        (rawNode(json, 10)['variations'] as List<dynamic>).add(
          promotion(uci: 'a7a8q'),
        );
        final result = parseSupported(json);
        expect(result.warnings, isEmpty);
        final line = result.document.nodeAt(10)!.variationById('v10-study')!;
        expect(line.kind, VariationKind.unknown);
        expect(line.startPosition.fen, line.startFen);
        expect(line.moves.single.move.promotion, Role.queen);
      });

      test(
        'a pawn that reaches the last rank without promoting is illegal',
        () {
          (rawNode(json, 10)['variations'] as List<dynamic>).add(
            promotion(uci: 'a7a8'),
          );
          final result = parseSupported(json);
          expect(
            result.document.nodeAt(10)!.variationById('v10-study'),
            isNull,
          );
          expect(result.warnings.single, contains('v10-study'));
        },
      );

      test('an impossible start position drops the line', () {
        (rawNode(json, 10)['variations'] as List<dynamic>).add(
          promotion(uci: 'a7a8q')
            ..['start_fen'] = '8/P7/8/8/8/8/8/7K w - - 0 1',
        );
        final result = parseSupported(json);
        expect(result.document.nodeAt(10)!.variationById('v10-study'), isNull);
      });
    });
  });

  group('comments (dropped one by one, never fatal)', () {
    test('a malformed comment goes, the rest stays', () {
      for (final breakIt in <void Function(Map<String, dynamic>)>[
        (c) => c.remove('id'),
        (c) => c.remove('type'),
        (c) => c.remove('ply'),
        (c) => c.remove('text'),
        (c) => c['text'] = '',
        (c) => c['ply'] = 'ten',
        (c) => c['ply'] = 0,
        (c) => c['ply'] = 22,
      ]) {
        json = fixtureJson('short-game.json');
        breakIt(rawComment(json, 10));
        final result = parseSupported(json);
        final doc = result.document;
        expect(doc.comments.map((c) => c.ply), [12, 16]);
        expect(doc.nodeAt(10)!.commentIds, isEmpty);
        expect(doc.commentsAt(10), isEmpty);
        // Still a moment of the game, with its engine lines.
        expect(doc.nodeAt(10)!.isCritical, isTrue);
        expect(doc.nodeAt(10)!.variations, hasLength(3));
        expect(result.warnings.single, contains('comments[0]'));
      }
    });

    test('a comment that is not an object, comments that is not a list', () {
      (json['comments'] as List<dynamic>)[1] = 'Qa5+ is a mistake';
      expect(parseSupported(json).document.comments.map((c) => c.ply), [
        10,
        16,
      ]);
      json['comments'] = 'none';
      final result = parseSupported(json);
      expect(result.document.comments, isEmpty);
      expect(result.document.nodes.expand((n) => n.commentIds), isEmpty);
    });

    test('an unknown type is skipped and removed from the node', () {
      rawComment(json, 12)['type'] = 'endgame_tip';
      final result = parseSupported(json);
      expect(result.document.comments.map((c) => c.ply), [10, 16]);
      expect(result.document.nodeAt(12)!.commentIds, isEmpty);
      expect(result.warnings.single, contains('endgame_tip'));
    });

    test('a duplicate id keeps the first', () {
      rawComment(json, 12)['id'] = rawComment(json, 10)['id'];
      final result = parseSupported(json);
      expect(result.document.comments.map((c) => c.ply), [10, 16]);
      expect(result.warnings, contains(contains('duplicate id')));
    });

    test('missing title and theme get defaults', () {
      rawComment(json, 10)
        ..remove('title')
        ..remove('theme')
        ..remove('verification')
        ..remove('squares')
        ..remove('arrows')
        ..remove('lines')
        ..remove('moves_mentioned');
      final comment = parseSupported(json).document.commentsAt(10).single;
      expect(comment.title, '');
      expect(comment.theme, 'unknown');
      expect(comment.verificationStatus, VerificationStatus.unknown);
      expect(comment.squares, isEmpty);
      expect(comment.arrows, isEmpty);
      expect(comment.lines, isEmpty);
      expect(comment.movesMentioned, isEmpty);
    });

    test('node.comment_ids only keeps ids of comments on that ply', () {
      rawNode(json, 10)['comment_ids'] = [
        'ffffffff-0000-4000-8000-000000000000',
        rawComment(json, 12)['id'],
        rawComment(json, 10)['id'],
        7,
      ];
      final doc = parseSupported(json).document;
      expect(doc.nodeAt(10)!.commentIds, [rawComment(json, 10)['id']]);
    });

    test('a comment its node does not list is linked, with a warning', () {
      rawNode(json, 10)['comment_ids'] = <String>[];
      final result = parseSupported(json);
      expect(result.document.commentsAt(10), hasLength(1));
      expect(result.warnings.single, contains('nodes[9].comment_ids'));
    });

    test('comments come out ordered by ply, stable within a ply', () {
      final comments = json['comments'] as List<dynamic>;
      final second =
          jsonDecode(jsonEncode(rawComment(json, 10))) as Map<String, dynamic>;
      second['id'] = 'aaaaaaaa-0000-4000-8000-000000000000';
      second['title'] = 'Second';
      json['comments'] = [...comments.reversed, second];
      (rawNode(json, 10)['comment_ids'] as List<dynamic>).add(second['id']);
      final doc = parseSupported(json).document;
      expect(doc.comments.map((c) => c.ply), [10, 10, 12, 16]);
      expect(doc.comments[1].title, 'Second');
      expect(doc.commentsAt(10).map((c) => c.title), [
        'Opening the centre too early',
        'Second',
      ]);
    });

    test(
      'arrows: bad squares, a null move and impossible moves are dropped',
      () {
        rawComment(json, 10)['arrows'] = [
          {'from': 'e7', 'to': 'e5', 'role': 'played'},
          {'from': 'z9', 'to': 'e5', 'role': 'played'},
          {'from': 'e7', 'to': 'e55', 'role': 'played'},
          {'from': 'e7', 'role': 'played'},
          {'from': 'e7', 'to': 'e7', 'role': 'played'},
          'e7e5',
          // Not a move of the side to move before the move.
          {'from': 'a8', 'to': 'h1', 'role': 'best'},
          {'from': 'd4', 'to': 'e5', 'role': 'played'},
          // A threat has to start on a piece in the position after the move.
          {'from': 'd5', 'to': 'e6', 'role': 'threat'},
          {'from': 'd4', 'to': 'e5', 'role': 'threat'},
          // Unknown roles are kept in the model (and not drawn).
          {'from': 'a1', 'to': 'a8', 'role': 'sparkle'},
        ];
        final result = parseSupported(json);
        final comment = result.document.commentsAt(10).single;
        expect(comment.arrows.map((a) => '${a.from.name}${a.to.name}'), [
          'e7e5',
          'd4e5',
          'a1a8',
        ]);
        expect(result.warnings, hasLength(8));
        expect(result.warnings, everyElement(contains('comments[0].arrows')));
      },
    );

    test('squares: bad squares are dropped', () {
      rawComment(json, 10)['squares'] = [
        {'square': 'e8', 'role': 'weak'},
        {'square': 'i1', 'role': 'weak'},
        {'square': 5, 'role': 'weak'},
        {'role': 'weak'},
        'e5',
        {'square': 'e5'},
      ];
      final result = parseSupported(json);
      final squares = result.document.commentsAt(10).single.squares;
      expect(squares.map((s) => s.square), [Square.e8, Square.e5]);
      expect(squares.last.role, SquareRole.unknown);
      expect(result.warnings, hasLength(4));
    });

    test('lines: a reference to another node\'s variation is dropped', () {
      rawComment(json, 10)['lines'] = [
        {'variation_id': 'v12-best', 'label': 'Better'},
        {'variation_id': 'v10-best'},
        {'label': 'Nothing'},
        'v10-alt1',
      ];
      final result = parseSupported(json);
      final lines = result.document.commentsAt(10).single.lines;
      expect(lines.map((l) => (l.variationId, l.label)), [('v10-best', '')]);
      expect(result.warnings, hasLength(3));
    });

    test('moves_mentioned: only moves of the node, no duplicates', () {
      rawComment(json, 10)['moves_mentioned'] = ['e5', 'Qh4#', 'e5', 3, 'Be2'];
      final result = parseSupported(json);
      expect(result.document.commentsAt(10).single.movesMentioned, [
        'e5',
        'Be2',
      ]);
      expect(result.warnings, hasLength(2));
    });
  });

  group('lessons', () {
    test('a malformed lesson is dropped, evidence is filtered', () {
      final summary = json['summary'] as Map<String, dynamic>;
      final lessons = listOf(summary, 'lessons');
      lessons[0].remove('text');
      lessons[1]['evidence_plies'] = [12, 0, 22, 'x', 12.0];
      lessons[2]
        ..remove('title')
        ..remove('theme')
        ..remove('evidence_plies');
      final result = parseSupported(json);
      final parsed = result.document.lessons;
      expect(parsed, hasLength(2));
      expect(parsed[0].evidencePlies, [12, 12]);
      expect(parsed[1].title, '');
      expect(parsed[1].theme, 'unknown');
      expect(parsed[1].evidencePlies, isEmpty);
      expect(result.warnings.single, contains('summary.lessons[0]'));
    });

    test('lessons that is not a list', () {
      (json['summary'] as Map<String, dynamic>)['lessons'] = 'none';
      expect(parseSupported(json).document.lessons, isEmpty);
    });
  });

  group('never throws', () {
    const junk = <Object?>[
      null,
      0,
      -1,
      1.5,
      '',
      'junk',
      true,
      <dynamic>[],
      <dynamic>[null, 1, 'x', <String, dynamic>{}],
      <String, dynamic>{},
      <String, dynamic>{'cp': 'x', 'san': 1, 'id': null},
    ];

    void fuzz(
      String what,
      Map<String, dynamic> Function(Map<String, dynamic>) target, {
      bool alwaysSupported = false,
    }) {
      test('junk in every field of $what', () {
        final keys = target(fixtureJson('short-game.json')).keys.toList();
        for (final key in [...keys, 'no_such_key']) {
          for (final value in junk) {
            final copy = fixtureJson('short-game.json');
            target(copy)[key] = value;
            final AnalysisParseResult result;
            try {
              result = AnalysisParser.parse(copy);
            } catch (e) {
              fail('$what.$key = ${jsonEncode(value)} threw $e');
            }
            if (alwaysSupported) {
              expect(
                result,
                isA<AnalysisSupported>(),
                reason: '$what.$key = ${jsonEncode(value)}: $result',
              );
            }
            // Whatever survived is legal chess.
            if (result case AnalysisSupported(:final document)) {
              for (final node in document.nodes) {
                expect(node.positionBefore.isLegal(node.move), isTrue);
                for (final id in node.commentIds) {
                  expect(document.commentsById[id]!.ply, node.ply);
                }
              }
              for (final comment in document.comments) {
                for (final line in comment.lines) {
                  expect(
                    document
                        .nodeAt(comment.ply)!
                        .variationById(line.variationId),
                    isNotNull,
                  );
                }
              }
            }
          }
        }
      });
    }

    fuzz('the envelope', (json) => json);
    fuzz('game', (json) => json['game'] as Map<String, dynamic>);
    fuzz('a critical node', (json) => rawNode(json, 10));
    fuzz(
      'a variation',
      (json) => rawVariation(json, 10, 'v10-refutation'),
      alwaysSupported: true,
    );
    fuzz(
      'a variation move',
      (json) => listOf(rawVariation(json, 10, 'v10-best'), 'moves')[2],
      alwaysSupported: true,
    );
    fuzz(
      'a best move',
      (json) => rawNode(json, 10)['best'] as Map<String, dynamic>,
      alwaysSupported: true,
    );
    fuzz('a comment', (json) => rawComment(json, 10), alwaysSupported: true);
    fuzz(
      'an arrow',
      (json) => listOf(rawComment(json, 10), 'arrows')[1],
      alwaysSupported: true,
    );
    fuzz(
      'the summary',
      (json) => json['summary'] as Map<String, dynamic>,
      alwaysSupported: true,
    );
    fuzz(
      'a lesson',
      (json) => listOf(json['summary'] as Map<String, dynamic>, 'lessons')[0],
      alwaysSupported: true,
    );

    test('a map with keys that are not strings', () {
      final result = AnalysisParser.parse({
        'schema': AnalysisParser.schemaName,
        'schema_version': 1,
        'game': {1: 2},
        'nodes': [
          {1: 2},
        ],
      });
      expect(result, isA<AnalysisInvalid>());
    });
  });
}
