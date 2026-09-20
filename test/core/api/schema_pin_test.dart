// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// `graphql/schema.graphql` is a byte copy of the backend's mobile contract.
/// Nobody edits it here. A refresh is deliberate: copy the new file, update
/// this checksum and `graphql/SCHEMA_SOURCE.md`, run `tool/gen.sh`, fix what
/// no longer compiles.
const String kSchemaSha256 =
    '96803b4c0e4cae0933d9a0072a0a99ac4fc930542e83d2f437f71a7369e37df8';

void main() {
  test('graphql/schema.graphql is the pinned contract', () {
    final bytes = File('graphql/schema.graphql').readAsBytesSync();
    expect(
      sha256.convert(bytes).toString(),
      kSchemaSha256,
      reason:
          'The schema copy changed. If that is a deliberate refresh, follow '
          'graphql/SCHEMA_SOURCE.md; otherwise restore the file.',
    );
  });

  test('SCHEMA_SOURCE.md names the same checksum', () {
    final notes = File('graphql/SCHEMA_SOURCE.md').readAsStringSync();
    expect(notes, contains(kSchemaSha256));
  });

  test('every operation the design lists has a document', () {
    final text = [
      for (final file in Directory('graphql/operations').listSync())
        if (file is File && file.path.endsWith('.graphql'))
          file.readAsStringSync(),
    ].join('\n');
    final operations = RegExp(
      r'^(?:query|mutation)\s+(\w+)',
      multiLine: true,
    ).allMatches(text).map((m) => m[1]).toSet();
    expect(operations, {
      'MobileConfig',
      'MyMobileGames',
      'GameById',
      'ImportMobileGame',
      'DeleteChessGame',
      'RequestGameAnalysis',
      'AnalysisJob',
      'MyActiveAnalysisJobs',
      'GameAnalysis',
      'SubmitCoachCommentFeedback',
      'MyAnalysisUsage',
      'RegisterMobileDevice',
      'UnregisterMobileDevice',
      'TrackMobileEvents',
      'LegalDocument',
      'MyAiConsent',
      'MyConsent',
      'RecordAiConsent',
      'RecordConsent',
      'DeleteMyAccount',
    });
  });

  test('every mutation selects the type name of its errors', () {
    for (final file in Directory(
      'graphql/operations',
    ).listSync().whereType<File>()) {
      final text = file.readAsStringSync();
      final mutations = RegExp(
        r'^mutation\s',
        multiLine: true,
      ).allMatches(text);
      final selections = RegExp(r'errors \{\s+__typename').allMatches(text);
      expect(selections.length, mutations.length, reason: file.path);
    }
  });
}
