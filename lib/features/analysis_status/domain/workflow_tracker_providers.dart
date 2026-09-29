// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/app_foreground.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:bogner_chess/features/library/domain/games_repository.dart';
import 'package:bogner_chess/features/library/domain/owner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'job_tracker_providers.dart' show jobTrackerUiMountedProvider;
import 'mobile_config_provider.dart';
import 'workflow_tracker.dart';

export 'workflow_tracker.dart';

/// The one workflow tracker of the app, wired to the app life cycle and to
/// who is signed in. It lives as long as the process.
///
/// For the push handler: `ref.read(workflowTrackerProvider).refreshNow()` when
/// an "analysis ready" notification arrives while the app is open.
///
/// It shares `jobTrackerUiMountedProvider` with the tracker it replaces:
/// `AnalysisNotices` reports one mounted widget tree, and both trackers have
/// the same reason to care about it. WP-60 B12 deletes the old tracker and
/// that provider moves here.
final workflowTrackerProvider = Provider<WorkflowTracker>((ref) {
  final tracker = WorkflowTracker(
    api: ref.watch(stageApiProvider),
    analysisApi: ref.watch(analysisApiProvider),
    db: ref.watch(appDatabaseProvider),
    games: ref.watch(gamesRepositoryProvider),
    baseInterval: () =>
        ref.read(mobileConfigProvider).value?.jobPollInterval ??
        WorkflowTracker.defaultBaseInterval,
  );

  // Visible = the life cycle says resumed and the widget tree is mounted.
  var resumed = AppForeground.isForeground;
  void update() =>
      tracker.setForeground(resumed && ref.read(jobTrackerUiMountedProvider));
  update();
  final lifecycle = AppForeground(
    onChanged: (foreground) {
      resumed = foreground;
      if (foreground && ref.read(mobileConfigProvider).hasError) {
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

/// The pipeline of every game the tracker watches, by game id.
///
/// This is what the game detail, the review banner and the library rows read;
/// a game that is not in here has nothing in flight on this device.
final trackedWorkflowsProvider =
    NotifierProvider<TrackedWorkflowsNotifier, Map<String, AnalysisWorkflow>>(
      TrackedWorkflowsNotifier.new,
    );

class TrackedWorkflowsNotifier extends Notifier<Map<String, AnalysisWorkflow>> {
  @override
  Map<String, AnalysisWorkflow> build() {
    final workflows = ref.watch(workflowTrackerProvider).workflows;
    void update() => state = workflows.value;
    workflows.addListener(update);
    ref.onDispose(() => workflows.removeListener(update));
    return workflows.value;
  }
}
