// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:flutter/foundation.dart';

/// The user's verdict on one coach comment (AN-7).
enum CommentRating { up, down }

/// What the header of the review screen shows about the game. Display only;
/// the analysis document itself carries no names.
@immutable
class GameHeaderInfo {
  const GameHeaderInfo({this.white, this.black, this.result, this.date});

  /// Player names. Null or empty: the screen says "White" / "Black".
  final String? white;
  final String? black;

  /// The PGN result token (`1-0`, `0-1`, `1/2-1/2`, `*`). Null: the screen
  /// falls back to the result inside the analysis document.
  final String? result;

  /// When the game was played.
  final DateTime? date;
}

/// Everything the review screen needs for one game.
@immutable
class ReviewData {
  const ReviewData({
    required this.result,
    this.header = const GameHeaderInfo(),
    this.myFeedback = const {},
  });

  /// The parsed analysis document. `AnalysisParser.parseString` never throws,
  /// so a repository hands over whatever it got: supported, newer major or
  /// invalid. The screen has a state for each.
  final AnalysisParseResult result;

  final GameHeaderInfo header;

  /// The ratings this user already gave, by comment id. A missing key and a
  /// null value both mean "not rated".
  final Map<String, CommentRating?> myFeedback;
}

/// Where the review screen gets a game's analysis from. "Analysis not ready
/// yet" is not this interface's business: the screen is only opened for a
/// game that has one. A failure to load is thrown.
abstract class ReviewRepository {
  Future<ReviewData> load(String gameId);
}

/// Where a thumbs up or down goes. `null` withdraws the rating. A thrown
/// error makes the screen roll its optimistic state back.
abstract class FeedbackSink {
  Future<void> rate(String commentId, CommentRating? rating);
}
