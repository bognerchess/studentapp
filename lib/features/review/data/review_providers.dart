// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/config/env.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/review_repository.dart';
import 'fixture_review_repository.dart';

/// Where the review screen loads a game's analysis from.
///
/// WP-28 overrides this with the API- and cache-backed implementation. Until
/// then only the fake configuration (`config/fake.json`) has one: the bundled
/// demo document, so that the fake build shows a real review screen. The
/// check on `kReleaseMode` lets the compiler drop the demo document from a
/// release build (which refuses fake auth anyway).
final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  if (!kReleaseMode && ref.watch(envProvider).usesFakeAuth) {
    return FixtureReviewRepository(
      languageCode: PlatformDispatcher.instance.locale.languageCode,
    );
  }
  return const _UnwiredReviewRepository();
});

/// Where thumbs up and down go. WP-28 overrides this with the feedback
/// outbox; the fake configuration keeps ratings in memory.
final feedbackSinkProvider = Provider<FeedbackSink>((ref) {
  if (!kReleaseMode && ref.watch(envProvider).usesFakeAuth) {
    return InMemoryFeedbackSink();
  }
  return const _UnwiredFeedbackSink();
});

class _UnwiredReviewRepository implements ReviewRepository {
  const _UnwiredReviewRepository();

  @override
  Future<ReviewData> load(String gameId) async =>
      throw UnimplementedError('wired in WP-28');
}

class _UnwiredFeedbackSink implements FeedbackSink {
  const _UnwiredFeedbackSink();

  @override
  Future<void> rate(String commentId, CommentRating? rating) async =>
      throw UnimplementedError('wired in WP-28');
}
