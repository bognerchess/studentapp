// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:drift/drift.dart';

/// State of an analysis job. Stored by name; see [DraftState] for the rule.
enum JobState {
  queued,
  running,
  done,
  failed;

  /// Whether the poller still has to ask about the job.
  bool get isActive => this == queued || this == running;
}

/// Analysis jobs the poller watches. Persisted so they survive an app kill.
@DataClassName('PendingJob')
@TableIndex(name: 'pending_jobs_owner_state', columns: {#ownerSub, #state})
class PendingJobs extends Table {
  TextColumn get jobId => text()();
  TextColumn get gameId => text()();
  TextColumn get ownerSub => text()();
  TextColumn get state => textEnum<JobState>()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastPolledAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {jobId};
}
