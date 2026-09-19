// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// The one database of the app.
///
/// A plain provider that is never auto-disposed: two open [AppDatabase]
/// instances on the same file corrupt it. Tests override it with an in-memory
/// database and close that in `tearDown`.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});
