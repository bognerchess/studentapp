// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:io';

import 'package:bogner_chess/core/api/analysis_api.dart' as api;
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/features/review/data/local_feedback_store.dart';
import 'package:bogner_chess/features/review/data/outbox_feedback_sink.dart';
import 'package:bogner_chess/features/review/domain/review_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/api/api_test_support.dart';
import '../../core/storage/test_database.dart';
import '../../helpers/fixture_link.dart';

void main() {
  late AppDatabase db;
  late FixtureLink link;
  late OutboxFeedbackSink sink;
  String? owner;

  setUp(() {
    db = openTestDatabase(FakeClock());
    link = FixtureLink();
    owner = alice;
    sink = OutboxFeedbackSink(
      analysisApi: api.AnalysisApi(linkExecutor(link)),
      db: db,
      owner: () => owner,
    );
  });
  tearDown(() => db.close());

  Future<List<OutboxFeedback>> pending() =>
      db.feedbackOutboxDao.takeBatch(alice, 100);
  List<Object?> sent() => [
    for (final r in link.requestsOf('SubmitCoachCommentFeedback'))
      (r.variables['input'] as Map)['rating'],
  ];

  test('online: sent at once, outbox empty, remembered locally', () async {
    await sink.rate('c1', CommentRating.up);
    await sink.flush();
    expect(sent(), ['UP']);
    expect(await pending(), isEmpty);
    expect(await LocalFeedbackStore(db).read(alice, ['c1']), {
      'c1': CommentRating.up,
    });
  });

  test(
    'offline: rate does not throw, the rating waits, flush sends it',
    () async {
      link.fail('SubmitCoachCommentFeedback', const SocketException('offline'));
      await sink.rate('c1', CommentRating.down);
      await sink.flush();
      final waiting = await pending();
      expect(waiting.single.commentId, 'c1');
      expect(waiting.single.rating, FeedbackRating.down);
      expect(waiting.single.attempts, greaterThan(0));
      // The screen shows the thumb meanwhile.
      expect(await LocalFeedbackStore(db).read(alice, ['c1']), {
        'c1': CommentRating.down,
      });

      link.use('SubmitCoachCommentFeedback', 'down');
      await sink.flush();
      expect(await pending(), isEmpty);
      expect(sent().last, 'DOWN');
    },
  );

  test('latest wins: only the last rating of a comment goes out', () async {
    link.fail('SubmitCoachCommentFeedback', const SocketException('offline'));
    await sink.rate('c1', CommentRating.up);
    await sink.rate('c1', CommentRating.down);
    await sink.rate('c1', null);
    await sink.flush();
    expect((await pending()).single.rating, FeedbackRating.cleared);

    final before = sent().length;
    link.use('SubmitCoachCommentFeedback', 'cleared');
    await sink.flush();
    expect(sent().skip(before), [null], reason: 'a cleared rating has none');
    expect(await pending(), isEmpty);
    expect(await LocalFeedbackStore(db).read(alice, ['c1']), isEmpty);
  });

  test('offline stops the run: later rows are not even tried', () async {
    link.fail('SubmitCoachCommentFeedback', const SocketException('offline'));
    await sink.rate('c1', CommentRating.up);
    await sink.rate('c2', CommentRating.up);
    await sink.flush();
    final before = sent().length;
    await sink.flush();
    expect(sent().length, before + 1);
    expect(await pending(), hasLength(2));
  });

  test(
    'a rating the server refuses is dropped, the next one still goes',
    () async {
      link.use('SubmitCoachCommentFeedback', 'business_error');
      await sink.rate('gone', CommentRating.up);
      await sink.flush();
      expect(await pending(), isEmpty);

      link.use('SubmitCoachCommentFeedback', 'default');
      await sink.rate('c2', CommentRating.up);
      await sink.flush();
      expect(await pending(), isEmpty);
    },
  );

  test('a rating that failed too often is given up', () async {
    link.fail('SubmitCoachCommentFeedback', const SocketException('offline'));
    await sink.rate('c1', CommentRating.up);
    for (var i = 0; i < OutboxFeedbackSink.maxAttempts + 1; i++) {
      await sink.flush();
    }
    expect(await pending(), isEmpty);
  });

  test(
    'a thumb changed while its request is in flight goes out next',
    () async {
      final gate = Completer<void>();
      link.respond('SubmitCoachCommentFeedback', (variables) async {
        if (!gate.isCompleted) {
          await gate.future;
        }
        return link.store.response('SubmitCoachCommentFeedback', 'default');
      });
      await sink.rate('c1', CommentRating.up);
      // The first request hangs; the user changes their mind.
      await Future<void>.delayed(Duration.zero);
      await sink.rate('c1', CommentRating.down);
      gate.complete();
      await sink.flush();
      expect(sent(), ['UP', 'DOWN']);
      expect(await pending(), isEmpty);
    },
  );

  test('signed out: rate throws, flush does nothing', () async {
    owner = null;
    await expectLater(
      sink.rate('c1', CommentRating.up),
      throwsA(isA<api.ApiUnauthenticated>()),
    );
    await sink.flush();
    expect(sent(), isEmpty);
  });
}
