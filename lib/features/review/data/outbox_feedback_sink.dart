// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/api/analysis_api.dart' as api;
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/storage/app_database.dart';

import '../domain/review_repository.dart';
import 'local_feedback_store.dart';

/// Thumbs up and down through the feedback outbox (AN-7).
///
/// [rate] writes the rating to `feedback_outbox` (one row per comment, the
/// latest wins) and to the local store, then tries to send. It does not
/// throw for a failed send, so the screen never rolls a thumb back because
/// the device is offline; [flush] sends what is waiting, and the provider
/// calls it when the app comes back to the foreground, when somebody signs
/// in, and when a review is opened.
class OutboxFeedbackSink implements FeedbackSink {
  OutboxFeedbackSink({
    required api.AnalysisApi analysisApi,
    required AppDatabase db,
    required String? Function() owner,
  }) : _api = analysisApi,
       _db = db,
       _ownerOf = owner,
       _local = LocalFeedbackStore(db);

  /// A rating that failed this often is dropped.
  static const int maxAttempts = 8;
  static const int _batchSize = 20;
  static const _log = Log('feedback');

  final api.AnalysisApi _api;
  final AppDatabase _db;
  final String? Function() _ownerOf;
  final LocalFeedbackStore _local;

  Future<void>? _flushing;
  bool _flushAgain = false;

  @override
  Future<void> rate(String commentId, CommentRating? rating) async {
    final owner = _ownerOf();
    if (owner == null) {
      throw const api.ApiUnauthenticated();
    }
    await _db.feedbackOutboxDao.put(owner, commentId, switch (rating) {
      CommentRating.up => FeedbackRating.up,
      CommentRating.down => FeedbackRating.down,
      null => FeedbackRating.cleared,
    });
    await _local.write(owner, commentId, rating);
    unawaited(flush());
  }

  /// Sends the waiting ratings, oldest first. One run at a time; a call
  /// during a run makes it go round once more. Stops at the first failure
  /// that a retry can cure (offline, server trouble) and leaves the rest for
  /// the next call. Never throws.
  Future<void> flush() {
    final running = _flushing;
    if (running != null) {
      _flushAgain = true;
      return running;
    }
    final done = () async {
      do {
        _flushAgain = false;
        await _flushOnce();
      } while (_flushAgain);
    }();
    _flushing = done;
    return done.whenComplete(() => _flushing = null);
  }

  Future<void> _flushOnce() async {
    final owner = _ownerOf();
    if (owner == null) {
      return;
    }
    try {
      final dao = _db.feedbackOutboxDao;
      await dao.removeExhausted(owner, maxAttempts);
      while (true) {
        final batch = await dao.takeBatch(owner, _batchSize);
        if (batch.isEmpty) {
          return;
        }
        for (final row in batch) {
          try {
            await _api.submitFeedback(
              commentId: row.commentId,
              rating: switch (row.rating) {
                FeedbackRating.up => api.CommentRating.up,
                FeedbackRating.down => api.CommentRating.down,
                FeedbackRating.cleared => null,
              },
            );
            await dao.removeSent([row]);
          } on api.ApiError catch (e) {
            if (e.isRetryable || e is api.ApiUnauthenticated) {
              await dao.bumpAttempts([row.id]);
              _log.debug('feedback stays in the outbox: $e');
              return;
            }
            // The server refuses this rating (the comment is gone, say):
            // sending it again cannot help.
            _log.warning('feedback dropped: $e');
            await dao.removeSent([row]);
          }
        }
      }
    } on Object catch (e, s) {
      _log.warning('flushing feedback failed', error: e, stackTrace: s);
    }
  }
}
