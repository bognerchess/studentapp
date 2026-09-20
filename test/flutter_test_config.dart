// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:drift/drift.dart';

/// Runs around every test file.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // drift warns when one database class is created twice in a process,
  // because two instances on one file corrupt it. In tests every pumped app
  // has a provider container, and so a database object, of its own (since
  // WP-30 the app reads its consent state from the database at start-up);
  // none of them shares a file. Without this the warning, with a stack
  // trace, is printed about 150 times per run.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await testMain();
}
