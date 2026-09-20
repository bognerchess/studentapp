// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:io';

import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

/// The migration harness. docs/storage.md explains how it is fed.
///
/// `drift_schemas/drift_schema_v<N>.json` is the frozen schema of version N,
/// and `generated/schema_v<N>.dart` is a database class built from it. The
/// tests compare what the app's code really creates with those references.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  final currentVersion = AppDatabase(NativeDatabase.memory()).schemaVersion;

  test('there is a schema dump for every version up to the current one', () {
    expect(
      GeneratedHelper.versions,
      [for (var v = 1; v <= currentVersion; v++) v],
      reason:
          'schemaVersion is $currentVersion. Dump it and regenerate the test '
          'helpers; see "Changing the schema" in docs/storage.md.',
    );
    for (final version in GeneratedHelper.versions) {
      expect(
        File('drift_schemas/drift_schema_v$version.json').existsSync(),
        isTrue,
        reason: 'generated/schema_v$version.dart has no dump next to it',
      );
    }
  });

  test('a fresh install has exactly the dumped schema', () async {
    // Fails when a table changed without a new schema version: the code then
    // creates something else than drift_schemas/ says this version is.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, currentVersion);
  });

  group('upgrades end in the dumped schema', () {
    // Every pair (from, to) of known versions. Empty while version 1 is the
    // only one; from version 2 on this covers each migration automatically.
    const versions = GeneratedHelper.versions;
    for (final (i, from) in versions.indexed) {
      for (final to in versions.skip(i + 1)) {
        test('from $from to $to', () async {
          final schema = await verifier.schemaAt(from);
          final db = AppDatabase(schema.newConnection());
          addTearDown(db.close);
          await verifier.migrateAndValidate(db, to);
        });
      }
    }
  });
}
