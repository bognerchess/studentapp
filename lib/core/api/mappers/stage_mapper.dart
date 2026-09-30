// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/generated/operations/stages.graphql.dart';
import 'package:bogner_chess/core/api/generated/schema.graphql.dart';
import 'package:bogner_chess/core/api/mappers/enum_mappers.dart';
import 'package:bogner_chess/core/api/models/stage_models.dart';

// Every switch over a generated enum has a case for `$unknown`, the value the
// generated fromJson gives to anything a newer server may send. A stage or a
// state this build does not know must never stop the pipeline: an unknown
// stage is simply not started, and an unknown state counts as active.

AnalysisStage stageOf(Enum$EngineStage value) => switch (value) {
  Enum$EngineStage.BASE_EVALUATION => AnalysisStage.baseEvaluation,
  Enum$EngineStage.BASE_CLASSIFICATION => AnalysisStage.baseClassification,
  Enum$EngineStage.DEEP_EVALUATION => AnalysisStage.deepEvaluation,
  Enum$EngineStage.COACHING => AnalysisStage.coaching,
  Enum$EngineStage.$unknown => AnalysisStage.unknown,
};

/// Throws an [ArgumentError] for [AnalysisStage.unknown], which is only ever
/// read.
Enum$EngineStage stageToWire(AnalysisStage value) => switch (value) {
  AnalysisStage.baseEvaluation => Enum$EngineStage.BASE_EVALUATION,
  AnalysisStage.baseClassification => Enum$EngineStage.BASE_CLASSIFICATION,
  AnalysisStage.deepEvaluation => Enum$EngineStage.DEEP_EVALUATION,
  AnalysisStage.coaching => Enum$EngineStage.COACHING,
  AnalysisStage.unknown => throw ArgumentError.value(
    value,
    'stage',
    'cannot be sent',
  ),
};

AnalysisStageState stageStateOf(Enum$AnalysisStageState value) =>
    switch (value) {
      Enum$AnalysisStageState.NOT_RUN => AnalysisStageState.notRun,
      Enum$AnalysisStageState.QUEUED => AnalysisStageState.queued,
      Enum$AnalysisStageState.RUNNING => AnalysisStageState.running,
      Enum$AnalysisStageState.READY => AnalysisStageState.ready,
      Enum$AnalysisStageState.STALE => AnalysisStageState.stale,
      Enum$AnalysisStageState.FAILED => AnalysisStageState.failed,
      Enum$AnalysisStageState.$unknown => AnalysisStageState.unknown,
    };

StageRun stageRunOf(Fragment$StageRunFields run) => StageRun(
  id: run.id,
  gameId: run.chessGameId,
  stage: stageOf(run.stage),
  status: jobStatusOf(run.status),
  artifact: StageArtifact.of(run.artifact),
  supersededAt: run.supersededAt,
  finishedAt: run.finishedAt,
  failureCode: run.failureCode,
  failureMessage: run.failureMessage,
);

StageRunSummary stageRunSummaryOf(Fragment$WorkflowRunFields run) =>
    StageRunSummary(
      id: run.id,
      status: jobStatusOf(run.status),
      hasArtifact: run.hasArtifact,
      progressStage: run.progressStage,
      progressDone: run.progressDone,
      progressTotal: run.progressTotal,
      persona: run.persona,
      language: run.language,
      requestedAt: run.requestedAt,
      startedAt: run.startedAt,
      finishedAt: run.finishedAt,
      failureCode: run.failureCode,
      failureMessage: run.failureMessage,
    );

WorkflowStage workflowStageOf(Fragment$WorkflowFields$stages stage) {
  final blockedBy = stage.blockedBy;
  final run = stage.run;
  return WorkflowStage(
    stage: stageOf(stage.stage),
    state: stageStateOf(stage.state),
    runnable: stage.runnable,
    usesModel: stage.usesModel,
    blockedBy: blockedBy == null ? null : stageOf(blockedBy),
    run: run == null ? null : stageRunSummaryOf(run),
  );
}

AnalysisWorkflow workflowOf(Fragment$WorkflowFields workflow) {
  final next = workflow.nextRunnableStage;
  return AnalysisWorkflow(
    gameId: workflow.chessGameId,
    stages: List.unmodifiable(workflow.stages.map(workflowStageOf)),
    nextRunnableStage: next == null ? null : stageOf(next),
    isComplete: workflow.isComplete,
  );
}
