// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/api/analysis_api.dart' as api;
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/features/library/domain/games_repository.dart';

import '../domain/review_repository.dart';
import 'local_feedback_store.dart';

/// Thrown by [ApiReviewRepository.load] when the server has no finished
/// analysis for the game. The review screen shows its error state.
class AnalysisNotAvailable implements Exception {
  const AnalysisNotAvailable();

  @override
  String toString() => 'AnalysisNotAvailable';
}

/// The review screen's data from the cache first, then the server.
///
/// The job tracker stores a finished analysis in `cached_analyses` as soon
/// as its job is done, so a review normally opens without a request, also
/// offline. The server is asked when nothing is cached, when the cached
/// document cannot be read, or when the game's newest job finished after
/// the cached copy was fetched (the game was analysed again). When that
/// request fails and there is a cached copy, the copy is shown.
class ApiReviewRepository implements ReviewRepository {
  ApiReviewRepository({
    required api.AnalysisApi analysisApi,
    required this._games,
    required AppDatabase db,
    required String? Function() owner,
  }) : _api = analysisApi,
       _db = db,
       _ownerOf = owner,
       _feedback = LocalFeedbackStore(db);

  static const _log = Log('review-data');

  final api.AnalysisApi _api;
  final GamesRepository _games;
  final AppDatabase _db;
  final String? Function() _ownerOf;
  final LocalFeedbackStore _feedback;

  @override
  Future<ReviewData> load(String gameId) async {
    final owner = _ownerOf();
    if (owner == null) {
      throw const api.ApiUnauthenticated();
    }
    final cached = await _db.analysisCacheDao.get(owner, gameId);
    var game = await _games.cached(owner, gameId);

    var result = cached == null
        ? null
        : AnalysisParser.parseString(cached.payload);
    final stale =
        cached == null ||
        result is AnalysisInvalid ||
        _finishedAfter(game?.latestJob, cached.fetchedAt);

    if (stale) {
      try {
        final fetched = await _api.analysis(gameId);
        if (fetched != null) {
          await _db.analysisCacheDao.put(
            owner,
            gameId,
            schemaVersion: fetched.schemaVersion,
            schemaMinor: fetched.schemaMinor,
            payload: fetched.rawJson,
          );
          result = fetched.parsed;
          await _feedback.mergeServer(owner, {
            for (final id in _commentIds(fetched.parsed))
              id: switch (fetched.feedback[id]) {
                api.CommentRating.up => CommentRating.up,
                api.CommentRating.down => CommentRating.down,
                null => null,
              },
          });
        }
      } on api.ApiError catch (e) {
        if (result == null) {
          rethrow;
        }
        _log.debug('refresh failed, showing the cached analysis: $e');
      }
    }
    if (result == null) {
      throw const AnalysisNotAvailable();
    }

    if (game == null) {
      // Opened from a notification before the library ever listed the game.
      try {
        game = await _games.fetchDetail(owner, gameId);
      } on api.ApiError {
        // The header falls back to "White – Black".
      }
    }

    return ReviewData(
      result: result,
      header: GameHeaderInfo(
        white: game?.whiteName,
        black: game?.blackName,
        result: game?.result.pgn,
        date: game?.playedDate?.toLocalDateTime(),
      ),
      myFeedback: await _feedback.read(owner, _commentIds(result)),
    );
  }

  static bool _finishedAfter(JobInfo? job, DateTime fetchedAt) {
    // The database keeps whole seconds, and the tracker fetches a document
    // right when its job ends: allow for the rounding.
    final finishedAt = job?.finishedAt;
    return job?.status == JobStatus.done &&
        finishedAt != null &&
        finishedAt.difference(fetchedAt) > const Duration(seconds: 2);
  }

  static List<String> _commentIds(AnalysisParseResult result) =>
      switch (result) {
        AnalysisSupported(:final document) => [
          for (final comment in document.comments) comment.id,
        ],
        _ => const [],
      };
}
