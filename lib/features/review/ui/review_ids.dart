// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/widgets.dart';

/// Semantics identifiers of the review screen (`accessibilityIdentifier` on
/// iOS), for UI automation and tests. Squares are `board-square-e4`.
abstract final class ReviewIds {
  static const String first = 'review-first';
  static const String previous = 'review-prev';
  static const String next = 'review-next';
  static const String last = 'review-last';
  static const String previousMoment = 'review-prev-moment';
  static const String nextMoment = 'review-next-moment';

  static const String menu = 'review-menu';
  static const String menuBestArrow = 'review-menu-best-arrow';
  static const String menuPlayedArrow = 'review-menu-played-arrow';
  static const String menuFlip = 'review-menu-flip';

  static const String graph = 'review-eval-graph';
  static const String updateBanner = 'review-update-banner';

  static const String tabCoach = 'review-tab-coach';
  static const String tabMoves = 'review-tab-moves';
  static const String tabSummary = 'review-tab-summary';

  /// The card of the comment on screen; its children are below.
  static const String commentCard = 'comment-card';
  static const String thumbUp = 'comment-thumb-up';
  static const String thumbDown = 'comment-thumb-down';

  /// The engine fact shown on a ply without a comment.
  static const String engineFact = 'review-engine-fact';

  /// The button on a ply without a comment: next key moment, or the summary
  /// after the last one.
  static const String coachNext = 'review-coach-next';

  static const String linePrevious = 'line-prev';
  static const String lineNext = 'line-next';
  static const String lineExit = 'line-exit';
  static const String lineEval = 'line-eval';

  /// "Show line" button of variation [variationId]: `comment-line-v6-best`.
  static String commentLine(String variationId) => 'comment-line-$variationId';

  /// Move [index] (1-based) of the open line: `line-move-1`.
  static String lineMove(int index) => 'line-move-$index';

  /// A move of the move list: `review-move-12`.
  static String move(int ply) => 'review-move-$ply';

  /// Lesson card [number] (1-based): `review-lesson-1`.
  static String lesson(int number) => 'review-lesson-$number';

  /// Evidence chip of lesson [number] for [ply]: `review-lesson-1-ply-10`.
  static String lessonEvidence(int number, int ply) =>
      'review-lesson-$number-ply-$ply';
}

/// One semantics node with an identifier around a control, in the way
/// `BoardView` labels its squares: automation finds the identifier, a screen
/// reader hears [label], and both activate [onTap].
class ReviewIdentified extends StatelessWidget {
  const ReviewIdentified({
    super.key,
    required this.identifier,
    required this.label,
    required this.onTap,
    required this.child,
    this.selected,
    this.toggled,
  });

  final String identifier;
  final String label;

  /// Null marks the control as disabled.
  final VoidCallback? onTap;

  /// For a control that is one of several choices (a tab, a move).
  final bool? selected;

  /// For an on/off control (a thumb).
  final bool? toggled;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      excludeSemantics: true,
      identifier: identifier,
      label: label,
      button: true,
      enabled: onTap != null,
      selected: selected,
      toggled: toggled,
      onTap: onTap,
      child: child,
    );
  }
}
