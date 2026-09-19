// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// Layer-import check. Part of `tool/check.sh`.
///
/// Usage: `dart tool/check_layers.dart [--root <dir>]`
///
/// Looks at the `import` and `export` directives of every hand-written Dart
/// file under `lib/` and enforces four rules:
///
/// 1. `chessground`: only `lib/core/chess/` may import
///    `package:chessground/`. Everything else talks to the board through the
///    wrapper, so an upstream API change touches one directory.
/// 2. `graphql`: only `lib/core/api/` may import `package:graphql/` or any
///    `package:gql*` package.
/// 3. `generated-graphql`: `lib/features/*/ui/` and `lib/core/ui/` must not
///    import a `*.graphql.dart` file. UI code sees domain models; the mappers
///    in `data/` do the conversion.
/// 4. `cross-feature`: a feature must not import another feature's `ui/` or
///    `data/`. Another feature's `domain/` is allowed.
///
/// Generated files and `third_party/` are skipped as sources. `test/` is not
/// checked: a widget test legitimately builds a `gql` link to serve fixtures.
/// Exit code 0 means clean, 1 means at least one violation, 64 bad usage.
library;

import 'dart:io';

import 'src/source_files.dart';

class LayerViolation {
  const LayerViolation(this.path, this.line, this.rule, this.message);

  /// Path relative to the checked root, with forward slashes.
  final String path;

  /// 1-based line of the offending URI.
  final int line;

  /// Short rule id: `chessground`, `graphql`, `generated-graphql` or
  /// `cross-feature`.
  final String rule;
  final String message;

  @override
  String toString() => '$path:$line: error: [$rule] $message';
}

/// One URI named by an `import` or `export` directive.
class Directive {
  const Directive(this.uri, this.line);

  final String uri;
  final int line;
}

final RegExp _directiveStart = RegExp(r'^\s*(import|export)\b');
final RegExp _stringLiteral = RegExp('\'([^\']*)\'|"([^"]*)"');
final RegExp _harmlessLine = RegExp(r'^\s*(@|library\b|part\b|$)');

/// Extracts the URIs of all `import` and `export` directives.
///
/// This is a line scanner, not a parser, which keeps the tool free of
/// dependencies. It knows about comments, about directives that span lines
/// (conditional imports) and it stops at the first declaration, because Dart
/// allows no directive after one. That last point is what keeps a string
/// literal further down that happens to contain `import '...'` from counting.
List<Directive> parseDirectives(List<String> lines) {
  final directives = <Directive>[];
  var inBlockComment = false;
  var inDirective = false;
  var inOtherDirective = false;

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];

    if (inBlockComment) {
      final end = line.indexOf('*/');
      if (end < 0) continue;
      line = line.substring(end + 2);
      inBlockComment = false;
    }
    // Strip block comments that open on this line.
    while (true) {
      final start = line.indexOf('/*');
      if (start < 0) break;
      final end = line.indexOf('*/', start + 2);
      if (end < 0) {
        line = line.substring(0, start);
        inBlockComment = true;
        break;
      }
      line = line.substring(0, start) + line.substring(end + 2);
    }
    // Strip a line comment. A URI never contains "//" except after a scheme
    // colon ("package:" has none), so this cannot cut a directive short.
    final comment = line.indexOf('//');
    if (comment >= 0) line = line.substring(0, comment);

    if (inOtherDirective) {
      if (line.contains(';')) inOtherDirective = false;
      continue;
    }
    if (!inDirective) {
      if (_directiveStart.hasMatch(line)) {
        inDirective = true;
      } else if (_harmlessLine.hasMatch(line)) {
        // `library`, `part` and annotations may span lines too.
        if (line.trim().isNotEmpty && !line.contains(';')) {
          inOtherDirective = !line.trimLeft().startsWith('@');
        }
        continue;
      } else {
        break; // First declaration: no directive can follow.
      }
    }
    for (final match in _stringLiteral.allMatches(line)) {
      directives.add(Directive(match.group(1) ?? match.group(2)!, i + 1));
    }
    if (line.contains(';')) inDirective = false;
  }
  return directives;
}

/// Resolves [uri], as written in the file [fromPath], to a path relative to
/// the repository root (`lib/...`). Returns null for `dart:` URIs and for
/// other packages.
String? resolveToRepoPath(String uri, String fromPath, String packageName) {
  if (uri.startsWith('package:$packageName/')) {
    return 'lib/${uri.substring('package:$packageName/'.length)}';
  }
  if (uri.contains(':')) return null;

  final segments = fromPath.split('/')..removeLast();
  for (final part in uri.split('/')) {
    if (part == '.' || part.isEmpty) continue;
    if (part == '..') {
      if (segments.isEmpty) return null;
      segments.removeLast();
    } else {
      segments.add(part);
    }
  }
  return segments.join('/');
}

final RegExp _featurePath = RegExp(r'^lib/features/([^/]+)/(?:(.*)/)?[^/]*$');

/// The feature a `lib/features/<feature>/...` path belongs to, or null.
String? featureOf(String path) => _featurePath.firstMatch(path)?.group(1);

bool _isInLayer(String path, String layer) {
  final match = _featurePath.firstMatch(path);
  if (match == null) return false;
  final inner = match.group(2) ?? '';
  return inner == layer || inner.startsWith('$layer/');
}

/// Checks the directives of one file. [path] is relative to the repository
/// root and starts with `lib/`.
List<LayerViolation> checkFile(
  String path,
  List<String> lines, {
  required String packageName,
}) {
  final violations = <LayerViolation>[];
  final feature = featureOf(path);
  // Any ui/ directory inside a feature counts, however deeply it is nested.
  final isUi =
      path.startsWith('lib/core/ui/') ||
      (path.startsWith('lib/features/') && path.contains('/ui/'));

  for (final directive in parseDirectives(lines)) {
    final uri = directive.uri;
    void report(String rule, String message) => violations.add(
      LayerViolation(path, directive.line, rule, "'$uri': $message"),
    );

    if (uri.startsWith('package:chessground/') &&
        !path.startsWith('lib/core/chess/')) {
      report(
        'chessground',
        'only lib/core/chess/ may import chessground; use the BoardView '
            'wrapper from lib/core/chess/ instead',
      );
    }
    if ((uri.startsWith('package:graphql/') || uri.startsWith('package:gql')) &&
        !path.startsWith('lib/core/api/')) {
      report(
        'graphql',
        'only lib/core/api/ may import graphql or gql packages',
      );
    }
    if (isUi && uri.endsWith('.graphql.dart')) {
      report(
        'generated-graphql',
        'UI code must not see generated GraphQL types; map them to domain '
            'models in data/*_mapper.dart',
      );
    }
    if (feature != null) {
      final target = resolveToRepoPath(uri, path, packageName);
      final targetFeature = target == null ? null : featureOf(target);
      if (target != null && targetFeature != null && targetFeature != feature) {
        for (final layer in const ['ui', 'data']) {
          if (_isInLayer(target, layer)) {
            report(
              'cross-feature',
              "feature '$feature' must not import the $layer/ layer of "
                  "feature '$targetFeature' (its domain/ is allowed)",
            );
          }
        }
      }
    }
  }
  return violations;
}

/// Reads `name:` from the `pubspec.yaml` below [root].
String readPackageName(Directory root) {
  final pubspec = File('${root.path}/pubspec.yaml');
  if (pubspec.existsSync()) {
    for (final line in pubspec.readAsLinesSync()) {
      final match = RegExp(r'^name:\s*(\S+)').firstMatch(line);
      if (match != null) return match.group(1)!;
    }
  }
  return 'bogner_chess';
}

/// Runs the layer check over every hand-written Dart file below `lib/`.
List<LayerViolation> checkLayers(Directory root, {bool useGit = true}) {
  final packageName = readPackageName(root);
  final violations = <LayerViolation>[];
  for (final path in listFiles(root, useGit: useGit)) {
    if (!path.startsWith('lib/') || !path.endsWith('.dart')) continue;
    if (isOutOfScope(path) || isGenerated(path)) continue;
    final lines = File('${root.path}/$path').readAsLinesSync();
    violations.addAll(checkFile(path, lines, packageName: packageName));
  }
  return violations;
}

void main(List<String> args) {
  var root = Directory.current;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--root' when i + 1 < args.length:
        root = Directory(args[++i]);
      default:
        stderr.writeln('usage: dart tool/check_layers.dart [--root <dir>]');
        exit(64);
    }
  }

  final violations = checkLayers(root);
  for (final violation in violations) {
    stderr.writeln(violation);
  }
  if (violations.isNotEmpty) {
    stderr.writeln(
      'check_layers: ${violations.length} violation(s). The rules are '
      'explained in CLAUDE.md under "Architecture rules".',
    );
    exit(1);
  }
  stdout.writeln('check_layers: ok');
}
