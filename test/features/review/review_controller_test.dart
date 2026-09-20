// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/features/review/data/review_providers.dart';
import 'package:bogner_chess/features/review/domain/review_controller.dart';
import 'package:bogner_chess/features/review/domain/review_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_review.dart';

/// The moments of `forty-move-game.json`.
const _moments = [6, 10, 18, 22, 30, 34, 36, 38];

class _Subject {
  _Subject(this.container, this.sink);

  final ProviderContainer container;
  final RecordingFeedbackSink sink;

  ReviewController get controller =>
      container.read(reviewControllerProvider(kReviewGameId).notifier);
  ReviewState get state =>
      container.read(reviewControllerProvider(kReviewGameId));
}

Future<_Subject> _make({
  String fixture = kFortyMoveGame,
  Map<String, CommentRating?> myFeedback = const {},
}) async {
  final sink = RecordingFeedbackSink();
  final container = ProviderContainer(
    overrides: [
      reviewRepositoryProvider.overrideWithValue(
        FakeReviewRepository(
          ReviewData(result: parseFixture(fixture), myFeedback: myFeedback),
        ),
      ),
      feedbackSinkProvider.overrideWithValue(sink),
    ],
  );
  addTearDown(container.dispose);
  container.listen(reviewDataProvider(kReviewGameId), (_, _) {});
  await container.read(reviewDataProvider(kReviewGameId).future);
  container.listen(reviewControllerProvider(kReviewGameId), (_, _) {});
  return _Subject(container, sink);
}

void main() {
  setUp(() => Log.sink = (_) {});
  tearDown(Log.resetSink);

  group('navigation', () {
    test('starts on the start position, on the coach tab', () async {
      final s = await _make();
      expect(s.state.ply, 0);
      expect(s.state.tab, ReviewTab.coach);
      expect(s.state.line, isNull);
      expect(s.state.showBestArrow, isTrue);
      expect(s.state.showPlayedArrow, isFalse);
      expect(s.controller.plyCount, 80);
      expect(s.controller.canGoBack, isFalse);
      expect(s.controller.canGoForward, isTrue);
    });

    test('stays inside the game', () async {
      final s = await _make();
      s.controller.previous();
      expect(s.state.ply, 0);
      s.controller.goTo(-5);
      expect(s.state.ply, 0);
      s.controller.last();
      expect(s.state.ply, 80);
      expect(s.controller.canGoForward, isFalse);
      s.controller.next();
      expect(s.state.ply, 80);
      s.controller.goTo(999);
      expect(s.state.ply, 80);
      s.controller.first();
      expect(s.state.ply, 0);
    });

    test('a single step animates, a jump does not', () async {
      final s = await _make();
      s.controller.next();
      expect(s.state.animate, isTrue);
      s.controller.goTo(30);
      expect(s.state.animate, isFalse);
      s.controller.previous();
      expect(s.state.animate, isTrue);
    });

    test('selects the first comment of a ply that has one', () async {
      final s = await _make();
      s.controller.goTo(6);
      final id = s.controller.document!.nodeAt(6)!.commentIds.single;
      expect(s.state.selectedCommentId, id);
      s.controller.next();
      expect(s.state.selectedCommentId, isNull);
      // A comment of another ply cannot be selected.
      s.controller.selectComment(id);
      expect(s.state.selectedCommentId, isNull);
    });
  });

  group('key moments', () {
    test('forward through all of them, then nothing', () async {
      final s = await _make();
      final seen = <int>[];
      while (s.controller.nextMoment()) {
        seen.add(s.state.ply);
      }
      expect(seen, _moments);
      expect(s.controller.nextMomentPly, isNull);
      expect(s.state.ply, 38);
    });

    test('backward from the end, then nothing', () async {
      final s = await _make();
      s.controller.last();
      final seen = <int>[];
      while (s.controller.previousMoment()) {
        seen.add(s.state.ply);
      }
      expect(seen, _moments.reversed);
      expect(s.controller.previousMoment(), isFalse);
      expect(s.state.ply, 6);
    });

    test('from between two moments', () async {
      final s = await _make();
      s.controller.goTo(20);
      expect(s.controller.nextMomentPly, 22);
      expect(s.controller.previousMomentPly, 18);
    });

    test('a jump brings the coach tab forward', () async {
      final s = await _make();
      s.controller.setTab(ReviewTab.moves);
      s.controller.nextMoment();
      expect(s.state.tab, ReviewTab.coach);

      s.controller.setTab(ReviewTab.summary);
      s.controller.showEvidence(36);
      expect(s.state.ply, 36);
      expect(s.state.tab, ReviewTab.coach);
    });
  });

  group('line viewer', () {
    test('enter, step, clamp, exit', () async {
      final s = await _make();
      s.controller.goTo(6);
      s.controller.enterLine('v6-best');
      expect(
        s.state.line,
        const LineCursor(ply: 6, variationId: 'v6-best', index: 1),
      );
      expect(s.controller.currentVariation!.sans.first, 'd5');
      expect(s.controller.canLineBack, isTrue);

      s.controller.lineNext();
      expect(s.state.line!.index, 2);
      expect(s.state.animate, isTrue);
      s.controller.lineGoTo(99);
      expect(s.state.line!.index, 6);
      expect(s.controller.canLineForward, isFalse);
      s.controller.lineNext();
      expect(s.state.line!.index, 6);
      s.controller.lineGoTo(0);
      expect(s.state.line!.index, 0);
      expect(s.state.animate, isFalse);
      expect(s.controller.canLineBack, isFalse);
      s.controller.linePrevious();
      expect(s.state.line!.index, 0);

      s.controller.exitLine();
      expect(s.state.line, isNull);
      expect(s.state.ply, 6);
    });

    test('an unknown variation id does nothing', () async {
      final s = await _make();
      s.controller.goTo(6);
      s.controller.enterLine('v10-best'); // belongs to another ply
      expect(s.state.line, isNull);
      s.controller.enterLine('nope');
      expect(s.state.line, isNull);
    });

    test('main-line navigation and the other tabs leave the line', () async {
      final s = await _make();
      s.controller.goTo(6);
      s.controller.enterLine('v6-refutation');
      s.controller.goTo(7);
      expect(s.state.line, isNull);
      expect(s.state.ply, 7);
      // Leaving a line is a jump, not a slide.
      expect(s.state.animate, isFalse);

      s.controller.goTo(6);
      s.controller.enterLine('v6-refutation');
      s.controller.setTab(ReviewTab.coach);
      expect(s.state.line, isNotNull);
      s.controller.setTab(ReviewTab.moves);
      expect(s.state.line, isNull);
    });

    test('entering a line brings the coach tab forward', () async {
      final s = await _make();
      s.controller.goTo(6);
      s.controller.setTab(ReviewTab.moves);
      s.controller.enterLine('v6-best');
      expect(s.state.tab, ReviewTab.coach);
    });
  });

  group('toggles', () {
    test('arrows and orientation', () async {
      final s = await _make();
      s.controller.toggleBestArrow();
      expect(s.state.showBestArrow, isFalse);
      s.controller.togglePlayedArrow();
      expect(s.state.showPlayedArrow, isTrue);
      s.controller.flipBoard();
      expect(s.state.flipped, isTrue);
    });
  });

  group('feedback', () {
    test('starts from the ratings the repository knows', () async {
      final s = await _make(myFeedback: {'a': CommentRating.up, 'b': null});
      expect(s.state.feedback, {'a': CommentRating.up});
    });

    test('is optimistic: the state changes before the sink answers', () async {
      final s = await _make();
      s.sink.gate = Completer<void>();
      final done = s.controller.rate('c1', CommentRating.up);
      expect(s.state.feedback, {'c1': CommentRating.up});
      expect(s.sink.calls, [('c1', CommentRating.up)]);
      s.sink.gate!.complete();
      await done;
      expect(s.state.feedback, {'c1': CommentRating.up});
      expect(s.state.feedbackFailures, 0);
    });

    test('the same thumb again withdraws, the other thumb switches', () async {
      final s = await _make();
      await s.controller.rate('c1', CommentRating.up);
      await s.controller.rate('c1', CommentRating.down);
      expect(s.state.feedback, {'c1': CommentRating.down});
      await s.controller.rate('c1', CommentRating.down);
      expect(s.state.feedback, isEmpty);
      expect(s.sink.calls, [
        ('c1', CommentRating.up),
        ('c1', CommentRating.down),
        ('c1', null),
      ]);
    });

    test('rolls back when the sink fails', () async {
      final s = await _make(myFeedback: {'c1': CommentRating.down});
      s.sink.failWith = StateError('offline');
      await s.controller.rate('c1', CommentRating.up);
      expect(s.state.feedback, {'c1': CommentRating.down});
      expect(s.state.feedbackFailures, 1);

      await s.controller.rate('c2', CommentRating.up);
      expect(s.state.feedback, {'c1': CommentRating.down});
      expect(s.state.feedbackFailures, 2);
    });

    test('an old failure does not undo a newer tap', () async {
      final s = await _make();
      final first = Completer<void>();
      s.sink.gate = first;
      s.sink.failWith = StateError('offline');
      final a = s.controller.rate('c1', CommentRating.up);

      // The second tap succeeds while the first is still in flight.
      s.sink
        ..gate = null
        ..failWith = null;
      await s.controller.rate('c1', CommentRating.down);
      expect(s.state.feedback, {'c1': CommentRating.down});

      s.sink.failWith = StateError('offline');
      first.complete();
      await a;
      expect(s.state.feedback, {'c1': CommentRating.down});
      expect(s.state.feedbackFailures, 1);
    });
  });

  group('newer major version', () {
    test('moves only: no moments, no coach tab, no lines', () async {
      final s = await _make(fixture: kNewerMajor);
      expect(s.controller.document, isNull);
      expect(s.controller.partial, isNotNull);
      expect(s.state.tab, ReviewTab.moves);
      expect(s.controller.plyCount, s.controller.partial!.moves.length);
      expect(s.controller.nextMoment(), isFalse);
      s.controller.setTab(ReviewTab.coach);
      expect(s.state.tab, ReviewTab.moves);
      s.controller.last();
      expect(s.state.ply, s.controller.plyCount);
      s.controller.enterLine('v6-best');
      expect(s.state.line, isNull);
    });
  });
}
