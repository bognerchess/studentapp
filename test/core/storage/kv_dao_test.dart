// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

void main() {
  late AppDatabase db;
  late KvDao dao;

  setUp(() {
    db = openTestDatabase(FakeClock());
    dao = db.kvDao;
  });

  tearDown(() => db.close());

  test('get, set, overwrite and remove', () async {
    expect(await dao.get('install_marker'), isNull);
    await dao.set('install_marker', '1');
    expect(await dao.get('install_marker'), '1');
    await dao.set('install_marker', '2');
    expect(await dao.get('install_marker'), '2');
    await dao.remove('install_marker');
    expect(await dao.get('install_marker'), isNull);
  });

  test('watch emits changes', () async {
    final seen = <String?>[];
    final sub = dao.watch('flag').listen(seen.add);
    await pumpEventQueue();
    await dao.set('flag', 'on');
    await pumpEventQueue();
    await sub.cancel();

    expect(seen, [null, 'on']);
  });

  test(
    'a key of an owner is separate from the app key and other owners',
    () async {
      await dao.set('ai_consent_seen', 'app');
      await dao.set('ai_consent_seen', '3', ownerSub: alice);
      await dao.set('ai_consent_seen', '2', ownerSub: bob);

      expect(await dao.get('ai_consent_seen'), 'app');
      expect(await dao.get('ai_consent_seen', ownerSub: alice), '3');
      expect(await dao.get('ai_consent_seen', ownerSub: bob), '2');

      await dao.remove('ai_consent_seen', ownerSub: alice);
      expect(await dao.get('ai_consent_seen', ownerSub: alice), isNull);
      expect(await dao.get('ai_consent_seen', ownerSub: bob), '2');
    },
  );

  test('removeAllForOwner is exact about the owner', () async {
    await dao.set('k', 'app');
    await dao.set('k', 'a', ownerSub: 'sub');
    await dao.set('k', 'b', ownerSub: 'sub/1');
    await dao.set('k', 'c', ownerSub: 'su%');

    expect(await dao.removeAllForOwner('sub'), 1);

    expect(await dao.get('k'), 'app');
    expect(await dao.get('k', ownerSub: 'sub'), isNull);
    expect(await dao.get('k', ownerSub: 'sub/1'), 'b');
    expect(await dao.get('k', ownerSub: 'su%'), 'c');
  });
}
