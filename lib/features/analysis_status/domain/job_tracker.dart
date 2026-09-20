// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/api/analysis_api.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/features/library/domain/games_repository.dart';
import 'package:flutter/foundation.dart';

/// What the tracker tells the rest of the app when a job ends.
@immutable
sealed class JobTrackerEvent {
  const JobTrackerEvent(this.gameId);
  final String gameId;
}

/// The analysis of [gameId] can be opened.
final class AnalysisReadyEvent extends JobTrackerEvent {
  const AnalysisReadyEvent(super.gameId);
}

/// The job of [gameId] failed. The server has refunded it.
final class AnalysisFailedEvent extends JobTrackerEvent {
  const AnalysisFailedEvent(super.gameId, {this.failureCode});
  final String? failureCode;
}

/// Follows the user's analysis jobs until they end (AN-1).
///
/// One poller for all jobs: a single `myActiveAnalysisJobs` query per tick,
/// plus one `analysisJob` query for each job that has left that list, to
/// learn whether it is done or failed. The first tick comes after
/// [baseInterval]; every further one waits 1.5 times longer, up to
/// [maxInterval]. It only runs while the app is in the foreground with its
/// UI mounted ([setForeground]), somebody is signed in and at least one job
/// is active. A resume, a newly tracked
/// job and [refreshNow] (a push notification) poll at once and start the
/// interval again.
///
/// Job ids are kept in `pending_jobs`, so tracking survives an app kill: on
/// start ([setOwner]) the table is read and then reconciled with the
/// server's list, which also adopts jobs requested elsewhere (the web
/// client). The table is also watched while the tracker runs, which is how
/// a job the submit queue just created (through `AnalysisJobSink`) is
/// picked up the moment it exists.
///
/// When a job is done the analysis is fetched once into `cached_analyses`
/// and the library copy of the game gets its new badge, so the review opens
/// without a wait; then an [AnalysisReadyEvent] goes out.
class JobTracker {
  JobTracker({
    required this._api,
    required this._db,
    required this._games,
    Duration Function()? baseInterval,
  }) : _baseInterval = baseInterval ?? (() => defaultBaseInterval);

  static const Duration defaultBaseInterval = Duration(seconds: 3);
  static const Duration maxInterval = Duration(seconds: 30);
  static const double backoffFactor = 1.5;

  static const _log = Log('jobs');

  final AnalysisApi _api;
  final AppDatabase _db;
  final GamesRepository _games;
  final Duration Function() _baseInterval;

  final ValueNotifier<Map<String, JobInfo>> _jobs = ValueNotifier(const {});
  final StreamController<JobTrackerEvent> _events =
      StreamController.broadcast();

  /// Job id to game id, for the jobs that are queued or running.
  final Map<String, String> _active = {};

  StreamSubscription<List<PendingJob>>? _rows;
  String? _owner;
  bool _foreground = true;
  bool _disposed = false;
  Timer? _timer;
  Duration? _interval;
  Future<void>? _polling;
  bool _pollAgain = false;

  /// The newest job the tracker knows of, by game id: active ones and those
  /// that ended in this session.
  ValueListenable<Map<String, JobInfo>> get jobs => _jobs;

  /// Jobs that ended while the tracker was watching. Broadcast, no replay.
  Stream<JobTrackerEvent> get events => _events.stream;

  /// The wait before the next poll; null while the poller is idle.
  @visibleForTesting
  Duration? get currentInterval => _timer == null ? null : _interval;

  bool get hasActiveJobs => _active.isNotEmpty;

  /// Who is signed in (null: nobody). Forgets the previous account's jobs,
  /// reads the persisted ones of the new account and reconciles them with
  /// the server.
  Future<void> setOwner(String? owner) async {
    if (_disposed || owner == _owner) {
      return;
    }
    _owner = owner;
    _stopTimer();
    unawaited(_rows?.cancel());
    _rows = null;
    _active.clear();
    _jobs.value = const {};
    if (owner == null) {
      return;
    }
    try {
      await _db.pendingJobsDao.removeFinished(owner);
      final rows = await _db.pendingJobsDao.getActive(owner);
      if (_disposed || owner != _owner) {
        return;
      }
      for (final row in rows) {
        _active[row.jobId] = row.gameId;
        // Details (stage, queue position) come with the first poll.
        _setJob(
          JobInfo(
            id: row.jobId,
            gameId: row.gameId,
            status: row.state == JobState.queued
                ? JobStatus.queued
                : JobStatus.running,
            requestedAt: row.createdAt.toUtc(),
          ),
        );
      }
      _rows = _db.pendingJobsDao
          .watchActive(owner)
          .listen((rows) => _adopt(owner, rows));
    } on Object catch (e, s) {
      _warn('reading persisted jobs failed', e, s);
    }
    await refreshNow();
  }

  /// Rows somebody else wrote (the submit queue's `AnalysisJobSink`, after
  /// "Save & analyse"): follow them from now on. What the tracker wrote
  /// itself is already known and ignored here.
  void _adopt(String owner, List<PendingJob> rows) {
    if (_disposed || owner != _owner) {
      return;
    }
    var added = false;
    for (final row in rows) {
      if (_active.containsKey(row.jobId)) {
        continue;
      }
      _active[row.jobId] = row.gameId;
      _setJob(
        JobInfo(
          id: row.jobId,
          gameId: row.gameId,
          status: row.state == JobState.queued
              ? JobStatus.queued
              : JobStatus.running,
          requestedAt: row.createdAt.toUtc(),
        ),
      );
      added = true;
    }
    if (added) {
      // Ask the server about it now, and keep asking.
      unawaited(refreshNow());
    }
  }

  /// Whether the app is visible: in the foreground, with its widget tree
  /// mounted. Coming back polls at once.
  void setForeground(bool value) {
    if (_disposed || value == _foreground) {
      return;
    }
    _foreground = value;
    if (value) {
      unawaited(refreshNow());
    } else {
      _stopTimer();
    }
  }

  /// Starts following [job], the answer of an accepted analysis request.
  Future<void> track(JobInfo job) async {
    final owner = _owner;
    if (_disposed || owner == null) {
      return;
    }
    if (job.status.isTerminal) {
      await _finish(owner, job);
      return;
    }
    _active[job.id] = job.gameId;
    _setJob(job);
    try {
      await _db.pendingJobsDao.upsert(
        owner,
        jobId: job.id,
        gameId: job.gameId,
        state: _stateOf(job.status),
      );
      await _games.applyJob(owner, job);
    } on Object catch (e, s) {
      _warn('persisting a job failed', e, s);
    }
    _restartTimer();
  }

  /// Polls now and starts the interval again. Called on resume, by the push
  /// handler when an "analysis ready" notification arrives, and by
  /// pull-to-refresh. Does nothing while the app is in the background or
  /// nobody is signed in. Never throws.
  Future<void> refreshNow() {
    if (_disposed || !_foreground || _owner == null) {
      return Future.value();
    }
    _stopTimer();
    return _poll().whenComplete(_restartTimer);
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _stopTimer();
    unawaited(_rows?.cancel());
    _jobs.dispose();
    unawaited(_events.close());
  }

  // ---- The poller ----

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _restartTimer() {
    _interval = null;
    _schedule();
  }

  void _schedule() {
    _stopTimer();
    if (_disposed || !_foreground || _owner == null || _active.isEmpty) {
      return;
    }
    final previous = _interval;
    final next = previous == null ? _baseInterval() : previous * backoffFactor;
    final wait = next > maxInterval ? maxInterval : next;
    _interval = wait;
    _timer = Timer(wait, () async {
      _timer = null;
      await _poll();
      // Unless somebody (refreshNow, track) has scheduled the next one.
      if (_timer == null) {
        _schedule();
      }
    });
  }

  /// One poll at a time. A request that arrives during a poll makes it run
  /// once more, because the running one may have asked before the change.
  Future<void> _poll() {
    final running = _polling;
    if (running != null) {
      _pollAgain = true;
      return running;
    }
    final done = () async {
      do {
        _pollAgain = false;
        await _pollOnce();
      } while (_pollAgain && !_disposed);
    }();
    _polling = done;
    return done.whenComplete(() => _polling = null);
  }

  Future<void> _pollOnce() async {
    final owner = _owner;
    if (_disposed || owner == null) {
      return;
    }
    try {
      final List<JobInfo> active;
      try {
        active = await _api.activeJobs();
      } on ApiError catch (e) {
        _log.debug('poll failed: $e');
        return;
      }
      if (_disposed || owner != _owner) {
        return;
      }
      final activeIds = <String>{};
      for (final job in active) {
        activeIds.add(job.id);
        final isNew = !_active.containsKey(job.id);
        final changed = _jobs.value[job.gameId] != job;
        _active[job.id] = job.gameId;
        _setJob(job);
        if (isNew || changed) {
          await _db.pendingJobsDao.upsert(
            owner,
            jobId: job.id,
            gameId: job.gameId,
            state: _stateOf(job.status),
          );
          await _games.applyJob(owner, job);
        }
      }
      // Jobs that left the list are done or failed (or gone with the game).
      final left = [
        for (final id in _active.keys)
          if (!activeIds.contains(id)) id,
      ];
      for (final jobId in left) {
        final JobInfo? job;
        try {
          job = await _api.job(jobId);
        } on ApiError catch (e) {
          _log.debug('job lookup failed: $e');
          continue; // Asked again with the next poll.
        }
        if (_disposed || owner != _owner) {
          return;
        }
        if (job == null) {
          final gameId = _active.remove(jobId);
          await _db.pendingJobsDao.remove(owner, jobId);
          if (gameId != null && _jobs.value[gameId]?.id == jobId) {
            _jobs.value = {..._jobs.value}..remove(gameId);
          }
        } else if (job.status.isActive) {
          _setJob(job); // It ended up in the list between the two queries.
        } else {
          await _finish(owner, job);
        }
      }
      if (_active.isNotEmpty) {
        await _db.pendingJobsDao.markPolled(owner, _active.keys);
      }
    } on Object catch (e, s) {
      _warn('poll failed', e, s);
    }
  }

  Future<void> _finish(String owner, JobInfo job) async {
    _active.remove(job.id);
    final done = job.status == JobStatus.done;
    if (done) {
      // Fetched here once, so that the review opens from the cache. When it
      // fails the review screen fetches it itself.
      try {
        final analysis = await _api.analysis(job.gameId);
        if (analysis != null && !_disposed) {
          await _db.analysisCacheDao.put(
            owner,
            job.gameId,
            schemaVersion: analysis.schemaVersion,
            schemaMinor: analysis.schemaMinor,
            payload: analysis.rawJson,
          );
        }
      } on ApiError catch (e) {
        _log.debug('fetching the finished analysis failed: $e');
      }
    }
    if (_disposed || owner != _owner) {
      return;
    }
    await _db.pendingJobsDao.upsert(
      owner,
      jobId: job.id,
      gameId: job.gameId,
      state: done ? JobState.done : JobState.failed,
    );
    await _games.applyJob(owner, job, hasAnalysis: done ? true : null);
    _setJob(job);
    if (!_events.isClosed) {
      _events.add(
        done
            ? AnalysisReadyEvent(job.gameId)
            : AnalysisFailedEvent(job.gameId, failureCode: job.failureCode),
      );
    }
  }

  void _setJob(JobInfo job) {
    if (_disposed) {
      return;
    }
    final known = _jobs.value[job.gameId];
    // An older job of the same game never replaces a newer one.
    if (known != null &&
        known.id != job.id &&
        known.requestedAt.isAfter(job.requestedAt)) {
      return;
    }
    if (known != job) {
      _jobs.value = {..._jobs.value, job.gameId: job};
    }
  }

  void _warn(String message, Object error, StackTrace stack) {
    // A closed database after dispose is the end of the app or of a test.
    if (!_disposed) {
      _log.warning(message, error: error, stackTrace: stack);
    }
  }

  static JobState _stateOf(JobStatus status) => switch (status) {
    JobStatus.queued => JobState.queued,
    JobStatus.running || JobStatus.unknown => JobState.running,
    JobStatus.done => JobState.done,
    JobStatus.failed => JobState.failed,
  };
}
