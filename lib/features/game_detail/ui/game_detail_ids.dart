// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/widgets.dart';

/// Semantics identifiers of the game screen (`accessibilityIdentifier` on
/// iOS), for UI tests and the simulator tool.
abstract final class GameDetailIds {
  /// The one button: analyses the game.
  static const String analyse = 'game-analyse';
  static const String openAnalysis = 'game-open-analysis';

  /// Analyses again after a failure. The server resumes where it stopped.
  static const String retryAnalysis = 'game-retry-analysis';

  /// Analyses again after the moves changed.
  static const String reanalyse = 'game-reanalyse';

  /// Writes the coach's text again over a finished analysis. Only shown to
  /// accounts whose usage policy is unlimited, because every run spends a
  /// quota: it is there for developing the coach's voice, not for the player.
  static const String rerunCoach = 'game-rerun-coach';

  /// The bar that says how far the analysis has come.
  static const String progress = 'game-analysis-progress';

  /// The card that says where the analysis of this game stands.
  static const String workflowCard = 'game-workflow-card';

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
