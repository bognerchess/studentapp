// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small key-value settings (not user content; that belongs in the database).
///
/// `SharedPreferencesAsync` needs no start-up await. Tests set
/// `SharedPreferencesAsyncPlatform.instance` to the in-memory implementation
/// or override this provider.
final preferencesProvider = Provider<SharedPreferencesAsync>(
  (ref) => SharedPreferencesAsync(),
);
