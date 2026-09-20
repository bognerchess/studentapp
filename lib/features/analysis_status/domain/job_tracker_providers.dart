// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:bogner_chess/features/library/domain/games_repository.dart';
import 'package:bogner_chess/features/library/domain/owner.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'job_tracker.dart';
import 'mobile_config_provider.dart';

export 'job_tracker.dart';

/// The one job tracker of the app, wired to the app life cycle and to who is
/// signed in. It lives as long as the process.
///
/// For the push handler: `ref.read(jobTrackerProvider).refreshNow()` when an
/// "analysis ready" notification arrives while the app is open.
final jobTrackerProvider = Provider<JobTracker>((ref) {
  final tracker = JobTracker(
    api: ref.watch(analysisApiProvider),
    db: ref.watch(appDatabaseProvider),
    games: ref.watch(gamesRepositoryProvider),
    baseInterval: () =>
        ref.read(mobileConfigProvider).value?.jobPollInterval ??
        JobTracker.defaultBaseInterval,
  );

  // Visible = the life cycle says resumed and the widget tree is mounted
  // (AnalysisNotices reports that through jobTrackerUiMountedProvider).
  final binding = WidgetsBinding.instance;
  var resumed =
      binding.lifecycleState == null ||
      binding.lifecycleState == AppLifecycleState.resumed;
  void update() =>
      tracker.setForeground(resumed && ref.read(jobTrackerUiMountedProvider));
  update();
  final lifecycle = AppLifecycleListener(
    binding: binding,
    onStateChange: (state) {
      resumed = state == AppLifecycleState.resumed;
      if (resumed && ref.read(mobileConfigProvider).hasError) {
        ref.invalidate(mobileConfigProvider);
      }
      update();
    },
  );
  ref.listen(jobTrackerUiMountedProvider, (_, _) => update());

  ref
    ..onDispose(lifecycle.dispose)
    ..onDispose(tracker.dispose)
    ..listen(currentOwnerProvider, (_, owner) {
      if (owner != null) {
        // Start loading the poll interval; the tracker has a default.
        ref.read(mobileConfigProvider);
      }
      unawaited(tracker.setOwner(owner));
    }, fireImmediately: true);
  return tracker;
});

/// Whether the app's widget tree is mounted. `AnalysisNotices` sets it; the
/// tracker does not poll without it (there is nobody to show anything to).
final jobTrackerUiMountedProvider =
    NotifierProvider<JobTrackerUiMounted, bool>(JobTrackerUiMounted.new);

class JobTrackerUiMounted extends Notifier<bool> {
  @override
  bool build() => false;

  void set({required bool mounted}) {
    // The last report comes from a disposed widget, possibly after the
    // container is gone as well.
    if (ref.mounted) {
      state = mounted;
    }
  }
}

/// The newest job per game id that the tracker knows of.
final trackedJobsProvider =
    NotifierProvider<TrackedJobsNotifier, Map<String, JobInfo>>(
      TrackedJobsNotifier.new,
    );

class TrackedJobsNotifier extends Notifier<Map<String, JobInfo>> {
  @override
  Map<String, JobInfo> build() {
    final jobs = ref.watch(jobTrackerProvider).jobs;
    void update() => state = jobs.value;
    jobs.addListener(update);
    ref.onDispose(() => jobs.removeListener(update));
    return jobs.value;
  }
}

/// The job to show for a game: the tracker's when it is the same or a newer
/// one than [fromServer] (the `latestJob` of a game summary), else that.
JobInfo? newestJob(JobInfo? tracked, JobInfo? fromServer) {
  if (tracked == null || fromServer == null) {
    return tracked ?? fromServer;
  }
  if (tracked.id == fromServer.id) {
    // The same job: a terminal state is final, otherwise trust the tracker.
    return fromServer.status.isTerminal && !tracked.status.isTerminal
        ? fromServer
        : tracked;
  }
  return fromServer.requestedAt.isAfter(tracked.requestedAt)
      ? fromServer
      : tracked;
}
