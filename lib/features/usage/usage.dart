// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// The public face of the usage feature: what other features (game detail,
/// settings) import. The layer check forbids reaching into another feature's
/// `ui/` directly; this file is the sanctioned way in.
library;

export 'domain/usage_providers.dart';
export 'ui/usage_summary.dart';
