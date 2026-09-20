// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/widgets.dart';

/// Semantics identifiers of the game screen (`accessibilityIdentifier` on
/// iOS), for UI tests and the simulator tool.
abstract final class GameDetailIds {
  static const String analyse = 'game-analyse';
  static const String openAnalysis = 'game-open-analysis';
  static const String retryAnalysis = 'game-retry-analysis';
  static const String jobCard = 'game-job-card';
  static const String delete = 'game-delete';
  static const String limitSheet = 'game-limit-sheet';
  static const String emailRecheck = 'game-email-recheck';
  static const String sheetClose = 'game-sheet-close';
}

/// Puts [identifier] on the child's own semantics node (see WP-25: a bare
/// `Semantics(identifier:)` around a button creates a parent node instead).
class Identified extends StatelessWidget {
  const Identified(this.identifier, {required this.child, super.key});

  final String identifier;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(identifier: identifier, child: child),
    );
  }
}
