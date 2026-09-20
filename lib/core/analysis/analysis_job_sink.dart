// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/api/models/analysis_models.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where an analysis job goes that somebody other than the job tracker
/// started (the submit queue after "Save & analyse"). The tracker implements
/// this and overrides [analysisJobSinkProvider], so that the job is polled
/// and shown from the moment it exists.
abstract interface class AnalysisJobSink {
  void track(JobInfo job);
}

/// The default: writes the job into `pending_jobs`, which is where a poller
/// that starts later looks first. Without a signed-in user it does nothing.
class PendingJobsAnalysisJobSink implements AnalysisJobSink {
  PendingJobsAnalysisJobSink(this._ref);

  static const _log = Log('job-sink');

  final Ref _ref;

  @override
  void track(JobInfo job) {
    final auth = _ref.read(authStateProvider);
    if (auth is! SignedIn) return;
    final state = switch (job.status) {
      JobStatus.queued || JobStatus.unknown => JobState.queued,
      JobStatus.running => JobState.running,
      JobStatus.done => JobState.done,
      JobStatus.failed => JobState.failed,
    };
    unawaited(
      _ref
          .read(appDatabaseProvider)
          .pendingJobsDao
          .upsert(auth.sub, jobId: job.id, gameId: job.gameId, state: state)
          .catchError((Object error) {
            _log.warning('could not record the job (${error.runtimeType})');
          }),
    );
  }
}

final analysisJobSinkProvider = Provider<AnalysisJobSink>(
  PendingJobsAnalysisJobSink.new,
);
