// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/api/usage_api.dart';
import 'package:bogner_chess/core/app_foreground.dart';
import 'package:bogner_chess/features/library/domain/owner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:bogner_chess/core/api/usage_api.dart'
    show AnalysisUsage, UsagePolicy;

/// The analysis quota of the signed-in user (LIM-2).
///
/// Loaded when first watched, again whenever the app comes back to the
/// foreground while somebody watches, and after every analysis request
/// (`ref.invalidate(usageProvider)`). The numbers are advisory; the server
/// decides.
final usageProvider = FutureProvider.autoDispose<AnalysisUsage>((ref) {
  // Another account has another quota.
  ref.watch(currentOwnerProvider);
  final lifecycle = AppForeground(onResume: ref.invalidateSelf);
  ref.onDispose(lifecycle.dispose);
  return ref.watch(usageApiProvider).usage();
  // The widget shows nothing on an error; the next resume or request asks
  // again.
}, retry: (_, _) => null);
