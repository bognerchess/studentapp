// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/foundation.dart';

import 'review_repository.dart';

/// The three panels below the board.
enum ReviewTab { coach, moves, summary }

/// Where the line viewer stands: inside variation [variationId] of the node
/// at [ply], after [index] of its moves (0 is the variation's start
/// position).
@immutable
class LineCursor {
  const LineCursor({
    required this.ply,
    required this.variationId,
    required this.index,
  });

  final int ply;
  final String variationId;
  final int index;

  LineCursor withIndex(int index) =>
      LineCursor(ply: ply, variationId: variationId, index: index);

  @override
  bool operator ==(Object other) =>
      other is LineCursor &&
      other.ply == ply &&
      other.variationId == variationId &&
      other.index == index;

  @override
  int get hashCode => Object.hash(ply, variationId, index);

  @override
  String toString() => 'LineCursor($ply, $variationId, $index)';
}

/// What the review screen shows right now. The document itself is not in
/// here; `ReviewController.data` has it.
@immutable
class ReviewState {
  const ReviewState({
    this.ply = 0,
    this.animate = true,
    this.selectedCommentId,
    this.line,
    this.showBestArrow = true,
    this.showPlayedArrow = false,
    this.flipped = false,
    this.tab = ReviewTab.coach,
    this.feedback = const {},
    this.feedbackFailures = 0,
  });

  /// The main-line ply on the board: 0 is the start position, `n` the
  /// position after ply `n`. While the line viewer is open this is the ply
  /// the line belongs to.
  final int ply;

  /// Whether the step that led here should slide the pieces: true for a step
  /// to a neighbouring position, false for a jump.
  final bool animate;

  /// The comment whose arrows are on the board. Set automatically to the
  /// first comment of a ply that has one.
  final String? selectedCommentId;

  /// Non-null while the line viewer is open.
  final LineCursor? line;

  /// The green arrow of the engine's best move.
  final bool showBestArrow;

  /// An amber arrow on the move that was played (the last-move highlight
  /// already shows it, so this is off by default).
  final bool showPlayedArrow;

  /// Board turned away from the default orientation (the analysed player's
  /// side at the bottom).
  final bool flipped;

  final ReviewTab tab;

  /// The user's ratings by comment id, optimistic: a rating is in here as
  /// soon as the thumb is tapped and leaves again if the sink fails.
  final Map<String, CommentRating> feedback;

  /// Counts failed ratings, so that the screen can show a message once per
  /// failure.
  final int feedbackFailures;

  bool get inLine => line != null;

  ReviewState copyWith({
    int? ply,
    bool? animate,
    String? Function()? selectedCommentId,
    LineCursor? Function()? line,
    bool? showBestArrow,
    bool? showPlayedArrow,
    bool? flipped,
    ReviewTab? tab,
    Map<String, CommentRating>? feedback,
    int? feedbackFailures,
  }) {
    return ReviewState(
      ply: ply ?? this.ply,
      animate: animate ?? this.animate,
      selectedCommentId: selectedCommentId != null
          ? selectedCommentId()
          : this.selectedCommentId,
      line: line != null ? line() : this.line,
      showBestArrow: showBestArrow ?? this.showBestArrow,
      showPlayedArrow: showPlayedArrow ?? this.showPlayedArrow,
      flipped: flipped ?? this.flipped,
      tab: tab ?? this.tab,
      feedback: feedback ?? this.feedback,
      feedbackFailures: feedbackFailures ?? this.feedbackFailures,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReviewState &&
      other.ply == ply &&
      other.animate == animate &&
      other.selectedCommentId == selectedCommentId &&
      other.line == line &&
      other.showBestArrow == showBestArrow &&
      other.showPlayedArrow == showPlayedArrow &&
      other.flipped == flipped &&
      other.tab == tab &&
      other.feedbackFailures == feedbackFailures &&
      mapEquals(other.feedback, feedback);

  @override
  int get hashCode => Object.hash(
    ply,
    animate,
    selectedCommentId,
    line,
    showBestArrow,
    showPlayedArrow,
    flipped,
    tab,
    feedbackFailures,
    Object.hashAllUnordered(
      feedback.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}
