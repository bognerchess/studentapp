// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// The key of the installation id in the `kv` table (no owner: it belongs to
/// the installation, not to an account).
const String kDeviceIdKey = 'device.id';

/// A random id of this installation: created once, kept in the database, the
/// same for every account that signs in here. It says nothing about the
/// hardware and is gone with the app's data.
///
/// The server uses it for rate limits per device (`requestGameAnalysis`), for
/// the push registration (`registerMobileDevice`) and for analytics batches;
/// all three must send the same value, so all three read this provider.
final deviceIdProvider = FutureProvider<String>(
  (ref) => loadOrCreateDeviceId(ref.watch(appDatabaseProvider)),
  // A database that cannot be read does not get better by asking again.
  retry: (_, _) => null,
);

/// Reads the id, or creates and stores it. Two callers at the same time end
/// up with the same id: the second insert loses and reads the first.
Future<String> loadOrCreateDeviceId(
  AppDatabase db, {
  String Function()? generate,
}) {
  return db.transaction(() async {
    final existing = await db.kvDao.get(kDeviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final created = (generate ?? const Uuid().v4)();
    await db.kvDao.set(kDeviceIdKey, created);
    return created;
  });
}
