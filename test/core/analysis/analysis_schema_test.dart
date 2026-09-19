// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';
import 'dart:io';

import 'package:bogner_chess/core/analysis/analysis_document.dart';
import 'package:flutter_test/flutter_test.dart';

import 'analysis_fixtures.dart';

/// Keeps the Dart enums in step with the vendored JSON Schema: when a
/// re-vendored schema lists a new known value, this fails and says which enum
/// wants a new member (until then the value parses as `unknown`, which is
/// safe, so this is a to-do list and not a production risk).
void main() {
  final schema = jsonDecode(
    File('$vendoredDir/game-analysis.v1.schema.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final defs = schema['\$defs'] as Map<String, dynamic>;

  List<String> knownValues(String def, String property) {
    final properties =
        (defs[def] as Map<String, dynamic>)['properties']
            as Map<String, dynamic>;
    final values = (properties[property] as Map<String, dynamic>);
    return ((values['x-known-values'] ?? values['enum']) as List<dynamic>)
        .cast<String>();
  }

  Set<String> wires(Iterable<String?> values) => values.nonNulls.toSet();

  test('classification', () {
    expect(
      wires(MoveClassification.values.map((v) => v.wire)),
      knownValues('node', 'classification').toSet(),
    );
  });

  test('variation kind', () {
    expect(
      wires(VariationKind.values.map((v) => v.wire)),
      knownValues('variation', 'kind').toSet(),
    );
  });

  test('comment type', () {
    expect(
      wires(CommentType.values.map((v) => v.wire)),
      knownValues('comment', 'type').toSet(),
    );
  });

  test('square and arrow roles', () {
    expect(
      wires(SquareRole.values.map((v) => v.wire)),
      knownValues('square_mark', 'role').toSet(),
    );
    expect(
      wires(ArrowRole.values.map((v) => v.wire)),
      knownValues('arrow', 'role').toSet(),
    );
  });

  test('verification status', () {
    expect(
      wires(VerificationStatus.values.map((v) => v.wire)),
      knownValues('verification', 'status').toSet(),
    );
  });

  test('closed enums: perspective and result', () {
    expect(
      wires(AnalysisPerspective.values.map((v) => v.wire)),
      knownValues('perspective', 'color').toSet(),
    );
    expect(
      wires(GameResult.values.map((v) => v.wire)),
      knownValues('game', 'result').toSet(),
    );
  });

  test('the schema is the version this parser was written for', () {
    final properties = schema['properties'] as Map<String, dynamic>;
    expect(
      (properties['schema'] as Map<String, dynamic>)['const'],
      'bognerchess.game-analysis',
    );
    expect((properties['schema_version'] as Map<String, dynamic>)['const'], 1);
  });
}
