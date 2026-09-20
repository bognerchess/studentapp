// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analysis/analysis_parser.dart';

import '../dev/demo_analysis.dart';
import '../domain/review_repository.dart';

/// Serves the bundled demo document for every game id: the fake build and
/// the demo entry point show a real review screen without a server.
class FixtureReviewRepository implements ReviewRepository {
  FixtureReviewRepository({
    this.languageCode = 'en',
    this.header = const GameHeaderInfo(
      white: 'Magnus Example',
      black: 'You',
      result: '1-0',
    ),
    this.payload,
  });

  /// `de` gives the demo document German coach texts; anything else English.
  final String languageCode;

  final GameHeaderInfo header;

  /// Another payload instead of the demo document (the demo entry point uses
  /// it to show the newer-major and the invalid state).
  final String? payload;

  @override
  Future<ReviewData> load(String gameId) async {
    final result = payload != null
        ? AnalysisParser.parseString(payload!)
        : AnalysisParser.parse(demoAnalysisJson(languageCode: languageCode));
    return ReviewData(
      result: result,
      header: GameHeaderInfo(
        white: header.white,
        black: header.black,
        result: header.result,
        date: header.date ?? DateTime(2026, 9, 12),
      ),
    );
  }
}

/// Keeps ratings in memory and forgets them with the process.
class InMemoryFeedbackSink implements FeedbackSink {
  final Map<String, CommentRating> ratings = {};

  @override
  Future<void> rate(String commentId, CommentRating? rating) async {
    if (rating == null) {
      ratings.remove(commentId);
    } else {
      ratings[commentId] = rating;
    }
  }
}
