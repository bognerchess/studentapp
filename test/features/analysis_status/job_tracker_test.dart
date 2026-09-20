// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:io';

import 'package:bogner_chess/core/api/analysis_api.dart';
import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/features/analysis_status/domain/job_tracker.dart';
import 'package:bogner_chess/features/library/data/cached_games_repository.dart';
import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/api/api_test_support.dart';
import '../../core/storage/test_database.dart';
import '../../helpers/fixture_link.dart';

Map<String, dynamic> jobJson(
  String id,
  String gameId,
  String status, {
  String? stage,
  int? queuePosition,
  String? failureCode,
}) => {
  'id': id,
  'chessGameId': gameId,
  'status': status,
  'stage': stage,
  'queuePosition': queuePosition,
  'requestedAt': '2026-09-19T10:00:00.000Z',
  'finishedAt': status == 'DONE' || status == 'FAILED'
      ? '2026-09-19T10:03:00.000Z'
      : null,
  'failureCode': failureCode,
};

JobInfo queuedJob(String id, String gameId) => JobInfo(
  id: id,
  gameId: gameId,
  status: JobStatus.queued,
  queuePosition: 0,
  requestedAt: DateTime.utc(2026, 9, 19, 10),
);

/// An in-memory database whose query streams close synchronously.
///
/// drift otherwise keeps a closed stream's cache alive for one more turn of
/// the event loop, with a timer. Under a fake clock that timer would still
/// be pending when the test ends, and cancelling the subscription would
/// wait for it for ever.
AppDatabase openTrackerDatabase(FakeClock clock) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
    clock: clock.call,
  );
}

/// Completes [future] under the fake clock and returns its value.
T settle<T>(FakeAsync async, Future<T> future) {
  Object? value;
  var done = false;
  unawaited(
    future.then((result) {
      value = result;
      done = true;
    }),
  );
  async.flushMicrotasks();
  expect(done, isTrue, reason: 'the future did not complete');
  return value as T;
}

/// A scripted server: the jobs by id, in whatever state the test puts them.
class Server {
  Server(this.link) {
    link
      ..respond(
        'MyActiveAnalysisJobs',
        (_) => {
          'data': {
            'myActiveAnalysisJobs': [
              for (final job in jobs.values)
                if (job['status'] == 'QUEUED' || job['status'] == 'RUNNING')
                  job,
            ],
          },
        },
      )
      ..respond(
        'AnalysisJob',
        (variables) => {
          'data': {'analysisJob': jobs[variables['id']]},
        },
      );
  }

  final FixtureLink link;
  final Map<String, Map<String, dynamic>> jobs = {};

  int get polls => link.requestsOf('MyActiveAnalysisJobs').length;
  int get lookups => link.requestsOf('AnalysisJob').length;
  int get analysisFetches => link.requestsOf('GameAnalysis').length;
}

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late FixtureLink link;
  late Server server;
  late JobTracker tracker;
  late List<JobTrackerEvent> events;

  JobTracker newTracker({Duration Function()? baseInterval}) {
    final executor = linkExecutor(link);
    final created = JobTracker(
      api: AnalysisApi(executor),
      db: db,
      games: CachedGamesRepository(api: GamesApi(executor), db: db),
      baseInterval: baseInterval,
    );
    created.events.listen(events.add);
    return created;
  }

  setUp(() {
    clock = FakeClock();
    db = openTrackerDatabase(clock);
    link = FixtureLink();
    server = Server(link);
    events = [];
    tracker = newTracker();
  });

  tearDown(() async {
    tracker.dispose();
    await db.close();
  });

  /// Runs [body] under a fake clock; `async.elapse` moves time.
  void fake(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      body(async);
      async.flushMicrotasks();
    });
  }

  group('polling', () {
    test('nothing to watch: one reconciling poll, then silence', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        async.flushMicrotasks();
        expect(server.polls, 1);
        expect(tracker.currentInterval, isNull);

        async.elapse(const Duration(minutes: 5));
        expect(server.polls, 1);
      });
    });

    test('3 s, then x1.5 each time, capped at 30 s', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        async.flushMicrotasks();
        server.jobs['j1'] = jobJson('j1', 'g1', 'QUEUED', queuePosition: 0);
        unawaited(tracker.track(queuedJob('j1', 'g1')));
        async.flushMicrotasks();
        final before = server.polls;

        final waits = <Duration>[];
        for (var i = 0; i < 9; i++) {
          final wait = tracker.currentInterval!;
          waits.add(wait);
          async.elapse(wait - const Duration(milliseconds: 1));
          expect(server.polls, before + i, reason: 'too early ($i)');
          async.elapse(const Duration(milliseconds: 1));
          expect(server.polls, before + i + 1, reason: 'due ($i)');
        }
        expect(waits.take(7), const [
          Duration(milliseconds: 3000),
          Duration(milliseconds: 4500),
          Duration(milliseconds: 6750),
          Duration(milliseconds: 10125),
          Duration(microseconds: 15187500),
          Duration(microseconds: 22781250),
          Duration(seconds: 30),
        ]);
        expect(waits.skip(7), everyElement(const Duration(seconds: 30)));
      });
    });

    test('the base interval comes from the configuration', () {
      tracker.dispose();
      tracker = newTracker(baseInterval: () => const Duration(seconds: 5));
      fake((async) {
        unawaited(tracker.setOwner(alice));
        server.jobs['j1'] = jobJson('j1', 'g1', 'RUNNING');
        unawaited(tracker.track(queuedJob('j1', 'g1')));
        async.flushMicrotasks();
        expect(tracker.currentInterval, const Duration(seconds: 5));
      });
    });

    test('refreshNow polls at once and starts the interval again', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        server.jobs['j1'] = jobJson('j1', 'g1', 'RUNNING', stage: 'engine');
        unawaited(tracker.track(queuedJob('j1', 'g1')));
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 3))
          ..elapse(const Duration(milliseconds: 4500));
        expect(tracker.currentInterval, const Duration(milliseconds: 6750));
        final before = server.polls;

        unawaited(tracker.refreshNow());
        async.flushMicrotasks();
        expect(server.polls, before + 1);
        expect(tracker.currentInterval, const Duration(seconds: 3));
      });
    });

    test('the background stops it; coming back polls at once', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        server.jobs['j1'] = jobJson('j1', 'g1', 'RUNNING');
        unawaited(tracker.track(queuedJob('j1', 'g1')));
        async.flushMicrotasks();
        final before = server.polls;

        tracker.setForeground(false);
        expect(tracker.currentInterval, isNull);
        async.elapse(const Duration(minutes: 10));
        expect(server.polls, before);

        // A push while in the background: nothing happens.
        unawaited(tracker.refreshNow());
        async.flushMicrotasks();
        expect(server.polls, before);

        tracker.setForeground(true);
        async.flushMicrotasks();
        expect(server.polls, before + 1);
        expect(tracker.currentInterval, const Duration(seconds: 3));
      });
    });

    test('signing out stops it and forgets the jobs', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        server.jobs['j1'] = jobJson('j1', 'g1', 'RUNNING');
        unawaited(tracker.track(queuedJob('j1', 'g1')));
        async.flushMicrotasks();
        final before = server.polls;

        unawaited(tracker.setOwner(null));
        async.flushMicrotasks();
        expect(tracker.jobs.value, isEmpty);
        async.elapse(const Duration(minutes: 1));
        expect(server.polls, before);
      });
    });

    test('a failing poll keeps the jobs and the rhythm', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        server.jobs['j1'] = jobJson('j1', 'g1', 'RUNNING');
        unawaited(tracker.track(queuedJob('j1', 'g1')));
        async.flushMicrotasks();

        link.fail('MyActiveAnalysisJobs', const SocketException('offline'));
        async.elapse(const Duration(seconds: 3));
        expect(tracker.hasActiveJobs, isTrue);
        expect(tracker.currentInterval, const Duration(milliseconds: 4500));
        expect(events, isEmpty);
      });
    });

    test('dispose cancels the timer', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        server.jobs['j1'] = jobJson('j1', 'g1', 'RUNNING');
        unawaited(tracker.track(queuedJob('j1', 'g1')));
        async.flushMicrotasks();
        tracker.dispose();
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  group('a job', () {
    test('progress reaches the state: queue position, then stage', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        server.jobs['j1'] = jobJson('j1', 'g1', 'QUEUED', queuePosition: 2);
        unawaited(tracker.track(queuedJob('j1', 'g1')));
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 3));
        expect(tracker.jobs.value['g1']!.queuePosition, 2);

        server.jobs['j1'] = jobJson('j1', 'g1', 'RUNNING', stage: 'coach');
        async.elapse(const Duration(milliseconds: 4500));
        final job = tracker.jobs.value['g1']!;
        expect(job.status, JobStatus.running);
        expect(job.stage, 'coach');
        expect(job.queuePosition, isNull);
      });
    });

    test('done: analysis cached once, library badge, event, no more polls', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        async.flushMicrotasks();
        // The library knows the game.
        final games = CachedGamesRepository(
          api: GamesApi(linkExecutor(link)),
          db: db,
        );
        unawaited(games.fetchPage(alice, fetchedAt: db.now()));
        async.flushMicrotasks();

        server.jobs['j9'] = jobJson('j9', 'game-3', 'RUNNING');
        unawaited(tracker.track(queuedJob('j9', 'game-3')));
        async.flushMicrotasks();
        final tracked = settle(async, games.cached(alice, 'game-3'))!;
        expect(tracked.latestJob!.id, 'j9');
        expect(tracked.hasAnalysis, isFalse);

        server.jobs['j9'] = jobJson('j9', 'game-3', 'DONE');
        async.elapse(const Duration(seconds: 3));

        expect(events.single, isA<AnalysisReadyEvent>());
        expect(events.single.gameId, 'game-3');
        expect(server.lookups, 1);
        expect(server.analysisFetches, 1);
        expect(tracker.jobs.value['game-3']!.status, JobStatus.done);
        expect(tracker.hasActiveJobs, isFalse);
        expect(tracker.currentInterval, isNull);

        final cached = settle(async, db.analysisCacheDao.get(alice, 'game-3'))!;
        expect(cached.schemaVersion, 1);
        expect(cached.payload, contains('bognerchess.game-analysis'));
        final game = settle(async, games.cached(alice, 'game-3'))!;
        expect(game.hasAnalysis, isTrue);
        expect(game.latestJob!.status, JobStatus.done);
        expect(settle(async, db.pendingJobsDao.getActive(alice)), isEmpty);

        final polls = server.polls;
        async.elapse(const Duration(minutes: 5));
        expect(server.polls, polls);
        expect(server.analysisFetches, 1);
      });
    });

    test('done while the analysis cannot be fetched: still ready', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        server.jobs['j1'] = jobJson('j1', 'g1', 'RUNNING');
        unawaited(tracker.track(queuedJob('j1', 'g1')));
        async.flushMicrotasks();

        link.fail('GameAnalysis', const SocketException('offline'));
        server.jobs['j1'] = jobJson('j1', 'g1', 'DONE');
        async.elapse(const Duration(seconds: 3));
        expect(events.single, isA<AnalysisReadyEvent>());
      });
    });

    test('failed: marked, surfaced with its code, nothing fetched', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        server.jobs['j1'] = jobJson('j1', 'g1', 'RUNNING');
        unawaited(tracker.track(queuedJob('j1', 'g1')));
        async.flushMicrotasks();

        server.jobs['j1'] = jobJson(
          'j1',
          'g1',
          'FAILED',
          failureCode: 'engine_timeout',
        );
        async.elapse(const Duration(seconds: 3));

        final event = events.single as AnalysisFailedEvent;
        expect(event.gameId, 'g1');
        expect(event.failureCode, 'engine_timeout');
        expect(tracker.jobs.value['g1']!.status, JobStatus.failed);
        expect(server.analysisFetches, 0);
        expect(tracker.currentInterval, isNull);
      });
    });

    test('a lookup that fails is repeated with the next poll', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        server.jobs['j1'] = jobJson('j1', 'g1', 'RUNNING');
        unawaited(tracker.track(queuedJob('j1', 'g1')));
        async.flushMicrotasks();

        server.jobs['j1'] = jobJson('j1', 'g1', 'DONE');
        link.fail('AnalysisJob', const SocketException('offline'));
        async.elapse(const Duration(seconds: 3));
        expect(events, isEmpty);
        expect(tracker.hasActiveJobs, isTrue);

        server.link.respond(
          'AnalysisJob',
          (variables) => {
            'data': {'analysisJob': server.jobs[variables['id']]},
          },
        );
        async.elapse(const Duration(milliseconds: 4500));
        expect(events.single, isA<AnalysisReadyEvent>());
      });
    });

    test('a job the server no longer knows is dropped quietly', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        server.jobs['j1'] = jobJson('j1', 'g1', 'RUNNING');
        unawaited(tracker.track(queuedJob('j1', 'g1')));
        async.flushMicrotasks();

        server.jobs.remove('j1');
        async.elapse(const Duration(seconds: 3));
        expect(events, isEmpty);
        expect(tracker.jobs.value, isEmpty);
        expect(tracker.hasActiveJobs, isFalse);
      });
    });

    test('an unknown status counts as active', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        async.flushMicrotasks();
        unawaited(
          tracker.track(
            JobInfo(
              id: 'j1',
              gameId: 'g1',
              status: JobStatus.unknown,
              requestedAt: DateTime.utc(2026),
            ),
          ),
        );
        async.flushMicrotasks();
        expect(tracker.hasActiveJobs, isTrue);
        expect(tracker.currentInterval, isNotNull);
      });
    });

    test('two jobs, one poller', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        server.jobs['j1'] = jobJson('j1', 'g1', 'RUNNING');
        server.jobs['j2'] = jobJson('j2', 'g2', 'QUEUED', queuePosition: 0);
        unawaited(tracker.track(queuedJob('j1', 'g1')));
        unawaited(tracker.track(queuedJob('j2', 'g2')));
        async.flushMicrotasks();
        final before = server.polls;

        async.elapse(const Duration(seconds: 3));
        expect(server.polls, before + 1);

        server.jobs['j1'] = jobJson('j1', 'g1', 'DONE');
        async.elapse(const Duration(milliseconds: 4500));
        expect(events.single.gameId, 'g1');
        expect(tracker.hasActiveJobs, isTrue, reason: 'j2 is still queued');
        expect(tracker.currentInterval, isNotNull);
      });
    });
  });

  group('restart', () {
    test('persisted jobs are followed again after an app kill', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        server.jobs['j1'] = jobJson('j1', 'g1', 'RUNNING', stage: 'engine');
        unawaited(tracker.track(queuedJob('j1', 'g1')));
        async.flushMicrotasks();
        tracker.dispose();

        // The job ends while the app is gone.
        server.jobs['j1'] = jobJson('j1', 'g1', 'DONE');
        tracker = newTracker();
        unawaited(tracker.setOwner(alice));
        async.flushMicrotasks();

        expect(events.single, isA<AnalysisReadyEvent>());
        expect(tracker.jobs.value['g1']!.status, JobStatus.done);
      });
    });

    test('jobs requested elsewhere are adopted from the server', () {
      fake((async) {
        server.jobs['j7'] = jobJson('j7', 'g7', 'QUEUED', queuePosition: 1);
        unawaited(tracker.setOwner(alice));
        async.flushMicrotasks();

        expect(tracker.jobs.value['g7']!.queuePosition, 1);
        expect(tracker.currentInterval, const Duration(seconds: 3));
        expect(
          settle(async, db.pendingJobsDao.getActive(alice)).single.jobId,
          'j7',
        );
      });
    });

    test('a job the submit queue wrote into pending_jobs is adopted', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        async.flushMicrotasks();
        expect(tracker.currentInterval, isNull, reason: 'nothing to watch');

        // What AnalysisJobSink (WP-27) does after "Save & analyse".
        server.jobs['j5'] = jobJson('j5', 'g5', 'QUEUED', queuePosition: 0);
        unawaited(
          db.pendingJobsDao.upsert(
            alice,
            jobId: 'j5',
            gameId: 'g5',
            state: JobState.queued,
          ),
        );
        async.flushMicrotasks();

        expect(tracker.jobs.value['g5']!.status, JobStatus.queued);
        expect(tracker.hasActiveJobs, isTrue);
        expect(tracker.currentInterval, const Duration(seconds: 3));

        server.jobs['j5'] = jobJson('j5', 'g5', 'DONE');
        async.elapse(const Duration(seconds: 3));
        expect(events.single, isA<AnalysisReadyEvent>());
        // And the finished job does not come back through the stream.
        async.elapse(const Duration(minutes: 2));
        expect(tracker.hasActiveJobs, isFalse);
        expect(events, hasLength(1));
      });
    });

    test('another account does not see the jobs', () {
      fake((async) {
        unawaited(tracker.setOwner(alice));
        server.jobs['j1'] = jobJson('j1', 'g1', 'RUNNING');
        unawaited(tracker.track(queuedJob('j1', 'g1')));
        async.flushMicrotasks();

        server.jobs.clear();
        unawaited(tracker.setOwner(bob));
        async.flushMicrotasks();
        expect(tracker.jobs.value, isEmpty);
        expect(
          settle(async, db.pendingJobsDao.getActive(alice)).single.jobId,
          'j1',
          reason: "alice's row is kept",
        );
      });
    });
  });
}
