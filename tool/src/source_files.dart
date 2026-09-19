// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// File listing shared by `tool/check_headers.dart` and
/// `tool/check_layers.dart`. Uses `dart:io` only, so the tools run without
/// any package being resolved.
library;

import 'dart:io';

/// True for files a generator wrote, which carry the generator's header.
bool isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.graphql.dart') ||
    path.startsWith('generated/') ||
    path.contains('/generated/');

/// True for paths no check in this repository looks at: vendored code, and
/// the deliberately broken fixture trees of the check tools themselves.
bool isOutOfScope(String path) =>
    path.startsWith('third_party/') ||
    path.contains('/third_party/') ||
    path.startsWith('tool/test_fixtures/');

/// Lists the files below [root] as forward-slash paths relative to it.
///
/// With [useGit] the list is what git tracks plus what it would track
/// (untracked but not ignored), so a file an agent has just written is
/// checked before it is committed. Outside a git repository, and in the
/// tests, the directory is walked instead.
List<String> listFiles(Directory root, {bool useGit = true}) {
  if (useGit) {
    try {
      final result = Process.runSync('git', [
        'ls-files',
        '--cached',
        '--others',
        '--exclude-standard',
      ], workingDirectory: root.path);
      if (result.exitCode == 0) {
        final files = (result.stdout as String)
            .split('\n')
            .where((p) => p.isNotEmpty)
            // A file deleted in the working tree is still listed by git.
            .where((p) => File('${root.path}/$p').existsSync())
            .toList();
        return files..sort();
      }
    } on ProcessException {
      // No git on the PATH: fall through to the directory walk.
    }
  }
  final prefix = root.absolute.path.endsWith('/')
      ? root.absolute.path
      : '${root.absolute.path}/';
  final files = <String>[];
  for (final entity in root.absolute.listSync(recursive: true)) {
    if (entity is! File) continue;
    final relative = entity.path.substring(prefix.length).replaceAll(r'\', '/');
    if (relative.startsWith('.') ||
        relative.startsWith('build/') ||
        relative.contains('/.')) {
      continue;
    }
    files.add(relative);
  }
  return files..sort();
}
