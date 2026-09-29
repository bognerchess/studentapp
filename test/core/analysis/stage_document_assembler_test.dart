// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/analysis/stage_document_assembler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'analysis_fixtures.dart';

/// The three stage artifacts, derived from the vendored forty-move game by
/// `test/fixtures/analysis/stages/make_fixtures.py`.
const String _stagesDir = 'test/fixtures/analysis/stages';

Map<String, dynamic> _artifact(String name) =>
    fixtureJson(name, dir: _stagesDir);

void main() {
  late Map<String, dynamic> base;
  late Map<String, dynamic> classification;
  late Map<String, dynamic> deep;

  setUp(() {
    base = _artifact('base-evaluation.json');
    classification = _artifact('base-classification.json');
    deep = _artifact('deep-evaluation.json');
  });

  group('the fixtures themselves', () {
    test('stage 1 marks nothing critical and carries no variations', () {
      final nodes = (base['nodes'] as List).cast<Map<String, dynamic>>();
      expect(nodes, hasLength(80));
      expect(nodes.every((n) => n['is_critical'] == false), isTrue);
      expect(nodes.every((n) => (n['variations'] as List).isEmpty), isTrue);
    });

    test('stage 2 selects a superset of the stage-3 moments', () {
      final selected = StageDocumentAssembler.criticalPliesOf(classification);
      final deepCritical = {
        for (final node in (deep['nodes'] as List).cast<Map<String, dynamic>>())
          if (node['is_critical'] == true) node['ply'] as int,
      };

      expect(selected, containsAll(deepCritical));
      expect(
        selected.difference(deepCritical),
        isNotEmpty,
        reason: 'the deep pass drops some of what stage 2 picked',
      );
    });

    test('stage 3 writes the engine flat, the document nests it', () {
      final engine = deep['engine']! as Map<String, dynamic>;
      expect(engine.keys, contains('pass1_nodes'));
      expect(engine.keys, isNot(contains('pass1')));
    });
  });

  group('build from stage 1 alone', () {
    test('the parser accepts it, and the eval graph is there', () {
      final document = StageDocumentAssembler.build(
        base: base,
        generatedAt: DateTime.utc(2026, 9, 29, 12),
      );
      final parsed = parseSupported(document);

      expect(parsed.warnings, isEmpty);
      expect(parsed.document.schemaVersion, 1);
      expect(parsed.document.nodes, hasLength(80));
      expect(parsed.document.perspective, AnalysisPerspective.black);
      expect(parsed.document.result, GameResult.whiteWins);
      expect(parsed.document.generatedAt, DateTime.utc(2026, 9, 29, 12));
      // Every ply has an eval and a classification: enough for the graph and
      // for the move quality in the move list.
      expect(parsed.document.nodes.every((n) => n.winPctAfter >= 0), isTrue);
      expect(
        parsed.document.nodes
            .map((n) => n.classification)
            .toSet()
            .contains(MoveClassification.blunder),
        isTrue,
      );
    });

    test('nothing is critical and there is no coach text yet', () {
      final parsed = parseSupported(StageDocumentAssembler.build(base: base));

      expect(parsed.document.nodes.any((n) => n.isCritical), isFalse);
      expect(parsed.document.comments, isEmpty);
      expect(parsed.document.lessons, isEmpty);
      expect(parsed.document.coach.model, '');
    });

    test('the artifact is not touched', () {
      final before = jsonEncode(base);
      StageDocumentAssembler.build(base: base, criticalPlies: const {6, 10});
      expect(jsonEncode(base), before);
    });

    test('stage 2 can be folded in at build time', () {
      final plies = StageDocumentAssembler.criticalPliesOf(classification);
      final parsed = parseSupported(
        StageDocumentAssembler.build(base: base, criticalPlies: plies),
      );

      expect(
        parsed.document.nodes.where((n) => n.isCritical).map((n) => n.ply),
        plies.toList()..sort(),
      );
    });
  });

  group('withCriticalPlies', () {
    test('patches a stage-1 document in place after stage 2 lands', () {
      final document = StageDocumentAssembler.build(base: base);
      final plies = StageDocumentAssembler.criticalPliesOf(classification);

      expect(StageDocumentAssembler.withCriticalPlies(document, plies), isTrue);
      final parsed = parseSupported(document);
      expect(
        parsed.document.nodes.where((n) => n.isCritical).map((n) => n.ply),
        plies.toList()..sort(),
      );
    });

    test('is idempotent: the second patch changes nothing', () {
      final document = StageDocumentAssembler.build(base: base);
      final plies = StageDocumentAssembler.criticalPliesOf(classification);

      StageDocumentAssembler.withCriticalPlies(document, plies);
      expect(
        StageDocumentAssembler.withCriticalPlies(document, plies),
        isFalse,
      );
    });

    test('a re-run of stage 2 with another selection takes marks away', () {
      final document = StageDocumentAssembler.build(
        base: base,
        criticalPlies: StageDocumentAssembler.criticalPliesOf(classification),
      );

      expect(
        StageDocumentAssembler.withCriticalPlies(document, const {6}),
        isTrue,
      );
      final parsed = parseSupported(document);
      expect(
        parsed.document.nodes.where((n) => n.isCritical).map((n) => n.ply),
        [6],
      );
    });

    test('a document without nodes is left alone', () {
      final document = <String, dynamic>{'nodes': 'not a list'};
      expect(
        StageDocumentAssembler.withCriticalPlies(document, const {1}),
        isFalse,
      );
    });
  });

  group('build with stage 3', () {
    test('the deep nodes supersede the base ones', () {
      final parsed = parseSupported(
        StageDocumentAssembler.build(base: base, deep: deep),
      );

      // The base nodes carry no variations at all; these do.
      expect(
        parsed.document.nodes.where((n) => n.variations.isNotEmpty),
        isNotEmpty,
      );
      expect(
        parsed.document.nodes.where((n) => n.isCritical).map((n) => n.ply),
        [6, 10, 18, 22, 30, 34, 36, 38],
      );
    });

    test('a stage-2 selection never overrides the settled is_critical', () {
      final parsed = parseSupported(
        StageDocumentAssembler.build(
          base: base,
          deep: deep,
          // Stage 2 picked these two as well; the deep pass dropped them.
          criticalPlies: const {6, 14, 26},
        ),
      );

      expect(
        parsed.document.nodes.where((n) => n.isCritical).map((n) => n.ply),
        [6, 10, 18, 22, 30, 34, 36, 38],
      );
    });

    test('accuracy and the nested engine come from stage 3', () {
      final parsed = parseSupported(
        StageDocumentAssembler.build(base: base, deep: deep),
      );

      expect(parsed.document.accuracyWhite, 91.6);
      expect(parsed.document.accuracyBlack, 89.5);
      expect(parsed.document.engine.name, 'Stockfish 19');
      expect(parsed.document.engine.humanModel, 'maia3-5m');
      expect(parsed.document.engine.pass1Nodes, 400000);
      expect(parsed.document.engine.pass2Nodes, 3000000);
      expect(parsed.document.engine.pass2MultiPv, 3);
      expect(parsed.document.ratingBand, '1200-1400');
    });

    test('stage 3 alone is enough: the base artifact is optional', () {
      final parsed = parseSupported(StageDocumentAssembler.build(deep: deep));

      expect(parsed.warnings, isEmpty);
      expect(parsed.document.nodes, hasLength(80));
      expect(parsed.document.result, GameResult.whiteWins);
      expect(parsed.document.language, 'en');
    });

    test('peer lines survive into the document and stay peer lines', () {
      final parsed = parseSupported(
        StageDocumentAssembler.build(base: base, deep: deep),
      );

      final peers = [
        for (final node in parsed.document.nodes)
          for (final line in node.variations)
            if (line.kind == VariationKind.peerLine) line,
      ];
      expect(peers, isNotEmpty);
      expect(peers.every((l) => l.moves.isNotEmpty), isTrue);
    });

    test('the best line and the refutation are still there', () {
      final parsed = parseSupported(
        StageDocumentAssembler.build(base: base, deep: deep),
      );
      final kinds = {
        for (final node in parsed.document.nodes)
          for (final line in node.variations) line.kind,
      };

      expect(kinds, {
        VariationKind.bestLine,
        VariationKind.refutation,
        VariationKind.alternative,
        VariationKind.peerLine,
      });
    });
  });

  group('the envelope', () {
    test('says which contract it is, at the minor this build assembles', () {
      final document = StageDocumentAssembler.build(base: base);

      expect(document['schema'], AnalysisParser.schemaName);
      expect(document['schema_version'], 1);
      expect(document['schema_minor'], 0);
    });

    test('carries the run id it was built from, when given one', () {
      final document = StageDocumentAssembler.build(
        base: base,
        analysisId: 'run-de',
      );
      expect(parseSupported(document).document.analysisId, 'run-de');
    });

    test('is JSON: what is stored is what is read back', () {
      final document = StageDocumentAssembler.build(base: base, deep: deep);
      final again = AnalysisParser.parseString(jsonEncode(document));

      expect(again, isA<AnalysisSupported>());
      expect((again as AnalysisSupported).warnings, isEmpty);
    });

    test('without any artifact it has no nodes, and the parser says so', () {
      final document = StageDocumentAssembler.build();

      expect(document['nodes'], isEmpty);
      expect(parseInvalid(document), contains('nodes'));
    });

    test('junk in an artifact is read past, never thrown on', () {
      final document = StageDocumentAssembler.build(
        base: {'nodes': 'not a list', 'scan': 42, 'student_color': 7},
        deep: {'nodes': <Object?>[], 'engine': 'no', 'accuracy': 'no'},
      );

      expect(document['nodes'], isEmpty);
      expect(document['engine'], isEmpty);
      expect(document['accuracy'], isEmpty);
      expect(document['language'], 'en');
    });
  });

  group('criticalPliesOf', () {
    test('reads the plies of a classification artifact', () {
      expect(StageDocumentAssembler.criticalPliesOf(classification), {
        6,
        10,
        14,
        18,
        22,
        26,
        30,
        34,
        36,
        38,
      });
    });

    test('a malformed or missing selection list is empty, not a throw', () {
      expect(StageDocumentAssembler.criticalPliesOf(const {}), isEmpty);
      expect(
        StageDocumentAssembler.criticalPliesOf(const {'selections': 'no'}),
        isEmpty,
      );
      expect(
        StageDocumentAssembler.criticalPliesOf(const {
          'selections': [
            {'ply': 'six'},
            {'ply': 0},
            <String, Object?>{},
            {'ply': 6},
          ],
        }),
        {6},
      );
    });
  });
}
