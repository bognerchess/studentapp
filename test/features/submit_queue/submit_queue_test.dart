// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/api/analysis_api.dart';
import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/features/entry/domain/entry_draft_store.dart';
import 'package:bogner_chess/features/submit_queue/data/drift_entry_draft_store.dart';
import 'package:bogner_chess/features/submit_queue/domain/draft_meta.dart';
import 'package:bogner_chess/features/submit_queue/domain/submit_models.dart';
import 'package:bogner_chess/features/submit_queue/domain/submit_queue.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const alice = 'sub-alice';
const bob = 'sub-bob';

final _start = DateTime.utc(2026, 9, 20, 12);

const _white = GameMetadata(
  whiteName: 'Alice Example',
  blackName: 'Jonas Keller',
  playerColor: PlayerColor.white,
  result: GameResult.whiteWins,
);

/// Everything around one queue, inside a fake-time zone.
class Harness {
  Harness(this.async) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final clock = async.getClock(_start);
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
      clock: clock.now,
    );
    queue = newQueue();
    queue.events.listen(events.add);
  }

  final FakeAsync async;
  late final AppDatabase db;
  late SubmitQueue queue;
  final games = FakeGamesApi();
  final analysis = FakeAnalysisApi();
  final connectivity = FakeConnectivity();
  final jobs = RecordingJobSink();
  final events = <SubmitEvent>[];
  int libraryRefreshes = 0;
  String? owner = alice;

  DraftsDao get dao => db.draftsDao;

  SubmitQueue newQueue() => SubmitQueue(
    database: () => db,
    games: () => games,
    analysis: () => analysis,
    owner: () => owner,
    connectivity: connectivity,
    jobSink: () => jobs,
    onLibraryChanged: () => libraryRefreshes++,
    coachLanguage: () => 'de',
  );

  /// Runs microtasks and zero-length timers until [future] is done.
  T wait<T>(Future<T> future) {
    T? value;
    Object? error;
    var done = false;
    unawaited(
      future.then(
        (v) {
          value = v;
          done = true;
        },
        onError: (Object e) {
          error = e;
          done = true;
        },
      ),
    );
    async.flushMicrotasks();
    if (!done) async.elapse(Duration.zero);
    expect(done, isTrue, reason: 'the future needs more than microtasks');
    // Whatever the future failed with.
    // ignore: only_throw_errors
    if (error != null) throw error!;
    return value as T;
  }

  void settle() {
    async.flushMicrotasks();
    async.elapse(Duration.zero);
  }

  /// A ready draft of [sub], straight into the table.
  Draft ready(
    String sub, {
    bool analyse = true,
    String pgn = '1. e4 e5 2. Nf3',
    GameMetadata metadata = _white,
  }) => wait(
    dao.create(
      sub,
      pgn: pgn,
      metaJson: DraftMeta(metadata: metadata, source: DraftSource.pgn).encode(),
      wantsAnalysis: analyse,
      ready: true,
    ),
  );

  Draft draft(String id, [String sub = alice]) => wait(dao.get(sub, id))!;

  void dispose() {
    queue.dispose();
    wait(db.close());
  }
}

void withQueue(void Function(Harness h) body) {
  fakeAsync((async) {
    final h = Harness(async);
    body(h);
    h.dispose();
    async.flushMicrotasks();
  });
}

void main() {
  group('a successful upload', () {
    test('imports, requests the analysis, hands over the job', () {
      withQueue((h) {
        final id = h.wait(
          h.queue.enqueueImport(
            movetext: '1. e4 e5 2. Nf3',
            metadata: _white,
            source: DraftSource.share,
            analyse: true,
          ),
        )!;
        h.settle();

        final draft = h.draft(id);
        expect(draft.state, DraftState.submitted);
        expect(draft.serverGameId, 'game-1');
        expect(draft.attempts, 0);
        expect(draft.lastError, isNull);

        final call = h.games.calls.single;
        expect(call.clientGameId, draft.clientGameId);
        expect(call.movetext, '1. e4 e5 2. Nf3');
        expect(call.metadata, _white);
        expect(call.source, ImportSource.share);
        expect(h.analysis.calls.single, (gameId: 'game-1', language: 'de'));
        expect(h.jobs.jobs.single.gameId, 'game-1');
        expect(h.libraryRefreshes, 1);

        final event = h.events.single as GameUploaded;
        expect(event.draftId, id);
        expect(event.gameId, 'game-1');
        expect(event.analysis, SubmittedAnalysis.started);
        expect(h.queue.status.value, SubmitQueueStatus.idle);
      });
    });

    test('"save only" never asks for an analysis', () {
      withQueue((h) {
        final id = h.wait(
          h.queue.enqueueImport(
            movetext: '1. d4',
            metadata: _white,
            source: DraftSource.file,
            analyse: false,
          ),
        )!;
        h.settle();

        expect(h.draft(id).state, DraftState.submitted);
        expect(h.games.calls.single.source, ImportSource.pgn);
        expect(h.analysis.calls, isEmpty);
        expect(h.jobs.jobs, isEmpty);
        expect(
          (h.events.single as GameUploaded).analysis,
          SubmittedAnalysis.notRequested,
        );
      });
    });

    test('the board path: the autosaved draft gets its metadata', () {
      withQueue((h) {
        final store = DriftEntryDraftStore(
          database: () => h.db,
          owner: () => h.owner,
        );
        const id = '00000000-0000-4000-8000-000000000001';
        h.wait(
          store.save(
            EntryDraftSnapshot(
              id: id,
              pgnMoves: '1. e4 e5',
              cursorPly: 1,
              orientation: Side.black,
              updatedAt: _start,
            ),
          ),
        );
        expect(h.draft(id).state, DraftState.editing);
        h.settle();
        expect(h.games.calls, isEmpty, reason: 'editing drafts are not sent');

        final queued = h.wait(
          h.queue.enqueueEntry(
            draftId: id,
            pgnMoves: '1. e4 e5 2. Nf3',
            metadata: _white,
            orientation: Side.black,
            analyse: true,
          ),
        );
        expect(queued, isTrue);
        // The closing entry screen flushes once more. Too late to matter.
        h.wait(
          store.save(
            EntryDraftSnapshot(
              id: id,
              pgnMoves: '1. e4',
              cursorPly: 1,
              orientation: Side.white,
              updatedAt: _start,
            ),
          ),
        );
        h.settle();

        final draft = h.draft(id);
        expect(draft.state, DraftState.submitted);
        expect(draft.pgn, '1. e4 e5 2. Nf3');
        final meta = DraftMeta.decode(draft.metaJson);
        expect(meta.metadata, _white);
        expect(meta.source, DraftSource.board);
        expect(meta.orientation, Side.black);
        expect(meta.cursorPly, 1);
        expect(h.games.calls.single.source, ImportSource.board);
        expect(h.games.calls.single.movetext, '1. e4 e5 2. Nf3');

        // Saving the same draft twice does nothing.
        expect(
          h.wait(
            h.queue.enqueueEntry(
              draftId: id,
              pgnMoves: '1. e4',
              metadata: _white,
              orientation: Side.white,
              analyse: true,
            ),
          ),
          isFalse,
        );
        expect(h.draft(id).pgn, '1. e4 e5 2. Nf3');
      });
    });

    test('a draft whose autosave never landed is created on save', () {
      withQueue((h) {
        const id = '00000000-0000-4000-8000-000000000002';
        expect(
          h.wait(
            h.queue.enqueueEntry(
              draftId: id,
              pgnMoves: '1. c4',
              metadata: _white,
              orientation: Side.white,
              analyse: false,
            ),
          ),
          isTrue,
        );
        h.settle();
        expect(h.draft(id).state, DraftState.submitted);
        expect(h.games.calls.single.movetext, '1. c4');
      });
    });
  });

  group('the game is saved, the analysis is not started', () {
    final cases = <AnalysisHold, RequestAnalysisOutcome>{
      AnalysisHold.limitReached: AnalysisLimitReached(
        window: LimitWindow.day,
        limit: 3,
        used: 3,
        resetAt: DateTime.utc(2026, 9, 21),
      ),
      AnalysisHold.queueFull: const AnalysisQueueFull(2),
      AnalysisHold.rateLimited: const AnalysisRateLimited(
        Duration(seconds: 30),
      ),
      AnalysisHold.emailNotVerified: const AnalysisEmailNotVerified(),
      AnalysisHold.aiConsentRequired: const AnalysisAiConsentRequired(2),
    };
    for (final MapEntry(key: hold, value: outcome) in cases.entries) {
      test('${hold.name}: submitted, reason kept, no loop', () {
        withQueue((h) {
          h.analysis.outcomes.add(outcome);
          final draft = h.ready(alice);
          h.wait(h.queue.kick());

          final after = h.draft(draft.id);
          expect(after.state, DraftState.submitted);
          expect(after.serverGameId, 'game-1');
          expect(DraftMeta.decode(after.metaJson).analysisHold, hold);
          expect(DraftMeta.decode(after.metaJson).metadata, _white);
          final event = h.events.single as GameUploaded;
          expect(event.analysis, SubmittedAnalysis.held);
          expect(event.hold, hold);
          expect(h.jobs.jobs, isEmpty);

          h.async.elapse(const Duration(hours: 3));
          h.queue.onAppResumed();
          h.settle();
          expect(h.analysis.calls, hasLength(1));
          expect(h.games.calls, hasLength(1));
        });
      });
    }
  });

  group('failures', () {
    test('a PGN the server cannot read fails for good, readably', () {
      withQueue((h) {
        h.games.failures.add(
          const ImportPgnInvalid(moveNumber: 12, san: 'Nf9'),
        );
        final draft = h.ready(alice);
        h.wait(h.queue.kick());

        final after = h.draft(draft.id);
        expect(after.state, DraftState.failed);
        expect(after.attempts, 1);
        expect(
          SubmitError.parse(after.lastError),
          const SubmitError(
            SubmitErrorKind.pgnInvalid,
            moveNumber: 12,
            san: 'Nf9',
          ),
        );
        expect(
          (h.events.single as UploadFailed).error.kind,
          SubmitErrorKind.pgnInvalid,
        );
        expect(h.queue.status.value.failed, 1);
        expect(h.queue.status.value.waiting, 0);

        h.async.elapse(const Duration(hours: 2));
        expect(h.games.calls, hasLength(1), reason: 'no retry by itself');

        // The visible Retry.
        h.wait(h.queue.retry(draft.id));
        expect(h.draft(draft.id).state, DraftState.submitted);
        expect(h.queue.status.value, SubmitQueueStatus.idle);
      });
    });

    test('a game the server refuses fails for good; the next one is sent', () {
      withQueue((h) {
        h.games.failures.add(
          const ImportFailed(ApiRejected(typename: 'BusinessError')),
        );
        final refused = h.ready(alice);
        h.async.elapse(const Duration(seconds: 1));
        final fine = h.ready(alice);
        h.wait(h.queue.kick());

        expect(h.draft(refused.id).state, DraftState.failed);
        expect(
          SubmitError.parse(h.draft(refused.id).lastError).kind,
          SubmitErrorKind.rejected,
        );
        expect(h.draft(fine.id).state, DraftState.submitted);
      });
    });

    test('network errors back off 5 s, 15 s, 1 min, 5 min, 30 min, 30 min, '
        '30 min, then the draft is failed', () {
      withQueue((h) {
        const offline = ImportFailed(ApiNetworkError());
        h.games.failures.addAll(List.filled(SubmitQueue.maxAttempts, offline));
        final draft = h.ready(alice);
        final times = <Duration>[];
        var seen = 0;
        void note() {
          while (seen < h.games.calls.length) {
            seen++;
            times.add(h.db.now().difference(_start));
          }
        }

        h.wait(h.queue.kick());
        note();
        for (var second = 0; second < 3 * 3600; second++) {
          h.async.elapse(const Duration(seconds: 1));
          note();
        }

        expect(times, const [
          Duration.zero,
          Duration(seconds: 5),
          Duration(seconds: 20),
          Duration(seconds: 80),
          Duration(seconds: 380),
          Duration(seconds: 2180),
          Duration(seconds: 3980),
          Duration(seconds: 5780),
        ]);
        final after = h.draft(draft.id);
        expect(after.state, DraftState.failed);
        expect(after.attempts, SubmitQueue.maxAttempts);
        expect(
          SubmitError.parse(after.lastError).kind,
          SubmitErrorKind.network,
        );
        expect(h.events.single, isA<UploadFailed>());

        // Retry starts from a clean slate.
        h.wait(h.queue.retryAll());
        final retried = h.draft(draft.id);
        expect(retried.state, DraftState.submitted);
        expect(h.games.stored, hasLength(1));
      });
    });

    test('while a draft waits for its back-off the status says when', () {
      withQueue((h) {
        h.games.failures.add(
          const ImportFailed(ApiServerError(statusCode: 503)),
        );
        final draft = h.ready(alice);
        h.wait(h.queue.kick());

        final waiting = h.draft(draft.id);
        expect(waiting.state, DraftState.ready);
        expect(waiting.attempts, 1);
        expect(
          SubmitError.parse(waiting.lastError).kind,
          SubmitErrorKind.server,
        );
        final status = h.queue.status.value;
        expect(status.waiting, 1);
        expect(status.uploading, isFalse);
        expect(
          status.nextAttemptAt!.isAtSameMomentAs(
            _start.add(const Duration(seconds: 5)),
          ),
          isTrue,
        );

        h.async.elapse(const Duration(seconds: 5));
        expect(h.draft(draft.id).state, DraftState.submitted);
        expect(h.queue.status.value, SubmitQueueStatus.idle);
      });
    });

    test('a rate-limited import waits at least as long as the server says', () {
      withQueue((h) {
        h.games.failures.add(const ImportRateLimited(Duration(seconds: 90)));
        final draft = h.ready(alice);
        h.wait(h.queue.kick());

        expect(
          SubmitError.parse(h.draft(draft.id).lastError).kind,
          SubmitErrorKind.rateLimited,
        );
        h.async.elapse(const Duration(seconds: 89));
        expect(h.games.calls, hasLength(1));
        h.async.elapse(const Duration(seconds: 1));
        expect(h.games.calls, hasLength(2));
        expect(h.draft(draft.id).state, DraftState.submitted);
      });
    });

    test(
      'trouble with the server stops the run; the others wait their turn',
      () {
        withQueue((h) {
          h.games.failures.add(const ImportFailed(ApiNetworkError()));
          final first = h.ready(alice);
          h.async.elapse(const Duration(seconds: 1));
          final second = h.ready(alice);
          h.wait(h.queue.kick());

          expect(h.games.calls, hasLength(1));
          expect(h.draft(second.id).state, DraftState.ready);
          expect(h.draft(second.id).attempts, 0);

          h.async.elapse(const Duration(seconds: 5));
          expect(h.draft(first.id).state, DraftState.submitted);
          expect(h.draft(second.id).state, DraftState.submitted);
        });
      },
    );

    test('a failing analysis request repeats the request, not the import, '
        'and never makes the saved game look failed', () {
      withQueue((h) {
        const offline = AnalysisRequestFailed(ApiNetworkError());
        h.analysis.outcomes.addAll(
          List.filled(SubmitQueue.maxAttempts, offline),
        );
        final draft = h.ready(alice);
        h.wait(h.queue.kick());

        var after = h.draft(draft.id);
        expect(after.state, DraftState.ready);
        expect(after.serverGameId, 'game-1');
        expect(h.libraryRefreshes, 1);

        h.async.elapse(const Duration(hours: 3));
        after = h.draft(draft.id);
        expect(after.state, DraftState.submitted);
        expect(
          DraftMeta.decode(after.metaJson).analysisHold,
          AnalysisHold.requestFailed,
        );
        expect(h.games.calls, hasLength(1));
        expect(h.analysis.calls, hasLength(SubmitQueue.maxAttempts));
        expect(h.events.whereType<UploadFailed>(), isEmpty);
        expect(
          (h.events.single as GameUploaded).hold,
          AnalysisHold.requestFailed,
        );
      });
    });
  });

  group('idempotency', () {
    test('a lost answer: the second import returns the same game', () {
      withQueue((h) {
        h.games.loseNextAnswer = true;
        final draft = h.ready(alice);
        h.wait(h.queue.kick());
        expect(h.games.stored, hasLength(1));
        expect(h.draft(draft.id).serverGameId, isNull);

        h.async.elapse(const Duration(seconds: 5));
        expect(h.games.calls, hasLength(2));
        expect(h.games.calls[0].clientGameId, h.games.calls[1].clientGameId);
        expect(h.games.stored, hasLength(1));
        expect(h.draft(draft.id).state, DraftState.submitted);
        expect(h.draft(draft.id).serverGameId, 'game-1');
      });
    });

    test('killed between the import and markSubmitted: start() recovers, the '
        'server answers with the game it has', () {
      withQueue((h) {
        // What the killed process left: the server has the game, the row
        // still says "submitting" and knows no server id.
        final draft = h.ready(alice);
        h.wait(h.dao.markSubmitting(alice, draft.id));
        h.games.stored[draft.clientGameId] = GameSummary(
          id: 'game-from-before',
          clientGameId: draft.clientGameId,
          playerColor: PlayerColor.white,
          result: GameResult.whiteWins,
          hasAnalysis: false,
        );

        h.queue.start(observeLifecycle: false);
        h.settle();

        final after = h.draft(draft.id);
        expect(after.state, DraftState.submitted);
        expect(after.serverGameId, 'game-from-before');
        expect(h.games.stored, hasLength(1));
        expect(h.analysis.calls.single.gameId, 'game-from-before');
      });
    });

    test('killed after the server id was stored: no second import', () {
      withQueue((h) {
        final draft = h.ready(alice);
        h.wait(h.dao.markSubmitting(alice, draft.id));
        h.wait(h.dao.setServerGameId(alice, draft.id, 'game-7'));

        h.queue.start(observeLifecycle: false);
        h.settle();

        expect(h.games.calls, isEmpty);
        expect(h.analysis.calls.single.gameId, 'game-7');
        expect(h.draft(draft.id).state, DraftState.submitted);
      });
    });

    test('recovery happens once, not on every pass', () {
      withQueue((h) {
        h.queue.start(observeLifecycle: false);
        h.settle();
        // A draft that is "submitting" now is in flight, not interrupted.
        final gate = h.games.gate = Completer<void>();
        final draft = h.ready(alice);
        unawaited(h.queue.kick());
        h.settle();
        expect(h.draft(draft.id).state, DraftState.submitting);
        unawaited(h.queue.kick());
        h.queue.onAppResumed();
        h.settle();
        expect(h.draft(draft.id).state, DraftState.submitting);
        expect(h.games.calls, hasLength(1));
        gate.complete();
        h.settle();
        expect(h.draft(draft.id).state, DraftState.submitted);
        expect(h.games.calls, hasLength(1));
      });
    });
  });

  test(
    'single-flight and sequential: one request at a time, whatever kicks',
    () {
      withQueue((h) {
        final first = h.ready(alice, analyse: false);
        h.async.elapse(const Duration(seconds: 1));
        final second = h.ready(alice, analyse: false);
        final gate = h.games.gate = Completer<void>();

        for (var i = 0; i < 5; i++) {
          unawaited(h.queue.kick());
        }
        h.queue.onAppResumed();
        h.connectivity.set(online: true);
        h.settle();

        expect(h.games.calls, hasLength(1), reason: 'the second one waits');
        expect(h.draft(first.id).state, DraftState.submitting);
        expect(h.draft(second.id).state, DraftState.ready);
        expect(h.queue.status.value.uploading, isTrue);
        expect(h.queue.status.value.waiting, 2);

        h.games.gate = null;
        gate.complete();
        h.settle();

        expect(h.games.calls, hasLength(2));
        expect(h.games.calls.map((c) => c.clientGameId).toSet(), hasLength(2));
        expect(h.draft(first.id).state, DraftState.submitted);
        expect(h.draft(second.id).state, DraftState.submitted);
        expect(h.queue.status.value, SubmitQueueStatus.idle);
      });
    },
  );

  group('owners', () {
    test("only the signed-in user's drafts are sent", () {
      withQueue((h) {
        final hers = h.ready(alice);
        final his = h.ready(bob);
        h.owner = bob;
        h.wait(h.queue.kick());

        expect(h.draft(his.id, bob).state, DraftState.submitted);
        expect(h.draft(hers.id).state, DraftState.ready);
        expect(h.draft(hers.id).attempts, 0);
        expect(h.games.calls.single.clientGameId, his.clientGameId);

        // Sign-in is a trigger.
        h.owner = alice;
        h.queue.onOwnerChanged();
        h.settle();
        expect(h.draft(hers.id).state, DraftState.submitted);
      });
    });

    test('signed out: nothing is queued, nothing is sent, drafts stay', () {
      withQueue((h) {
        final draft = h.ready(alice);
        h.owner = null;
        h.queue.start(observeLifecycle: false);
        h.queue.onOwnerChanged();
        h.settle();
        expect(
          h.wait(
            h.queue.enqueueImport(
              movetext: '1. e4',
              metadata: _white,
              source: DraftSource.pgn,
              analyse: true,
            ),
          ),
          isNull,
        );
        h.async.elapse(const Duration(hours: 1));
        expect(h.games.calls, isEmpty);
        expect(h.draft(draft.id).state, DraftState.ready);
        expect(h.queue.status.value, SubmitQueueStatus.idle);
      });
    });

    test('somebody else signs in while a game is on its way: the rest of it '
        'waits for its owner', () {
      withQueue((h) {
        final hers = h.ready(alice);
        final his = h.ready(bob, analyse: false);
        final gate = h.games.gate = Completer<void>();
        unawaited(h.queue.kick());
        h.settle();
        expect(h.games.calls, hasLength(1));

        h.owner = bob;
        h.queue.onOwnerChanged();
        h.games.gate = null;
        gate.complete();
        h.settle();

        // Her import had left with her token; the analysis request would
        // have left with his.
        final after = h.draft(hers.id);
        expect(after.state, DraftState.ready);
        expect(after.serverGameId, 'game-1');
        expect(h.analysis.calls, isEmpty);
        expect(h.draft(his.id, bob).state, DraftState.submitted);

        h.owner = alice;
        h.queue.onOwnerChanged();
        h.settle();
        expect(h.draft(hers.id).state, DraftState.submitted);
        expect(h.analysis.calls.single.gameId, 'game-1');
        expect(h.games.calls, hasLength(2), reason: 'hers once, his once');
      });
    });
  });

  group('triggers', () {
    test('offline: nothing is tried and no attempt is used up; the network '
        'coming back sends the game', () {
      withQueue((h) {
        h.connectivity.online = false;
        h.queue.start(observeLifecycle: false);
        final id = h.wait(
          h.queue.enqueueImport(
            movetext: '1. e4',
            metadata: _white,
            source: DraftSource.pgn,
            analyse: true,
          ),
        )!;
        h.settle();
        h.async.elapse(const Duration(hours: 5));

        expect(h.games.calls, isEmpty);
        expect(h.draft(id).state, DraftState.ready);
        expect(h.draft(id).attempts, 0);
        expect(h.queue.status.value.offline, isTrue);
        expect(h.queue.status.value.waiting, 1);

        h.connectivity.set(online: true);
        h.settle();
        expect(h.draft(id).state, DraftState.submitted);
        expect(h.queue.status.value, SubmitQueueStatus.idle);
      });
    });

    test('Retry tries even when the device claims to be offline', () {
      withQueue((h) {
        h.connectivity.online = false;
        final draft = h.ready(alice);
        h.wait(h.queue.kick());
        expect(h.games.calls, isEmpty);

        h.wait(h.queue.retryAll());
        expect(h.draft(draft.id).state, DraftState.submitted);
      });
    });

    test('the network coming back and the app resuming end every back-off', () {
      withQueue((h) {
        h.queue.start(observeLifecycle: false);
        h.settle();
        h.games.failures.addAll(const [
          ImportFailed(ApiNetworkError()),
          ImportFailed(ApiNetworkError()),
          ImportFailed(ApiNetworkError()),
        ]);
        final draft = h.ready(alice);
        h.wait(h.queue.kick());
        h.async.elapse(const Duration(seconds: 5));
        h.async.elapse(const Duration(seconds: 15));
        expect(h.games.calls, hasLength(3));
        expect(h.draft(draft.id).nextAttemptAt, isNotNull);

        h.queue.onAppResumed();
        h.settle();
        expect(h.games.calls, hasLength(4));
        expect(h.draft(draft.id).state, DraftState.submitted);
      });
    });

    test('start() is a trigger', () {
      withQueue((h) {
        final draft = h.ready(alice);
        h.queue.start(observeLifecycle: false);
        h.settle();
        expect(h.draft(draft.id).state, DraftState.submitted);
      });
    });
  });

  group('housekeeping', () {
    test('delete removes a waiting draft, not one that is being sent', () {
      withQueue((h) {
        h.connectivity.online = false;
        final draft = h.ready(alice);
        h.wait(h.queue.kick());
        expect(h.queue.status.value.waiting, 1);
        expect(h.wait(h.queue.delete(draft.id)), isTrue);
        h.settle();
        expect(h.queue.status.value.waiting, 0);

        h.connectivity.online = true;
        final gate = h.games.gate = Completer<void>();
        final flying = h.ready(alice);
        unawaited(h.queue.kick());
        h.settle();
        expect(h.wait(h.queue.delete(flying.id)), isFalse);
        gate.complete();
        h.settle();
        expect(h.draft(flying.id).state, DraftState.submitted);
      });
    });

    test('submitted drafts are forgotten after a week', () {
      withQueue((h) {
        final old = h.ready(alice);
        h.wait(h.queue.kick());
        expect(h.draft(old.id).state, DraftState.submitted);
        h.async.elapse(const Duration(days: 8));
        final recent = h.ready(alice);

        // The next start of the app.
        h.queue.dispose();
        h.queue = h.newQueue()..start(observeLifecycle: false);
        h.settle();

        expect(h.wait(h.dao.get(alice, old.id)), isNull);
        expect(h.draft(recent.id).state, DraftState.submitted);
      });
    });
  });

  group('DraftMeta', () {
    test('round trip; GameMetadata.fromJson reads the same text', () {
      const meta = DraftMeta(
        metadata: _white,
        source: DraftSource.file,
        cursorPly: 7,
        orientation: Side.black,
        analysisHold: AnalysisHold.queueFull,
      );
      final text = meta.encode();
      expect(DraftMeta.decode(text), meta);
      expect(
        GameMetadata.fromJson(DraftMeta.decode(text).metadata.toJson()),
        _white,
      );
    });

    test('damaged or foreign text reads as an empty board draft', () {
      for (final text in [
        '',
        '{}',
        'null',
        '[1]',
        '{"draft": 3}',
        '{"draft":'
            ' {"source": "telepathy", "cursorPly": -4, "orientation": 1}}',
      ]) {
        expect(DraftMeta.decode(text), const DraftMeta(), reason: text);
      }
    });

    test('SubmitError survives the last_error column', () {
      for (final kind in SubmitErrorKind.values) {
        expect(SubmitError.parse(SubmitError(kind).encode()).kind, kind);
      }
      expect(SubmitError.parse(null).kind, SubmitErrorKind.server);
      expect(SubmitError.parse('something old').kind, SubmitErrorKind.server);
      expect(
        SubmitError.parse(
          const SubmitError(SubmitErrorKind.pgnInvalid, san: 'a|b').encode(),
        ).san,
        'ab',
      );
    });
  });
}
