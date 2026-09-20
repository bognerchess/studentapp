// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// A clock that only moves when the test says so. Whole seconds, because that
/// is what the database keeps.
class FakeClock {
  FakeClock([DateTime? start]) : _now = start ?? DateTime.utc(2026, 9, 19, 12);

  DateTime _now;

  DateTime call() => _now;

  void advance(Duration by) => _now = _now.add(by);
}

/// An empty in-memory database on [clock].
AppDatabase openTestDatabase(FakeClock clock) {
  // drift warns when one database class is created twice, because two
  // instances on the same file corrupt it. Every instance here has an
  // in-memory database of its own.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    // `closeStreamsSynchronously`: without it drift tears its streams down on
    // a timer, and a widget test that ends while one is pending fails with
    // "A Timer is still pending even after the widget tree was disposed".
    // Harmless for a plain unit test, required for anything that pumps a
    // widget tree.
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
    clock: clock.call,
  );
}

const alice = 'sub-alice';
const bob = 'sub-bob';
