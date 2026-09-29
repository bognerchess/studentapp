// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'analysis_parser.dart' show AnalysisParser;

/// Turns the artifacts of the free engine stages into a document the existing
/// [AnalysisParser] reads, so the review screen shows the engine's work long
/// before the coach has written anything.
///
/// The pieces fit because a stage artifact's `nodes` are the document's own
/// node model: chess-ai dumps `$defs/node` of `game-analysis.v1.schema.json`
/// into them. What is missing is the envelope around them, and one shape
/// difference — a stage-3 artifact carries `engine` flat (`pass1_nodes`,
/// `pass2_nodes`, `pass2_multipv`) while the document nests it.
///
/// What each stage adds to what the review screen can show:
///
/// | Stage | What the document then has |
/// | --- | --- |
/// | 1, base evaluation | Every ply with its evals and classification: the eval graph, the best-move arrow, the quality of each move. `is_critical` is always false here. |
/// | 2, base classification | Which plies are worth a closer look: the key-moment navigation and the markers on the graph. |
/// | 3, deep evaluation | Variations, accuracy, and the final `is_critical`: the line panel and the quality table. |
/// | 4, coaching | The comments and the lessons, and with them the `!` glyph on a positive moment — which needs a comment and is therefore absent until the coach has run. |
///
/// Everything here is pure: no artifact is changed, and the result is plain
/// JSON, ready for `cached_analyses.payload`.
abstract final class StageDocumentAssembler {
  /// The major version of the documents this builds. It is the contract the
  /// parser knows, not the minor of whatever produced the artifacts: an
  /// assembled document uses only the parts of the node model that have been
  /// there since minor 0.
  static const int schemaVersion = 1;
  static const int schemaMinor = 0;

  /// A document from what the engine stages have produced so far.
  ///
  /// [base] is a base-evaluation artifact, [deep] a deep-evaluation one; pass
  /// whichever are stored. The deep nodes win when both are there, because
  /// they carry the variations and the settled `is_critical`. [criticalPlies]
  /// comes from a base classification ([criticalPliesOf]) and is used only
  /// while there is no deep artifact yet.
  ///
  /// The result is a document, not a promise that it is a valid one: with no
  /// usable nodes it comes out with an empty `nodes` list, which the parser
  /// rejects. Callers parse before they store.
  static Map<String, dynamic> build({
    Map<String, dynamic>? base,
    Map<String, dynamic>? deep,
    Set<int> criticalPlies = const {},
    DateTime? generatedAt,
    String analysisId = '',
  }) {
    final context = _map(deep?['context']);
    final scanGame = _map(_map(base?['scan'])?['game']);

    final deepNodes = _list(deep?['nodes']);
    final fromDeep = deepNodes != null && deepNodes.isNotEmpty;
    final rawNodes = fromDeep ? deepNodes : (_list(base?['nodes']) ?? const []);

    final nodes = <Map<String, dynamic>>[];
    for (final raw in rawNodes) {
      final node = _map(raw);
      if (node == null) continue;
      final copy = Map<String, dynamic>.of(node);
      // Stage 1 sets `is_critical` false on every node, because it runs
      // before anything is selected; stage 3 sets the final value.
      if (!fromDeep) {
        copy['is_critical'] = criticalPlies.contains(_int(copy['ply']));
      }
      // There are no comments in an engine-only document, and a node that
      // pointed at one would only produce a parser warning.
      copy['comment_ids'] = const <String>[];
      nodes.add(copy);
    }

    final color =
        _string(context?['student_color']) ?? _string(base?['student_color']);
    final band = _string(context?['rating_band']);

    return {
      'schema': AnalysisParser.schemaName,
      'schema_version': schemaVersion,
      'schema_minor': schemaMinor,
      'analysis_id': analysisId,
      'generated_at': (generatedAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'language': _string(context?['language']) ?? 'en',
      'perspective': {'color': ?color, 'rating_band': ?band},
      'engine': _engine(_map(deep?['engine'])),
      // No coach has run. The empty object keeps the envelope's shape; the
      // parser reads every field of it as "not known".
      'coach': const <String, dynamic>{},
      'game': {
        'start_fen': scanGame?['start_fen'],
        'ply_count': nodes.length,
        'result':
            ?(_string(scanGame?['result']) ?? _string(context?['result'])),
      },
      'accuracy': _map(deep?['accuracy']) ?? const <String, dynamic>{},
      'nodes': nodes,
      'comments': const <Map<String, dynamic>>[],
      'summary': const {'lessons': <Map<String, dynamic>>[]},
    };
  }

  /// Marks the plies a base classification picked, in a document that was
  /// built from a base evaluation alone.
  ///
  /// This is the cheap half of the pipeline landing: stage 2 is a handful of
  /// ply numbers, so there is no reason to rebuild the document or to fetch
  /// stage 1 again. Idempotent, and it leaves a document that already has its
  /// deep nodes alone — those carry the settled `is_critical`.
  ///
  /// Returns whether anything changed, so a caller can skip the write.
  static bool withCriticalPlies(Map<String, dynamic> document, Set<int> plies) {
    final nodes = _list(document['nodes']);
    if (nodes == null) return false;
    var changed = false;
    for (final raw in nodes) {
      final node = _map(raw);
      if (node == null) continue;
      final wanted = plies.contains(_int(node['ply']));
      if (node['is_critical'] != wanted) {
        node['is_critical'] = wanted;
        changed = true;
      }
    }
    return changed;
  }

  /// The plies a base-classification artifact picked as worth a closer look.
  ///
  /// These are a superset of the moments stage 3 ends up describing: the deep
  /// pass drops the ones that do not hold up. Before stage 3 they are the
  /// best the app can mark.
  static Set<int> criticalPliesOf(Map<String, dynamic> classification) {
    final selections = _list(classification['selections']);
    if (selections == null) return const {};
    return {
      for (final raw in selections)
        if (_int(_map(raw)?['ply']) case final ply? when ply >= 1) ply,
    };
  }

  /// Flat to nested: `{name, pass1_nodes, pass2_nodes, pass2_multipv,
  /// human_model}` as the deep-evaluation artifact writes it, into the
  /// `{name, human_model, pass1: {nodes}, pass2: {nodes, multipv}}` the
  /// document contract uses.
  ///
  /// A key that is not there is left out rather than guessed; the parser
  /// reads a missing engine number as null and the UI does not show it.
  static Map<String, dynamic> _engine(Map<String, dynamic>? raw) {
    if (raw == null) return const {};
    final pass1Nodes = _int(raw['pass1_nodes']);
    final pass2Nodes = _int(raw['pass2_nodes']);
    final multiPv = _int(raw['pass2_multipv']);
    return {
      'name': ?_string(raw['name']),
      'human_model': ?_string(raw['human_model']),
      if (pass1Nodes != null) 'pass1': {'nodes': pass1Nodes},
      if (pass2Nodes != null || multiPv != null)
        'pass2': {'nodes': ?pass2Nodes, 'multipv': ?multiPv},
    };
  }

  static Map<String, dynamic>? _map(Object? value) => switch (value) {
    final Map<String, dynamic> value => value,
    final Map<Object?, Object?> value => value.cast<String, dynamic>(),
    _ => null,
  };

  static List<dynamic>? _list(Object? value) =>
      value is List<dynamic> ? value : null;

  static String? _string(Object? value) => value is String ? value : null;

  static int? _int(Object? value) => switch (value) {
    final int value => value,
    final double value when value == value.roundToDouble() => value.round(),
    _ => null,
  };
}
