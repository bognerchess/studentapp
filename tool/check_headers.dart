// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// Licence-header check. Part of `tool/check.sh`.
///
/// Usage: `dart tool/check_headers.dart [--strict-swift] [--root <dir>]`
///
/// Every Dart file under `lib/`, `test/`, `tool/` and `integration_test/`
/// must start with one of two headers:
///
/// * own code: line 1 is `// SPDX-License-Identifier: GPL-3.0-or-later`, and
///   one of the first five lines names `LICENSE-APP-STORE-PERMISSION.md`;
/// * code adapted from lichess: line 1 is
///   `// SPDX-License-Identifier: GPL-3.0-only`, and one of the first ten
///   lines is a provenance line containing `Adapted from `. Such a file must
///   not name the app-store permission, because that permission is not ours
///   to give for somebody else's code.
///
/// Swift files under `ios/Runner/` and `ios/ShareExtension/` follow the same
/// rules. Until the iOS work package has added its headers a Swift finding is
/// only a warning; `--strict-swift` turns it into an error.
///
/// Generated files and `third_party/` are skipped. Exit code 0 means clean,
/// 1 means at least one error, 64 means bad usage.
library;

import 'dart:io';

import 'src/source_files.dart';

const String spdxOwn = '// SPDX-License-Identifier: GPL-3.0-or-later';
const String spdxAdapted = '// SPDX-License-Identifier: GPL-3.0-only';
const String permissionFile = 'LICENSE-APP-STORE-PERMISSION.md';
const String provenanceMarker = 'Adapted from ';

/// The permission reference has to be this close to the top of the file.
const int permissionWindow = 5;

/// The provenance line has to be this close to the top of the file.
const int provenanceWindow = 10;

const List<String> dartRoots = ['lib/', 'test/', 'tool/', 'integration_test/'];
const List<String> swiftRoots = ['ios/Runner/', 'ios/ShareExtension/'];

final RegExp _provenanceWithSha = RegExp(r'Adapted from \S+@[0-9a-f]{7,40}\b');

enum Severity { error, warning }

class HeaderFinding {
  const HeaderFinding(this.path, this.line, this.severity, this.message);

  /// Path relative to the checked root, with forward slashes.
  final String path;

  /// 1-based line the finding points at.
  final int line;
  final Severity severity;
  final String message;

  @override
  String toString() =>
      '$path:$line: ${severity == Severity.error ? 'error' : 'warning'}: '
      '$message';
}

bool _isCheckedDart(String path) =>
    path.endsWith('.dart') && dartRoots.any(path.startsWith);

bool _isCheckedSwift(String path) =>
    path.endsWith('.swift') && swiftRoots.any(path.startsWith);

/// Checks the first lines of one file. [path] is only used for reporting and
/// to tell Swift from Dart.
List<HeaderFinding> checkHeader(
  String path,
  List<String> lines, {
  bool strictSwift = false,
}) {
  final severity = path.endsWith('.swift') && !strictSwift
      ? Severity.warning
      : Severity.error;
  final findings = <HeaderFinding>[];
  void report(int line, String message) =>
      findings.add(HeaderFinding(path, line, severity, message));

  final first = lines.isEmpty ? '' : lines.first.trimRight();
  final head = lines.take(provenanceWindow).toList();
  final permissionLine = head.indexWhere((l) => l.contains(permissionFile));

  if (first == spdxOwn) {
    if (permissionLine < 0 || permissionLine >= permissionWindow) {
      report(
        1,
        'own code must name $permissionFile within the first '
        '$permissionWindow lines',
      );
    }
  } else if (first == spdxAdapted) {
    final provenanceLine = head.indexWhere((l) => l.contains(provenanceMarker));
    if (provenanceLine < 0) {
      report(
        1,
        'a GPL-3.0-only file must carry an "$provenanceMarker<repo>/<path>'
        '@<commit sha>" line within the first $provenanceWindow lines',
      );
    } else if (!_provenanceWithSha.hasMatch(head[provenanceLine])) {
      findings.add(
        HeaderFinding(
          path,
          provenanceLine + 1,
          Severity.warning,
          'the provenance line names no commit sha '
          '(expected "$provenanceMarker<repo>/<path>@<commit sha>")',
        ),
      );
    }
    if (permissionLine >= 0) {
      report(
        permissionLine + 1,
        'adapted code stays GPL-3.0-only and must not claim the app-store '
        'permission',
      );
    }
  } else {
    report(
      1,
      'line 1 must be "$spdxOwn" (own code) or "$spdxAdapted" (adapted code)',
    );
  }
  return findings;
}

/// Runs the header check over everything below [root].
List<HeaderFinding> checkHeaders(
  Directory root, {
  bool strictSwift = false,
  bool useGit = true,
}) {
  final findings = <HeaderFinding>[];
  for (final path in listFiles(root, useGit: useGit)) {
    if (isOutOfScope(path) || isGenerated(path)) continue;
    if (!_isCheckedDart(path) && !_isCheckedSwift(path)) continue;
    final lines = File('${root.path}/$path').readAsLinesSync();
    findings.addAll(checkHeader(path, lines, strictSwift: strictSwift));
  }
  return findings;
}

void main(List<String> args) {
  var strictSwift = false;
  var root = Directory.current;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--strict-swift':
        strictSwift = true;
      case '--root' when i + 1 < args.length:
        root = Directory(args[++i]);
      default:
        stderr.writeln(
          'usage: dart tool/check_headers.dart [--strict-swift] [--root <dir>]',
        );
        exit(64);
    }
  }

  final findings = checkHeaders(root, strictSwift: strictSwift);
  for (final finding in findings) {
    stderr.writeln(finding);
  }
  final errors = findings.where((f) => f.severity == Severity.error).length;
  final warnings = findings.length - errors;
  if (errors > 0) {
    stderr.writeln(
      'check_headers: $errors error(s), $warnings warning(s). Own files start '
      'with the three-line header of lib/main.dart.',
    );
    exit(1);
  }
  stdout.writeln(
    warnings > 0
        ? 'check_headers: ok, $warnings warning(s)'
              '${strictSwift ? '' : ' (Swift headers are not enforced without --strict-swift)'}'
        : 'check_headers: ok',
  );
}
