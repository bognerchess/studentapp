// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late DraftsDao dao;

  setUp(() {
    clock = FakeClock();
    db = openTestDatabase(clock);
    dao = db.draftsDao;
  });

  tearDown(() => db.close());

  /// A draft of [owner] that the queue has picked up.
  Future<Draft> submitting(String owner) async {
    final draft = await dao.create(owner, pgn: '1. e4 e5');
    expect(await dao.markReady(owner, draft.id), isTrue);
    expect(await dao.markSubmitting(owner, draft.id), isTrue);
    return (await dao.get(owner, draft.id))!;
  }

  group('create and autosave', () {
    test('create starts in editing with fresh ids and defaults', () async {
      final a = await dao.create(alice);
      final b = await dao.create(alice, pgn: '1. d4', wantsAnalysis: false);

      expect(a.state, DraftState.editing);
      expect(a.ownerSub, alice);
      expect(a.pgn, '');
      expect(a.metaJson, '{}');
      expect(a.wantsAnalysis, isTrue);
      expect(a.serverGameId, isNull);
      expect(a.attempts, 0);
      expect(a.lastError, isNull);
      expect(a.nextAttemptAt, isNull);
      expect(a.createdAt.isAtSameMomentAs(clock()), isTrue);
      expect(a.updatedAt.isAtSameMomentAs(clock()), isTrue);
      expect(b.wantsAnalysis, isFalse);
      expect(a.id, isNot(b.id));
      expect(a.clientGameId, isNot(b.clientGameId));
      expect(a.clientGameId, isNot(a.id));
      expect(a.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
    });

    test('autosave per ply keeps ids and bumps updated_at', () async {
      final draft = await dao.create(alice);
      clock.advance(const Duration(seconds: 5));
      expect(await dao.autosave(alice, draft.id, pgn: '1. e4'), isTrue);
      clock.advance(const Duration(seconds: 5));
      expect(
        await dao.autosave(
          alice,
          draft.id,
          pgn: '1. e4 e5',
          metaJson: '{"white":"A"}',
        ),
        isTrue,
      );

      final saved = (await dao.get(alice, draft.id))!;
      expect(saved.pgn, '1. e4 e5');
      expect(saved.metaJson, '{"white":"A"}');
      expect(saved.clientGameId, draft.clientGameId);
      expect(saved.createdAt.isAtSameMomentAs(draft.createdAt), isTrue);
      expect(saved.updatedAt.isAtSameMomentAs(clock()), isTrue);
    });

    test('autosave without metaJson leaves the metadata alone', () async {
      final draft = await dao.create(alice, metaJson: '{"white":"A"}');
      await dao.autosave(alice, draft.id, pgn: '1. e4');
      expect((await dao.get(alice, draft.id))!.metaJson, '{"white":"A"}');
    });

    test('autosave is refused outside editing', () async {
      final draft = await dao.create(alice, pgn: '1. e4');
      await dao.markReady(alice, draft.id);
      expect(await dao.autosave(alice, draft.id, pgn: 'changed'), isFalse);
      expect((await dao.get(alice, draft.id))!.pgn, '1. e4');
    });

    test('autosave of an unknown id changes nothing', () async {
      expect(await dao.autosave(alice, 'nope', pgn: 'x'), isFalse);
    });
  });

  group('state transitions', () {
    test('happy path: editing, ready, submitting, submitted', () async {
      final draft = await submitting(alice);
      expect(draft.state, DraftState.submitting);

      expect(await dao.setServerGameId(alice, draft.id, 'game-1'), isTrue);
      expect((await dao.get(alice, draft.id))!.serverGameId, 'game-1');
      expect((await dao.get(alice, draft.id))!.state, DraftState.submitting);

      expect(
        await dao.markSubmitted(alice, draft.id, serverGameId: 'game-1'),
        isTrue,
      );
      final done = (await dao.get(alice, draft.id))!;
      expect(done.state, DraftState.submitted);
      expect(done.serverGameId, 'game-1');
      expect(done.lastError, isNull);
      expect(done.nextAttemptAt, isNull);
    });

    test('illegal transitions return false and change nothing', () async {
      final draft = await dao.create(alice);
      expect(await dao.markSubmitting(alice, draft.id), isFalse);
      expect(
        await dao.markSubmitted(alice, draft.id, serverGameId: 'g'),
        isFalse,
      );
      expect(
        await dao.markSubmitFailed(
          alice,
          draft.id,
          error: 'e',
          nextAttemptAt: null,
        ),
        isFalse,
      );
      expect(await dao.retry(alice, draft.id), isFalse);
      expect(await dao.reopen(alice, draft.id), isFalse);
      expect(await dao.setServerGameId(alice, draft.id, 'g'), isFalse);

      final same = (await dao.get(alice, draft.id))!;
      expect(same.state, DraftState.editing);
      expect(same.serverGameId, isNull);
      expect(same.attempts, 0);

      await dao.markReady(alice, draft.id);
      expect(await dao.markReady(alice, draft.id), isFalse);
    });

    test('a retryable failure goes back to ready with a back-off', () async {
      final draft = await submitting(alice);
      final later = clock().add(const Duration(seconds: 30));
      clock.advance(const Duration(seconds: 1));

      expect(
        await dao.markSubmitFailed(
          alice,
          draft.id,
          error: 'network',
          nextAttemptAt: later,
        ),
        isTrue,
      );

      final failed = (await dao.get(alice, draft.id))!;
      expect(failed.state, DraftState.ready);
      expect(failed.attempts, 1);
      expect(failed.lastError, 'network');
      expect(failed.nextAttemptAt!.isAtSameMomentAs(later), isTrue);
      expect(failed.updatedAt.isAtSameMomentAs(clock()), isTrue);
    });

    test('attempts add up over several failures', () async {
      final draft = await submitting(alice);
      for (var i = 1; i <= 3; i++) {
        await dao.markSubmitFailed(
          alice,
          draft.id,
          error: 'network $i',
          nextAttemptAt: clock(),
        );
        expect((await dao.get(alice, draft.id))!.attempts, i);
        await dao.markSubmitting(alice, draft.id);
      }
      expect((await dao.get(alice, draft.id))!.lastError, 'network 3');
    });

    test('a terminal failure goes to failed; retry resets it', () async {
      final draft = await submitting(alice);
      await dao.markSubmitFailed(
        alice,
        draft.id,
        error: 'gave up',
        nextAttemptAt: null,
      );

      final failed = (await dao.get(alice, draft.id))!;
      expect(failed.state, DraftState.failed);
      expect(failed.attempts, 1);
      expect(failed.nextAttemptAt, isNull);
      expect(await dao.nextSubmittable(alice), isNull);

      expect(await dao.retry(alice, draft.id), isTrue);
      final again = (await dao.get(alice, draft.id))!;
      expect(again.state, DraftState.ready);
      expect(again.attempts, 0);
      expect(again.lastError, 'gave up', reason: 'kept until it succeeds');
      expect((await dao.nextSubmittable(alice))!.id, draft.id);
    });

    test('markSubmitted clears the last error', () async {
      final draft = await submitting(alice);
      await dao.markSubmitFailed(
        alice,
        draft.id,
        error: 'network',
        nextAttemptAt: clock(),
      );
      await dao.markSubmitting(alice, draft.id);
      await dao.markSubmitted(alice, draft.id, serverGameId: 'g');
      expect((await dao.get(alice, draft.id))!.lastError, isNull);
    });

    test('reopen works from ready and failed, not with a server id', () async {
      final ready = await dao.create(alice);
      await dao.markReady(alice, ready.id);
      expect(await dao.reopen(alice, ready.id), isTrue);
      expect((await dao.get(alice, ready.id))!.state, DraftState.editing);

      final created = await submitting(alice);
      await dao.setServerGameId(alice, created.id, 'game-9');
      await dao.markSubmitFailed(
        alice,
        created.id,
        error: 'analysis request failed',
        nextAttemptAt: null,
      );
      expect(await dao.reopen(alice, created.id), isFalse);
      expect((await dao.get(alice, created.id))!.state, DraftState.failed);
    });

    test('recoverInterrupted puts submitting drafts back to ready', () async {
      final stuck = await submitting(alice);
      final editing = await dao.create(alice);
      final other = await submitting(bob);

      expect(await dao.recoverInterrupted(alice), 1);
      expect((await dao.get(alice, stuck.id))!.state, DraftState.ready);
      expect((await dao.get(alice, editing.id))!.state, DraftState.editing);
      expect((await dao.get(bob, other.id))!.state, DraftState.submitting);
    });
  });

  group('nextSubmittable', () {
    Future<Draft> ready(String owner) async {
      final draft = await dao.create(owner);
      await dao.markReady(owner, draft.id);
      return draft;
    }

    test('is null without ready drafts', () async {
      await dao.create(alice);
      expect(await dao.nextSubmittable(alice), isNull);
    });

    test('takes the one that has waited longest', () async {
      final first = await ready(alice);
      clock.advance(const Duration(seconds: 1));
      final second = await ready(alice);
      clock.advance(const Duration(seconds: 1));

      expect((await dao.nextSubmittable(alice))!.id, first.id);

      // A failure moves the first one behind the second.
      await dao.markSubmitting(alice, first.id);
      await dao.markSubmitFailed(
        alice,
        first.id,
        error: 'network',
        nextAttemptAt: clock(),
      );
      expect((await dao.nextSubmittable(alice))!.id, second.id);
    });

    test('respects next_attempt_at', () async {
      final draft = await ready(alice);
      await dao.markSubmitting(alice, draft.id);
      final until = clock().add(const Duration(seconds: 10));
      await dao.markSubmitFailed(
        alice,
        draft.id,
        error: 'network',
        nextAttemptAt: until,
      );

      expect(await dao.nextSubmittable(alice), isNull);
      expect(
        (await dao.nextBackoffEnd(alice))!.isAtSameMomentAs(until),
        isTrue,
      );

      clock.advance(const Duration(seconds: 9));
      expect(await dao.nextSubmittable(alice), isNull);
      clock.advance(const Duration(seconds: 1));
      expect((await dao.nextSubmittable(alice))!.id, draft.id);
    });

    test('skips a draft in back-off for one that is due', () async {
      final waiting = await ready(alice);
      await dao.markSubmitting(alice, waiting.id);
      await dao.markSubmitFailed(
        alice,
        waiting.id,
        error: 'network',
        nextAttemptAt: clock().add(const Duration(minutes: 5)),
      );
      clock.advance(const Duration(seconds: 1));
      final due = await ready(alice);

      expect((await dao.nextSubmittable(alice))!.id, due.id);
    });

    test('clearBackoff makes waiting drafts due at once', () async {
      final draft = await ready(alice);
      await dao.markSubmitting(alice, draft.id);
      await dao.markSubmitFailed(
        alice,
        draft.id,
        error: 'network',
        nextAttemptAt: clock().add(const Duration(minutes: 5)),
      );

      expect(await dao.clearBackoff(alice), 1);
      expect((await dao.nextSubmittable(alice))!.id, draft.id);
      expect(await dao.nextBackoffEnd(alice), isNull);
      expect((await dao.get(alice, draft.id))!.attempts, 1);
    });
  });

  group('watch', () {
    test('watchAll emits on changes, newest first, with a filter', () async {
      final older = await dao.create(alice, pgn: 'older');
      clock.advance(const Duration(seconds: 1));
      final newer = await dao.create(alice, pgn: 'newer');

      expect((await dao.watchAll(alice).first).map((d) => d.id), [
        newer.id,
        older.id,
      ]);

      clock.advance(const Duration(seconds: 1));
      await dao.markReady(alice, older.id);
      expect((await dao.watchAll(alice).first).map((d) => d.id), [
        older.id,
        newer.id,
      ]);
      expect(
        (await dao.watchAll(alice, states: {DraftState.editing}).first).map(
          (d) => d.id,
        ),
        [newer.id],
      );
    });

    test('watchAll pushes a new list after an autosave', () async {
      final draft = await dao.create(alice);
      final emissions = <String>[];
      final sub = dao
          .watchAll(alice)
          .listen((list) => emissions.add(list.single.pgn));
      await pumpEventQueue();
      await dao.autosave(alice, draft.id, pgn: '1. e4');
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions, ['', '1. e4']);
    });

    test('watch follows one draft until it is removed', () async {
      final draft = await dao.create(alice);
      expect((await dao.watch(alice, draft.id).first)!.id, draft.id);
      expect(await dao.remove(alice, draft.id), isTrue);
      expect(await dao.watch(alice, draft.id).first, isNull);
      expect(await dao.remove(alice, draft.id), isFalse);
    });
  });

  group('owner scoping', () {
    test('owner A never sees or touches the drafts of owner B', () async {
      final mine = await dao.create(alice, pgn: 'mine');
      final theirs = await dao.create(bob, pgn: 'theirs');
      await dao.markReady(bob, theirs.id);

      expect((await dao.watchAll(alice).first).map((d) => d.id), [mine.id]);
      expect(await dao.get(alice, theirs.id), isNull);
      expect(await dao.watch(alice, theirs.id).first, isNull);
      expect(await dao.nextSubmittable(alice), isNull);
      expect(await dao.nextBackoffEnd(alice), isNull);

      expect(await dao.autosave(alice, theirs.id, pgn: 'hacked'), isFalse);
      expect(await dao.markSubmitting(alice, theirs.id), isFalse);
      expect(await dao.reopen(alice, theirs.id), isFalse);
      expect(await dao.remove(alice, theirs.id), isFalse);
      expect(await dao.clearBackoff(alice), 0);

      final untouched = (await dao.get(bob, theirs.id))!;
      expect(untouched.pgn, 'theirs');
      expect(untouched.state, DraftState.ready);
    });
  });
}
