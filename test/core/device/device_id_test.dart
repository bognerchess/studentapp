// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/device/device_id.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase(FakeClock()));
  tearDown(() => db.close());

  test('created once as a UUID, then always the same', () async {
    final first = await loadOrCreateDeviceId(db);
    expect(
      first,
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[0-9a-f-]{17}$')),
    );
    expect(await loadOrCreateDeviceId(db), first);
    expect(await db.kvDao.get(kDeviceIdKey), first);
  });

  test('parallel first calls agree', () async {
    var n = 0;
    final ids = await Future.wait([
      for (var i = 0; i < 5; i++)
        loadOrCreateDeviceId(db, generate: () => 'id-${n++}'),
    ]);
    expect(ids.toSet(), hasLength(1));
  });

  test('belongs to the installation: signing out keeps it', () async {
    final id = await loadOrCreateDeviceId(db);
    await db.wipeOwner(alice);
    expect(await loadOrCreateDeviceId(db), id);
  });

  test('the provider serves the stored id', () async {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final id = await container.read(deviceIdProvider.future);
    expect(id, await db.kvDao.get(kDeviceIdKey));
    expect(await container.read(deviceIdProvider.future), id);
  });
}
