// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/storage/preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Preferences key of the installation id.
const String kDeviceIdKey = 'device_id';

/// A random id of this installation (UUID v4), created on first use and kept
/// in the preferences. It names the installation towards the server (push
/// registration, analytics batches, consent records). It is not a hardware
/// id: deleting the app, or restoring it on another phone without the
/// preferences, gives a new one.
final deviceIdProvider = FutureProvider<String>((ref) async {
  final preferences = ref.watch(preferencesProvider);
  final existing = await preferences.getString(kDeviceIdKey);
  if (existing != null && existing.isNotEmpty) {
    return existing;
  }
  final created = const Uuid().v4();
  await preferences.setString(kDeviceIdKey, created);
  return created;
});
