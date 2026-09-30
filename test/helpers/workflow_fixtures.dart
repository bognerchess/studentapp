// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/generated/operations/stages.graphql.dart';
import 'package:bogner_chess/core/api/mappers/stage_mapper.dart';
import 'package:bogner_chess/features/analysis_status/domain/workflow_tracker_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_riverpod/misc.dart' show Override;

import 'fixture_link.dart';

export 'package:bogner_chess/features/analysis_status/domain/workflow_tracker_providers.dart'
    show AnalysisStage, AnalysisStageState, AnalysisWorkflow;

/// One of the `GameAnalysisWorkflow` fixtures as the domain model, so that a
/// screen test can stand the pipeline anywhere without a poller.
///
/// [patch] changes the stage list first, for the states the fixtures do not
/// cover on their own (progress numbers, a different failure code).
AnalysisWorkflow workflowFixture(
  FixtureStore store,
  String scenario, {
  void Function(List<Map<String, dynamic>> stages)? patch,
}) {
  final workflow =
      store.data('GameAnalysisWorkflow', scenario)['gameAnalysisWorkflow']
          as Map<String, dynamic>;
  patch?.call((workflow['stages'] as List).cast<Map<String, dynamic>>());
  return workflowOf(Fragment$WorkflowFields.fromJson(workflow));
}

/// What `trackedWorkflowsProvider` holds for the length of a test, instead of
/// the tracker's own polling.
class FixedWorkflows extends TrackedWorkflowsNotifier {
  FixedWorkflows(this._value);

  Map<String, AnalysisWorkflow> _value;

  @override
  Map<String, AnalysisWorkflow> build() => _value;

  /// What a poll would have reported: a stage landed, a stage failed.
  void report(String gameId, AnalysisWorkflow workflow) {
    _value = {..._value, gameId: workflow};
    state = _value;
  }
}

/// The [FixedWorkflows] of a test that passed [tracking].
FixedWorkflows workflowsOf(ProviderContainer container) =>
    container.read(trackedWorkflowsProvider.notifier) as FixedWorkflows;

/// Puts [workflow] under [gameId], the way the tracker would after a poll.
Override tracking(String gameId, AnalysisWorkflow workflow) =>
    trackedWorkflowsProvider.overrideWith(
      () => FixedWorkflows({gameId: workflow}),
    );
