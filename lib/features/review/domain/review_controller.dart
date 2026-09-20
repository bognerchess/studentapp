// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/analysis/analysis_view.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/review_providers.dart';
import 'review_repository.dart';
import 'review_state.dart';

export 'review_state.dart';

const _log = Log('review');

/// Loads the analysis of one game. No automatic retry: the screen has a
/// retry button, and a repository that is not wired fails every time.
final reviewDataProvider = FutureProvider.autoDispose
    .family<ReviewData, String>(
      (ref, gameId) => ref.watch(reviewRepositoryProvider).load(gameId),
      retry: (_, _) => null,
    );

/// The state of the review screen of one game. Only read it once
/// [reviewDataProvider] has a value; the screen does.
final reviewControllerProvider = NotifierProvider.autoDispose
    .family<ReviewController, ReviewState, String>(ReviewController.new);

class ReviewController extends Notifier<ReviewState> {
  ReviewController(this.gameId);

  final String gameId;

  late ReviewData _data;

  /// Newest rating request per comment, so that the rollback of an old
  /// failure does not undo a newer tap.
  final Map<String, int> _ratingSeq = {};

  ReviewData get data => _data;

  /// The document, or null when the analysis is of a newer major version (or
  /// invalid): then there is only a board and a move list.
  AnalysisDocument? get document => switch (_data.result) {
    AnalysisSupported(:final document) => document,
    _ => null,
  };

  PartialAnalysis? get partial => switch (_data.result) {
    AnalysisNewerMajor(:final partial) => partial,
    _ => null,
  };

  int get plyCount => document?.plyCount ?? partial?.moves.length ?? 0;

  @override
  ReviewState build() {
    _data = ref.watch(reviewDataProvider(gameId)).requireValue;
    _ratingSeq.clear();
    return ReviewState(
      tab: document == null ? ReviewTab.moves : ReviewTab.coach,
      feedback: {
        for (final MapEntry(:key, :value) in _data.myFeedback.entries)
          key: ?value,
      },
    );
  }

  // ---- main line ----------------------------------------------------------

  /// Shows the position after [ply] (clamped) and leaves the line viewer.
  void goTo(int ply, {ReviewTab? tab}) {
    final target = ply.clamp(0, plyCount);
    final from = state.inLine ? null : state.ply;
    state = state.copyWith(
      ply: target,
      // Pieces slide for a single step; a jump just shows the new position.
      animate: from != null && (from - target).abs() == 1,
      line: () => null,
      selectedCommentId: () => _firstCommentAt(target),
      tab: tab,
    );
  }

  void next() => goTo(state.ply + 1);
  void previous() => goTo(state.ply - 1);
  void first() => goTo(0);
  void last() => goTo(plyCount);

  bool get canGoBack => state.ply > 0;
  bool get canGoForward => state.ply < plyCount;

  int? get nextMomentPly => document?.nextCritical(state.ply);
  int? get previousMomentPly => document?.previousCritical(state.ply);

  /// Jumps to the next key moment and brings the coach forward. Returns
  /// false when there is none.
  bool nextMoment() => _toMoment(nextMomentPly);

  bool previousMoment() => _toMoment(previousMomentPly);

  bool _toMoment(int? ply) {
    if (ply == null) return false;
    goTo(ply, tab: ReviewTab.coach);
    return true;
  }

  /// A tap on an evidence chip of a lesson.
  void showEvidence(int ply) => goTo(ply, tab: ReviewTab.coach);

  void selectComment(String commentId) {
    if (document?.commentsById[commentId]?.ply != state.ply) return;
    state = state.copyWith(selectedCommentId: () => commentId);
  }

  String? _firstCommentAt(int ply) =>
      document?.nodeAt(ply)?.commentIds.firstOrNull;

  // ---- line viewer --------------------------------------------------------

  /// The variation the line viewer is in, or null.
  Variation? get currentVariation {
    final line = state.line;
    if (line == null) return null;
    return document?.nodeAt(line.ply)?.variationById(line.variationId);
  }

  /// Opens variation [variationId] of the current ply with its first move
  /// played: that move is the point of the line. Does nothing for an id the
  /// node does not have.
  void enterLine(String variationId) {
    final variation = document?.nodeAt(state.ply)?.variationById(variationId);
    if (variation == null || variation.moves.isEmpty) return;
    state = state.copyWith(
      line: () =>
          LineCursor(ply: state.ply, variationId: variationId, index: 1),
      animate: true,
      tab: ReviewTab.coach,
    );
  }

  void lineGoTo(int index) {
    final line = state.line;
    final variation = currentVariation;
    if (line == null || variation == null) return;
    final target = index.clamp(0, variation.moves.length);
    state = state.copyWith(
      line: () => line.withIndex(target),
      animate: (target - line.index).abs() == 1,
    );
  }

  void lineNext() => lineGoTo((state.line?.index ?? 0) + 1);
  void linePrevious() => lineGoTo((state.line?.index ?? 0) - 1);

  bool get canLineBack => (state.line?.index ?? 0) > 0;
  bool get canLineForward =>
      (state.line?.index ?? 0) < (currentVariation?.moves.length ?? 0);

  /// Back to the main-line position the line started from.
  void exitLine() {
    if (!state.inLine) return;
    state = state.copyWith(line: () => null, animate: false);
  }

  // ---- toggles ------------------------------------------------------------

  void setTab(ReviewTab tab) {
    if (document == null && tab != ReviewTab.moves) return;
    // The line viewer lives on the coach tab; the other tabs are about the
    // game itself.
    final leaveLine = state.inLine && tab != ReviewTab.coach;
    state = state.copyWith(
      tab: tab,
      line: leaveLine ? () => null : null,
      animate: leaveLine ? false : null,
    );
  }

  void toggleBestArrow() =>
      state = state.copyWith(showBestArrow: !state.showBestArrow);

  void togglePlayedArrow() =>
      state = state.copyWith(showPlayedArrow: !state.showPlayedArrow);

  void flipBoard() =>
      state = state.copyWith(flipped: !state.flipped, animate: false);

  // ---- feedback -----------------------------------------------------------

  /// A tap on a thumb: the same thumb again withdraws the rating. The state
  /// changes at once; if the sink fails it goes back to what it was and
  /// [ReviewState.feedbackFailures] counts up.
  Future<void> rate(String commentId, CommentRating rating) async {
    final before = state.feedback[commentId];
    final after = before == rating ? null : rating;
    final seq = (_ratingSeq[commentId] ?? 0) + 1;
    _ratingSeq[commentId] = seq;
    _setRating(commentId, after);

    try {
      await ref.read(feedbackSinkProvider).rate(commentId, after);
    } on Object catch (error, stack) {
      _log.warning('rating was not accepted', error: error, stackTrace: stack);
      if (!ref.mounted) return;
      if (_ratingSeq[commentId] == seq) _setRating(commentId, before);
      state = state.copyWith(feedbackFailures: state.feedbackFailures + 1);
    }
  }

  void _setRating(String commentId, CommentRating? rating) {
    final feedback = Map<String, CommentRating>.of(state.feedback);
    if (rating == null) {
      feedback.remove(commentId);
    } else {
      feedback[commentId] = rating;
    }
    state = state.copyWith(feedback: Map.unmodifiable(feedback));
  }
}
