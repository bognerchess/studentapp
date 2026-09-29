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

  group('1 to 2: the staged analysis columns', () {
    /// A version-1 database with one cached analysis and one pending job.
    Future<AppDatabase> upgradedFromV1() async {
      final schema = await verifier.schemaAt(1);
      schema.rawDatabase.execute(
        'INSERT INTO cached_analyses '
        '(game_id, owner_sub, schema_version, schema_minor, payload, '
        'fetched_at) VALUES (?, ?, ?, ?, ?, ?)',
        ['g1', 'sub-alice', 1, 3, '{"schema":"x"}', 1758283200],
      );
      schema.rawDatabase.execute(
        'INSERT INTO pending_jobs '
        '(job_id, game_id, owner_sub, state, created_at) '
        'VALUES (?, ?, ?, ?, ?)',
        ['j1', 'g1', 'sub-alice', 'queued', 1758283200],
      );
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 2);
      return db;
    }

    test(
      'a row written before the staged pipeline is a coach document',
      () async {
        final db = await upgradedFromV1();

        final row = (await db.analysisCacheDao.get('sub-alice', 'g1'))!;
        // Version 1 had no other kind, so this is what the row always meant.
        expect(row.source, AnalysisSource.coach);
        expect(row.stage, null);
        expect(row.stageRunIds, null);
        // And nothing else about it moved.
        expect(row.payload, '{"schema":"x"}');
        expect(row.schemaMinor, 3);
      },
    );

    test('an engine assembly still cannot write over such a row', () async {
      final db = await upgradedFromV1();

      expect(
        await db.analysisCacheDao.putEngine(
          'sub-alice',
          'g1',
          schemaVersion: 1,
          schemaMinor: 0,
          payload: 'assembled',
          stage: 'BASE_EVALUATION',
          stageRunIds: '{}',
        ),
        isFalse,
      );
    });

    test('pending_workflows is there and empty, and usable', () async {
      final db = await upgradedFromV1();

      expect(await db.pendingWorkflowsDao.getActive('sub-alice'), isEmpty);
      await db.pendingWorkflowsDao.upsert(
        'sub-alice',
        gameId: 'g1',
        targetStage: 'DEEP_EVALUATION',
      );
      expect(await db.pendingWorkflowsDao.getActive('sub-alice'), hasLength(1));
    });

    test('the jobs of version 1 are left where they are', () async {
      final db = await upgradedFromV1();

      // B12 of WP-60 drops pending_jobs; until then a job that was in flight
      // over the upgrade still is.
      expect(await db.pendingJobsDao.getActive('sub-alice'), hasLength(1));
    });
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
