// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:drift/drift.dart';

import '../app_database.dart';

part 'feedback_outbox_dao.g.dart';

/// Thumbs on coach comments on their way to the server.
@DriftAccessor(tables: [FeedbackOutbox])
class FeedbackOutboxDao extends DatabaseAccessor<AppDatabase>
    with _$FeedbackOutboxDaoMixin {
  FeedbackOutboxDao(super.attachedDatabase);

  /// Records the rating of a comment. A rating of the same comment that is
  /// still waiting is replaced (latest wins) and its attempts start again.
  Future<void> put(String ownerSub, String commentId, FeedbackRating rating) {
    final now = attachedDatabase.now();
    return into(feedbackOutbox).insert(
      FeedbackOutboxCompanion.insert(
        ownerSub: ownerSub,
        commentId: commentId,
        rating: rating,
        createdAt: now,
      ),
      onConflict: DoUpdate(
        (_) => FeedbackOutboxCompanion(
          rating: Value(rating),
          createdAt: Value(now),
          attempts: const Value(0),
        ),
        target: [feedbackOutbox.ownerSub, feedbackOutbox.commentId],
      ),
    );
  }

  /// The rating that is waiting for [commentId], so the UI can show the
  /// user's choice before the server knows it.
  Stream<OutboxFeedback?> watchPending(String ownerSub, String commentId) {
    final query = select(feedbackOutbox)
      ..where(
        (t) => t.ownerSub.equals(ownerSub) & t.commentId.equals(commentId),
      );
    return query.watchSingleOrNull();
  }

  /// The [limit] ratings that have waited longest.
  Future<List<OutboxFeedback>> takeBatch(String ownerSub, int limit) {
    final query = select(feedbackOutbox)
      ..where((t) => t.ownerSub.equals(ownerSub))
      ..orderBy([
        (t) => OrderingTerm.asc(t.createdAt),
        (t) => OrderingTerm.asc(t.id),
      ])
      ..limit(limit);
    return query.get();
  }

  /// After a successful send. A row whose rating changed while the request
  /// was in flight stays, so the newer rating is sent next. Returns the number
  /// of rows removed.
  Future<int> removeSent(Iterable<OutboxFeedback> sent) {
    return transaction(() async {
      var removed = 0;
      for (final entry in sent) {
        final query = delete(feedbackOutbox)
          ..where(
            (t) =>
                t.id.equals(entry.id) &
                t.ownerSub.equals(entry.ownerSub) &
                t.rating.equalsValue(entry.rating),
          );
        removed += await query.go();
      }
      return removed;
    });
  }

  /// After a failed send.
  Future<void> bumpAttempts(Iterable<int> ids) {
    final query = update(feedbackOutbox)..where((t) => t.id.isIn(ids));
    return query.write(
      FeedbackOutboxCompanion.custom(
        attempts: feedbackOutbox.attempts + const Constant(1),
      ),
    );
  }

  /// Drops ratings that failed [maxAttempts] times or more.
  Future<int> removeExhausted(String ownerSub, int maxAttempts) {
    final query = delete(feedbackOutbox)
      ..where(
        (t) =>
            t.ownerSub.equals(ownerSub) &
            t.attempts.isBiggerOrEqualValue(maxAttempts),
      );
    return query.go();
  }
}
