// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The `sub` of the signed-in user: the owner of every locally stored row.
/// Null while nobody is signed in.
final currentOwnerProvider = Provider<String?>(
  (ref) => switch (ref.watch(authStateProvider)) {
    SignedIn(:final sub) => sub,
    SignedOut() => null,
  },
);
