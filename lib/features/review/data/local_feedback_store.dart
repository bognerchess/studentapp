// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/storage/app_database.dart';

import '../domain/review_repository.dart';

/// The user's thumbs as this device knows them, in the owner-scoped `kv`
/// table (so signing out wipes them): what the review shows when it opens
/// from the cache, offline included.
///
/// The sink writes every tap here; a fetch from the server overwrites
/// everything except comments whose rating still waits in the outbox, which
/// the server cannot know yet.
class LocalFeedbackStore {
  const LocalFeedbackStore(this._db);

  final AppDatabase _db;

  static String _key(String commentId) => 'review.feedback/$commentId';

  Future<void> write(
    String owner,
    String commentId,
    CommentRating? rating,
  ) async {
    if (rating == null) {
      await _db.kvDao.remove(_key(commentId), ownerSub: owner);
    } else {
      await _db.kvDao.set(_key(commentId), rating.name, ownerSub: owner);
    }
  }

  Future<Map<String, CommentRating?>> read(
    String owner,
    Iterable<String> commentIds,
  ) async {
    final result = <String, CommentRating?>{};
    for (final id in commentIds) {
      final value = await _db.kvDao.get(_key(id), ownerSub: owner);
      final rating = CommentRating.values.asNameMap()[value];
      if (rating != null) {
        result[id] = rating;
      }
    }
    return result;
  }

  /// Takes over the server's view of [ratings] (a null value: not rated).
  Future<void> mergeServer(
    String owner,
    Map<String, CommentRating?> ratings,
  ) async {
    if (ratings.isEmpty) {
      return;
    }
    final pending = {
      for (final row in await _db.feedbackOutboxDao.takeBatch(owner, 1000))
        row.commentId,
    };
    for (final MapEntry(key: id, value: rating) in ratings.entries) {
      if (!pending.contains(id)) {
        await write(owner, id, rating);
      }
    }
  }
}
