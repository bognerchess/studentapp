// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_headers.dart';
import '../../tool/src/source_files.dart';

// `flutter test` runs with the package root as the working directory.
final Directory good = Directory('tool/test_fixtures/headers/good');
final Directory bad = Directory('tool/test_fixtures/headers/bad');

void main() {
  group('checkHeaders on the fixture trees', () {
    test('accepts own, adapted, generated, vendored and unchecked files', () {
      expect(checkHeaders(good, useGit: false), isEmpty);
      expect(checkHeaders(good, useGit: false, strictSwift: true), isEmpty);
    });

    test('reports every broken Dart file with file:line', () {
      final findings = checkHeaders(bad, useGit: false);
      final errors = findings
          .where((f) => f.severity == Severity.error)
          .map((f) => '${f.path}:${f.line}')
          .toList();
      expect(errors, [
        'integration_test/missing_test.dart:1',
        'lib/adapted_no_provenance.dart:1',
        'lib/adapted_with_permission.dart:4',
        'lib/late_permission.dart:1',
        'lib/missing.dart:1',
        'lib/no_permission.dart:1',
        'lib/spdx_not_first.dart:1',
        'tool/missing.dart:1',
      ]);
    });

    test('a provenance line without a commit sha is only a warning', () {
      final findings = checkHeaders(
        bad,
        useGit: false,
      ).where((f) => f.path == 'lib/adapted_no_sha.dart').toList();
      expect(findings, hasLength(1));
      expect(findings.single.severity, Severity.warning);
      expect(findings.single.line, 3);
    });

    test('Swift findings warn by default and fail with strictSwift', () {
      const swift = [
        'ios/Runner/NoHeader.swift',
        'ios/ShareExtension/NoHeader.swift',
      ];
      List<HeaderFinding> swiftFindings({required bool strict}) => checkHeaders(
        bad,
        useGit: false,
        strictSwift: strict,
      ).where((f) => f.path.endsWith('.swift')).toList();

      final lenient = swiftFindings(strict: false);
      expect(lenient.map((f) => f.path), swift);
      expect(lenient.map((f) => f.severity), everyElement(Severity.warning));

      final strict = swiftFindings(strict: true);
      expect(strict.map((f) => f.path), swift);
      expect(strict.map((f) => f.severity), everyElement(Severity.error));
    });

    test('the finding reads like a compiler message', () {
      final finding = checkHeaders(
        bad,
        useGit: false,
      ).firstWhere((f) => f.path == 'lib/missing.dart');
      expect(
        finding.toString(),
        startsWith('lib/missing.dart:1: error: line 1 must be '),
      );
    });
  });

  group('checkHeader', () {
    test('accepts the three-line header', () {
      expect(
        checkHeader('lib/a.dart', [
          spdxOwn,
          '// Copyright (C) 2026 Bogner Chess',
          '// see $permissionFile.',
        ]),
        isEmpty,
      );
    });

    test('rejects an empty file', () {
      expect(checkHeader('lib/a.dart', const []), hasLength(1));
    });

    test('rejects another licence', () {
      expect(
        checkHeader('lib/a.dart', ['// SPDX-License-Identifier: MIT']),
        hasLength(1),
      );
    });
  });

  group('file selection', () {
    test('generated files are recognised', () {
      expect(isGenerated('lib/a.g.dart'), isTrue);
      expect(isGenerated('lib/a.freezed.dart'), isTrue);
      expect(isGenerated('lib/a.graphql.dart'), isTrue);
      expect(isGenerated('lib/core/l10n/generated/app_l10n.dart'), isTrue);
      expect(isGenerated('lib/features/x/data/generated/a.dart'), isTrue);
      expect(isGenerated('lib/features/x/data/a.dart'), isFalse);
    });

    test('vendored code and the fixture trees are out of scope', () {
      expect(isOutOfScope('third_party/chessground/lib/a.dart'), isTrue);
      expect(isOutOfScope('tool/test_fixtures/headers/bad/lib/a.dart'), isTrue);
      expect(isOutOfScope('tool/check_headers.dart'), isFalse);
    });
  });

  test('the command line exits 1 on the bad tree and 0 on the good one', () {
    ProcessResult run(List<String> args) =>
        Process.runSync('dart', ['tool/check_headers.dart', ...args]);

    final onBad = run(['--root', bad.path]);
    expect(onBad.exitCode, 1);
    expect(onBad.stderr, contains('lib/missing.dart:1: error:'));
    expect(onBad.stderr, contains('ios/Runner/NoHeader.swift:1: warning:'));

    final onGood = run(['--root', good.path, '--strict-swift']);
    expect(onGood.exitCode, 0, reason: '${onGood.stderr}');
    expect(onGood.stdout, contains('check_headers: ok'));

    expect(run(['--no-such-flag']).exitCode, 64);
  });
}
