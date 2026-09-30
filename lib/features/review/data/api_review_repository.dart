// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/api/analysis_api.dart' as api;
import 'package:bogner_chess/core/api/stage_api.dart'
    show AnalysisStage, AnalysisWorkflow, StageApi;
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/features/library/domain/games_repository.dart';

import '../domain/review_repository.dart';
import 'local_feedback_store.dart';

/// Thrown by [ApiReviewRepository.load] when neither the device nor the
/// server has an analysis for the game. The review screen shows its error
/// state.
class AnalysisNotAvailable implements Exception {
  const AnalysisNotAvailable();

  @override
  String toString() => 'AnalysisNotAvailable';
}

/// The review screen's data: the cached document first, then the server.
///
/// Three things can be shown, in this order of preference:
///
/// 1. the coach's document, which the workflow tracker stores as soon as the
///    coaching stage is ready;
/// 2. the engine assembly the tracker builds out of the stage artifacts —
///    eval graph, key positions, variations and accuracy, no text;
/// 3. whatever `gameAnalysis` serves, which is how a review opens for a game
///    analysed on the web or on another device.
///
/// So a review normally opens without a request and also offline. The server
/// is asked when nothing is cached, when the cached document cannot be read,
/// and when the pipeline says the coach has written something this device
/// does not have yet. **Artifacts are never fetched here**: they are hundreds
/// of kilobytes and the tracker owns them; a stage that lands while the
/// screen is open arrives as a new `readyRunIds` and the screen reloads.
class ApiReviewRepository implements ReviewRepository {
  ApiReviewRepository({
    required api.AnalysisApi analysisApi,
    required StageApi stageApi,
    required this._games,
    required AppDatabase db,
    required String? Function() owner,
    AnalysisWorkflow? Function(String gameId)? trackedWorkflow,
  }) : _api = analysisApi,
       _stages = stageApi,
       _db = db,
       _ownerOf = owner,
       _trackedWorkflow = trackedWorkflow ?? _noWorkflow,
       _feedback = LocalFeedbackStore(db);

  static const _log = Log('review-data');

  static AnalysisWorkflow? _noWorkflow(String gameId) => null;

  final api.AnalysisApi _api;
  final StageApi _stages;
  final GamesRepository _games;
  final AppDatabase _db;
  final String? Function() _ownerOf;
  final AnalysisWorkflow? Function(String gameId) _trackedWorkflow;
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
    var source = cached?.source ?? AnalysisSource.coach;

    final workflow = await _workflowOf(gameId, cached: cached);
    final coachRunId = workflow?.readyRunIds[AnalysisStage.coaching];
    // A document that cannot be read is worth asking about again, and it is
    // still what the screen shows should the request fail.
    final stale =
        result == null ||
        result is AnalysisInvalid ||
        _coachHasWrittenSince(workflow, cached);

    if (stale) {
      try {
        final fetched = await _api.analysis(gameId);
        if (fetched != null) {
          await _db.analysisCacheDao.putCoach(
            owner,
            gameId,
            schemaVersion: fetched.schemaVersion,
            schemaMinor: fetched.schemaMinor,
            payload: fetched.rawJson,
            stageRunIds: coachRunId == null
                ? null
                : jsonEncode({AnalysisStage.coaching.wire!: coachRunId}),
          );
          result = fetched.parsed;
          source = AnalysisSource.coach;
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
      // Nothing readable here, nothing on the server: either no stage has
      // finished yet or the document is broken on both sides.
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
      source: source,
      header: GameHeaderInfo(
        white: game?.whiteName,
        black: game?.blackName,
        result: game?.result.pgn,
        date: game?.playedDate?.toLocalDateTime(),
      ),
      myFeedback: await _feedback.read(owner, _commentIds(result)),
    );
  }

  /// The pipeline of [gameId]: the tracker's copy while it is watching the
  /// game, else one query on this cold open.
  ///
  /// With nothing cached the answer cannot change what happens next — the
  /// document is fetched either way — so the query is skipped. A query that
  /// fails is "nothing known": the screen must open offline.
  Future<AnalysisWorkflow?> _workflowOf(
    String gameId, {
    required CachedAnalysis? cached,
  }) async {
    final tracked = _trackedWorkflow(gameId);
    if (tracked != null || cached == null) {
      return tracked;
    }
    try {
      return await _stages.workflow(gameId);
    } on api.ApiError catch (e) {
      _log.debug('the workflow of $gameId is unknown: $e');
      return null;
    }
  }

  /// Whether the server has a coach document this device has not stored.
  ///
  /// True when the coaching stage is ready and the cached row is an engine
  /// assembly, and when it is a coach document fetched for an *older*
  /// coaching run. A coach row whose run is not recorded — the whole-game
  /// path wrote those, and so does a server that reports no run id — is left
  /// alone: it is already the best kind of document, and the tracker replaces
  /// it the next time it sees the stage change.
  static bool _coachHasWrittenSince(
    AnalysisWorkflow? workflow,
    CachedAnalysis? cached,
  ) {
    if (workflow == null || cached == null || !workflow.coachReady) {
      return false;
    }
    if (cached.source != AnalysisSource.coach) {
      return true;
    }
    final runId = workflow.readyRunIds[AnalysisStage.coaching];
    final stored = _storedRunId(cached.stageRunIds);
    return runId != null && stored != null && stored != runId;
  }

  /// The coaching run a cached coach document was fetched for; null when the
  /// row does not say.
  static String? _storedRunId(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final id = decoded[AnalysisStage.coaching.wire];
        return id is String && id.isNotEmpty ? id : null;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  static List<String> _commentIds(AnalysisParseResult result) =>
      switch (result) {
        AnalysisSupported(:final document) => [
          for (final comment in document.comments) comment.id,
        ],
        _ => const [],
      };
}
