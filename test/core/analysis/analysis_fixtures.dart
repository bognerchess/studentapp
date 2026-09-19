// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';
import 'dart:io';

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where the vendored contract files live, relative to the package root
/// (the working directory of `flutter test`).
const String vendoredDir = 'test/fixtures/analysis/v1';

/// Where the hand-made forward-compatibility fixtures live.
const String forwardCompatDir = 'test/fixtures/analysis/forward-compat';

/// The three fixtures of the contract.
const List<String> officialFixtures = [
  'short-game.json',
  'forty-move-game.json',
  'fallback-case.json',
];

String fixtureString(String name, {String dir = vendoredDir}) =>
    File('$dir/$name').readAsStringSync();

/// A fresh, mutable copy of a fixture for a test to break.
Map<String, dynamic> fixtureJson(String name, {String dir = vendoredDir}) =>
    jsonDecode(fixtureString(name, dir: dir)) as Map<String, dynamic>;

/// Parses and expects a supported document.
AnalysisSupported parseSupported(
  Map<String, dynamic> json, {
  bool keepUnknownCommentTypes = false,
}) {
  final result = AnalysisParser.parse(
    json,
    keepUnknownCommentTypes: keepUnknownCommentTypes,
  );
  expect(result, isA<AnalysisSupported>(), reason: '$result');
  return result as AnalysisSupported;
}

/// Parses and expects [AnalysisInvalid]; returns the reason.
String parseInvalid(Map<String, dynamic> json) {
  final result = AnalysisParser.parse(json);
  expect(result, isA<AnalysisInvalid>());
  return (result as AnalysisInvalid).reason;
}

/// The raw node of [ply] in a decoded fixture.
Map<String, dynamic> rawNode(Map<String, dynamic> json, int ply) =>
    (json['nodes'] as List<dynamic>)[ply - 1] as Map<String, dynamic>;

/// The raw comment on [ply] in a decoded fixture.
Map<String, dynamic> rawComment(Map<String, dynamic> json, int ply) =>
    (json['comments'] as List<dynamic>).cast<Map<String, dynamic>>().firstWhere(
      (comment) => comment['ply'] == ply,
    );

/// The raw variation [id] of the node of [ply].
Map<String, dynamic> rawVariation(
  Map<String, dynamic> json,
  int ply,
  String id,
) => (rawNode(json, ply)['variations'] as List<dynamic>)
    .cast<Map<String, dynamic>>()
    .firstWhere((variation) => variation['id'] == id);
