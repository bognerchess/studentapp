// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// The public face of the game screen: what other features import.
///
/// Asking the coach is one flow, with one set of sheets for the quota, the
/// e-mail address and the AI consent, and it lives here because this is the
/// screen it was written for. The review screen offers the same thing next to
/// the engine analysis, and the layer check forbids reaching into another
/// feature's `ui/` directly; this file is the sanctioned way in, the way
/// `usage.dart` is for the quota line.
library;

export 'domain/game_detail_controller.dart';
export 'ui/analysis_request_flow.dart' show runCoachRequest, runFreeChain;
