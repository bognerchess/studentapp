// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/analytics/analytics.dart';
import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/app_foreground.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:bogner_chess/features/library/domain/games_repository.dart';
import 'package:bogner_chess/features/library/domain/owner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/review_repository.dart';
import 'api_review_repository.dart';
import 'outbox_feedback_sink.dart';

/// Where the review screen loads a game's analysis from: the analysis cache
/// first, then the API. In every configuration; the fake build talks to the
/// mock server (`tool/mock_server`). The bundled demo document
/// (`FixtureReviewRepository`) is only used by the dev entry point, which
/// overrides this provider.
final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final repository = ApiReviewRepository(
    analysisApi: ref.watch(analysisApiProvider),
    games: ref.watch(gamesRepositoryProvider),
    db: ref.watch(appDatabaseProvider),
    owner: () => ref.read(currentOwnerProvider),
  );
  return _TrackedReviewRepository(repository, ref);
});

/// The feedback outbox with its flusher.
final outboxFeedbackSinkProvider = Provider<OutboxFeedbackSink>((ref) {
  final sink = OutboxFeedbackSink(
    analysisApi: ref.watch(analysisApiProvider),
    db: ref.watch(appDatabaseProvider),
    owner: () => ref.read(currentOwnerProvider),
  );
  // Ratings given offline go out when the app comes back, and when the
  // account they belong to signs in again.
  final lifecycle = AppForeground(onResume: sink.flush);
  ref
    ..onDispose(lifecycle.dispose)
    ..listen(currentOwnerProvider, (_, owner) {
      if (owner != null) {
        unawaited(sink.flush());
      }
    });
  return sink;
});

/// Where thumbs up and down go.
final feedbackSinkProvider = Provider<FeedbackSink>(
  (ref) => _TrackedFeedbackSink(ref.watch(outboxFeedbackSinkProvider), ref),
);

class _TrackedReviewRepository implements ReviewRepository {
  const _TrackedReviewRepository(this._inner, this._ref);

  final ReviewRepository _inner;
  final Ref _ref;

  @override
  Future<ReviewData> load(String gameId) async {
    final data = await _inner.load(gameId);
    _ref.read(analyticsProvider).track(AnalyticsEvents.reviewOpened);
    // A review is open: a good moment to send ratings that are waiting.
    unawaited(_ref.read(outboxFeedbackSinkProvider).flush());
    return data;
  }
}

class _TrackedFeedbackSink implements FeedbackSink {
  const _TrackedFeedbackSink(this._inner, this._ref);

  final FeedbackSink _inner;
  final Ref _ref;

  @override
  Future<void> rate(String commentId, CommentRating? rating) async {
    await _inner.rate(commentId, rating);
    _ref.read(analyticsProvider).track(AnalyticsEvents.commentFeedback, {
      'rating': rating?.name ?? 'cleared',
    });
  }
}
