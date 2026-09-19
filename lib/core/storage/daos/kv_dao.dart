// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:drift/drift.dart';

import '../app_database.dart';

part 'kv_dao.g.dart';

/// Small string flags. Without [ownerSub] a key belongs to the installation;
/// with it, to that account, and [AppDatabase.wipeOwner] removes it.
@DriftAccessor(tables: [Kv])
class KvDao extends DatabaseAccessor<AppDatabase> with _$KvDaoMixin {
  KvDao(super.attachedDatabase);

  Future<String?> get(String key, {String? ownerSub}) {
    return _byKey(key, ownerSub).map((row) => row.value).getSingleOrNull();
  }

  Stream<String?> watch(String key, {String? ownerSub}) {
    return _byKey(key, ownerSub).map((row) => row.value).watchSingleOrNull();
  }

  Future<void> set(String key, String value, {String? ownerSub}) {
    return into(kv).insertOnConflictUpdate(
      KvCompanion.insert(key: _storedKey(key, ownerSub), value: value),
    );
  }

  Future<void> remove(String key, {String? ownerSub}) {
    final stored = _storedKey(key, ownerSub);
    return (delete(kv)..where((t) => t.key.equals(stored))).go();
  }

  /// Removes every key of [ownerSub]. Part of [AppDatabase.wipeOwner].
  Future<int> removeAllForOwner(String ownerSub) {
    final prefix = _storedKey('', ownerSub);
    final query = delete(kv)
      ..where((t) => t.key.substr(1, prefix.length).equals(prefix));
    return query.go();
  }

  SimpleSelectStatement<$KvTable, KvEntry> _byKey(
    String key,
    String? ownerSub,
  ) {
    final stored = _storedKey(key, ownerSub);
    return select(kv)..where((t) => t.key.equals(stored));
  }

  /// `app/<key>` or `owner/<length of sub>/<sub>/<key>`. The length keeps one
  /// sub from being a prefix of another one's keys.
  static String _storedKey(String key, String? ownerSub) {
    return ownerSub == null
        ? 'app/$key'
        : 'owner/${ownerSub.length}/$ownerSub/$key';
  }
}
