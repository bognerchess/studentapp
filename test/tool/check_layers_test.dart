// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_layers.dart';

// `flutter test` runs with the package root as the working directory.
final Directory good = Directory('tool/test_fixtures/layers/good');
final Directory bad = Directory('tool/test_fixtures/layers/bad');

void main() {
  group('checkLayers on the fixture trees', () {
    test('accepts the allowed imports', () {
      expect(checkLayers(good, useGit: false), isEmpty);
    });

    test('reports every forbidden import with file:line and rule', () {
      final violations = checkLayers(
        bad,
        useGit: false,
      ).map((v) => '${v.path}:${v.line} ${v.rule}').toList();
      expect(violations, [
        'lib/core/auth/conditional.dart:7 chessground',
        'lib/core/ui/game_tile.dart:7 generated-graphql',
        'lib/features/library/data/library_repository.dart:7 graphql',
        'lib/features/library/data/library_repository.dart:8 graphql',
        'lib/features/review/ui/review_screen.dart:7 cross-feature',
        'lib/features/review/ui/review_screen.dart:8 chessground',
        'lib/features/review/ui/review_screen.dart:10 cross-feature',
        'lib/features/review/ui/review_screen.dart:11 generated-graphql',
      ]);
    });

    test('the violation reads like a compiler message', () {
      final violation = checkLayers(
        bad,
        useGit: false,
      ).firstWhere((v) => v.rule == 'cross-feature');
      expect(
        violation.toString(),
        'lib/features/review/ui/review_screen.dart:7: error: [cross-feature] '
        "'package:bogner_chess/features/library/ui/library_screen.dart': "
        "feature 'review' must not import the ui/ layer of feature 'library' "
        '(its domain/ is allowed)',
      );
    });
  });

  group('parseDirectives', () {
    test('reads imports and exports with their lines', () {
      final directives = parseDirectives([
        '// header',
        '',
        "import 'dart:io';",
        'import "package:a/a.dart" as a;',
        "export 'src/b.dart' show B;",
      ]);
      expect(directives.map((d) => '${d.line} ${d.uri}'), [
        '3 dart:io',
        '4 package:a/a.dart',
        '5 src/b.dart',
      ]);
    });

    test('follows a conditional import over several lines', () {
      final directives = parseDirectives([
        "import 'stub.dart'",
        "    if (dart.library.io) 'io.dart'",
        "    if (dart.library.js_interop) 'web.dart';",
      ]);
      expect(directives.map((d) => '${d.line} ${d.uri}'), [
        '1 stub.dart',
        '2 io.dart',
        '3 web.dart',
      ]);
    });

    test('ignores comments', () {
      final directives = parseDirectives([
        "// import 'a.dart';",
        "/* import 'b.dart'; */",
        '/*',
        "import 'c.dart';",
        '*/',
        "import 'd.dart'; // import 'e.dart';",
      ]);
      expect(directives.map((d) => d.uri), ['d.dart']);
    });

    test('stops at the first declaration', () {
      final directives = parseDirectives([
        '@TestOn("vm")',
        'library;',
        "import 'a.dart';",
        "part 'a.g.dart';",
        'const String decoy = """',
        "import 'b.dart';",
        '""";',
      ]);
      expect(directives.map((d) => d.uri), ['a.dart']);
    });
  });

  group('resolveToRepoPath', () {
    test('resolves URIs of this package', () {
      expect(
        resolveToRepoPath(
          'package:bogner_chess/features/a/ui/x.dart',
          'lib/main.dart',
          'bogner_chess',
        ),
        'lib/features/a/ui/x.dart',
      );
    });

    test('resolves relative URIs against the importing file', () {
      expect(
        resolveToRepoPath(
          '../../b/data/repo.dart',
          'lib/features/a/ui/x.dart',
          'bogner_chess',
        ),
        'lib/features/b/data/repo.dart',
      );
      expect(
        resolveToRepoPath('./y.dart', 'lib/features/a/ui/x.dart', 'p'),
        'lib/features/a/ui/y.dart',
      );
    });

    test('returns null for dart: and for other packages', () {
      expect(resolveToRepoPath('dart:io', 'lib/a.dart', 'p'), isNull);
      expect(resolveToRepoPath('package:q/q.dart', 'lib/a.dart', 'p'), isNull);
    });
  });

  group('checkFile', () {
    List<String> rules(String path, String uri) => checkFile(path, [
      "import '$uri';",
    ], packageName: 'bogner_chess').map((v) => v.rule).toList();

    test('a feature may import its own ui and data', () {
      expect(rules('lib/features/a/ui/x.dart', '../data/repo.dart'), isEmpty);
      expect(
        rules(
          'lib/features/a/domain/x.dart',
          'package:bogner_chess/features/a/ui/widgets/w.dart',
        ),
        isEmpty,
      );
    });

    test("a feature may import another feature's domain, nothing else", () {
      const from = 'lib/features/a/data/repo.dart';
      const other = 'package:bogner_chess/features/b';
      expect(rules(from, '$other/domain/model.dart'), isEmpty);
      expect(rules(from, '$other/ui/screen.dart'), ['cross-feature']);
      expect(rules(from, '$other/ui/widgets/w.dart'), ['cross-feature']);
      expect(rules(from, '$other/data/repo.dart'), ['cross-feature']);
    });

    test('code outside features may import any feature', () {
      expect(
        rules(
          'lib/app/router.dart',
          'package:bogner_chess/features/b/ui/screen.dart',
        ),
        isEmpty,
      );
    });

    test('graphql and gql packages belong to lib/core/api', () {
      expect(
        rules('lib/core/api/c.dart', 'package:graphql/client.dart'),
        isEmpty,
      );
      expect(
        rules('lib/core/api/c.dart', 'package:gql_exec/gql_exec.dart'),
        isEmpty,
      );
      expect(rules('lib/core/auth/a.dart', 'package:graphql/client.dart'), [
        'graphql',
      ]);
      expect(rules('lib/core/auth/a.dart', 'package:gql_link/gql_link.dart'), [
        'graphql',
      ]);
    });

    test('chessground belongs to lib/core/chess', () {
      expect(
        rules('lib/core/chess/b.dart', 'package:chessground/chessground.dart'),
        isEmpty,
      );
      expect(
        rules('lib/core/ui/b.dart', 'package:chessground/chessground.dart'),
        ['chessground'],
      );
      expect(
        rules('lib/core/chess/b.dart', 'package:dartchess/dartchess.dart'),
        isEmpty,
      );
    });

    test('data may import generated GraphQL files, ui may not', () {
      expect(rules('lib/features/a/data/m.dart', 'q.graphql.dart'), isEmpty);
      expect(rules('lib/features/a/ui/s.dart', '../data/q.graphql.dart'), [
        'generated-graphql',
      ]);
      expect(rules('lib/features/a/ui/w/s.dart', '../../data/q.graphql.dart'), [
        'generated-graphql',
      ]);
    });
  });

  test('the command line exits 1 on the bad tree and 0 on the good one', () {
    ProcessResult run(List<String> args) =>
        Process.runSync('dart', ['tool/check_layers.dart', ...args]);

    final onBad = run(['--root', bad.path]);
    expect(onBad.exitCode, 1);
    expect(
      onBad.stderr,
      contains(
        'lib/features/review/ui/review_screen.dart:8: error: [chessground]',
      ),
    );

    final onGood = run(['--root', good.path]);
    expect(onGood.exitCode, 0, reason: '${onGood.stderr}');
    expect(onGood.stdout, contains('check_layers: ok'));
  });
}
