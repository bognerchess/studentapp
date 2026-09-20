// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';
import 'dart:io';

/// Reads the GraphQL response fixtures in `test/fixtures/graphql`:
/// `<Operation>/<scenario>.json`, each the body of a GraphQL response.
///
/// Shared by the mock server and by the `FixtureLink` of the widget tests, so
/// both serve exactly the same data. Plain `dart:io`, no Flutter.
///
/// A fixture may embed another JSON file of `test/fixtures` instead of
/// repeating it: the object `{"$fixture": "analysis/v1/short-game.json"}` is
/// replaced by the content of that file. The GameAnalysis fixtures use it for
/// the vendored analysis documents.
class FixtureStore {
  FixtureStore({String? fixturesRoot})
    : root = Directory(fixturesRoot ?? _findFixturesRoot());

  /// The `test/fixtures` directory.
  final Directory root;

  static const String _refKey = r'$fixture';

  /// The response body of [scenario] for [operation]. Every call decodes the
  /// file again, so the caller may change the result.
  ///
  /// Throws a [FixtureNotFound] that lists the scenarios that do exist.
  Map<String, dynamic> response(String operation, String scenario) {
    final file = File('${root.path}/graphql/$operation/$scenario.json');
    if (!file.existsSync()) {
      throw FixtureNotFound(operation, scenario, scenarios(operation));
    }
    return _resolve(_decode(file)) as Map<String, dynamic>;
  }

  /// The `data` of [response].
  Map<String, dynamic> data(String operation, String scenario) =>
      response(operation, scenario)['data'] as Map<String, dynamic>;

  /// Any JSON file below `test/fixtures`, e.g.
  /// `analysis/v1/forty-move-game.json`.
  Object? json(String relativePath) =>
      _resolve(_decode(File('${root.path}/$relativePath')));

  /// The operations that have fixtures, sorted.
  List<String> operations() {
    final dir = Directory('${root.path}/graphql');
    if (!dir.existsSync()) {
      return const [];
    }
    return [
      for (final entry in dir.listSync())
        if (entry is Directory) entry.uri.pathSegments.lastWhere(_notEmpty),
    ]..sort();
  }

  /// The scenarios of [operation], sorted; empty when there are none.
  List<String> scenarios(String operation) {
    final dir = Directory('${root.path}/graphql/$operation');
    if (!dir.existsSync()) {
      return const [];
    }
    return [
      for (final entry in dir.listSync())
        if (entry is File && entry.path.endsWith('.json'))
          entry.uri.pathSegments.last.replaceFirst(RegExp(r'\.json$'), ''),
    ]..sort();
  }

  static bool _notEmpty(String segment) => segment.isNotEmpty;

  static Object? _decode(File file) => jsonDecode(file.readAsStringSync());

  Object? _resolve(Object? value) {
    if (value is Map<String, dynamic>) {
      final ref = value[_refKey];
      if (ref is String && value.length == 1) {
        return json(ref);
      }
      return {
        for (final MapEntry(:key, :value) in value.entries)
          key: _resolve(value),
      };
    }
    if (value is List) {
      return [for (final item in value) _resolve(item)];
    }
    return value;
  }

  /// `test/fixtures` of the package that contains the working directory or
  /// this script.
  static String _findFixturesRoot() {
    final starts = [
      Directory.current,
      if (Platform.script.scheme == 'file')
        File.fromUri(Platform.script).parent,
    ];
    for (final start in starts) {
      for (
        Directory? dir = start;
        dir != null;
        dir = dir.parent.path == dir.path ? null : dir.parent
      ) {
        final candidate = Directory('${dir.path}/test/fixtures/graphql');
        if (candidate.existsSync()) {
          return '${dir.path}/test/fixtures';
        }
      }
    }
    throw StateError(
      'test/fixtures/graphql not found; run from the repository or pass '
      '--fixtures <dir>',
    );
  }
}

class FixtureNotFound implements Exception {
  const FixtureNotFound(this.operation, this.scenario, this.available);

  final String operation;
  final String scenario;
  final List<String> available;

  @override
  String toString() => available.isEmpty
      ? 'no fixtures for operation "$operation" '
            '(test/fixtures/graphql/$operation/)'
      : 'no fixture "$scenario" for operation "$operation"; there are: '
            '${available.join(', ')}';
}
