// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Where one run of one stage is. The server folds its internal states into
/// these four; a value this build does not know reads as [unknown] and is
/// treated as still active, so that the poller keeps asking.
///
/// Named after `AnalysisJobStatus`, the enum the schema still calls it, which
/// the stage commands share with the web client's whole-game jobs.
enum JobStatus {
  queued,
  running,
  done,
  failed,
  unknown;

  bool get isTerminal => this == done || this == failed;
  bool get isActive => !isTerminal;
}

/// One stage of the analysis pipeline, in the order they run.
///
/// The three engine stages are free and are chained by the app; only
/// [coaching] calls a model, and it alone is metered and can be refused. A
/// value this build does not know reads as [unknown]; it sorts after
/// everything and is never started.
enum AnalysisStage {
  baseEvaluation('BASE_EVALUATION', 0),
  baseClassification('BASE_CLASSIFICATION', 1),
  deepEvaluation('DEEP_EVALUATION', 2),
  coaching('COACHING', 3),

  /// A stage this build does not know. Shown as nothing and never started.
  unknown(null, 99);

  const AnalysisStage(this.wire, this.order);

  final String? wire;

  /// Position in the pipeline; every stage needs the ones before it.
  final int order;

  /// The one stage that calls a language model.
  bool get usesModel => this == coaching;

  /// A free stage the app may start on its own.
  bool get isEngineStage =>
      this == baseEvaluation ||
      this == baseClassification ||
      this == deepEvaluation;

  static AnalysisStage fromWire(Object? value) {
    if (value is! String) return unknown;
    for (final stage in values) {
      if (stage.wire == value) return stage;
    }
    return unknown;
  }

  /// The engine stages in pipeline order.
  static const List<AnalysisStage> engineStages = [
    baseEvaluation,
    baseClassification,
    deepEvaluation,
  ];

  /// The four stages in pipeline order, without [unknown].
  static const List<AnalysisStage> pipeline = [
    baseEvaluation,
    baseClassification,
    deepEvaluation,
    coaching,
  ];
}

/// Where one stage of one game stands.
///
/// [stale] means the stage finished but what it was computed from has moved
/// on — the moves changed, or an earlier stage ran again. A value this build
/// does not know reads as [unknown] and counts as active, so the tracker
/// keeps polling rather than declaring the pipeline finished.
enum AnalysisStageState {
  notRun('NOT_RUN'),
  queued('QUEUED'),
  running('RUNNING'),
  ready('READY'),
  stale('STALE'),
  failed('FAILED'),
  unknown(null);

  const AnalysisStageState(this.wire);

  final String? wire;

  /// Something is happening, or might be: keep polling.
  bool get isActive => this == queued || this == running || this == unknown;

  static AnalysisStageState fromWire(Object? value) {
    if (value is! String) return unknown;
    for (final state in values) {
      if (state.wire == value) return state;
    }
    return unknown;
  }
}

/// The result of one stage run, exactly as chess-ai produced it.
///
/// Opaque to the API layer: the shape belongs to the analysis contract, and
/// `StageDocumentAssembler` is the one place that reads it.
@immutable
class StageArtifact {
  const StageArtifact(this.json);

  /// The artifact as a decoded JSON object.
  final Map<String, dynamic> json;

  /// The `Any` scalar as it arrives: a decoded object, or the JSON text
  /// should a server ever send it as a string. Null for anything else,
  /// including a run that has not finished.
  static StageArtifact? of(Object? raw) {
    if (raw is Map<String, dynamic>) {
      return StageArtifact(raw);
    }
    if (raw is Map) {
      return StageArtifact(raw.cast<String, dynamic>());
    }
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return StageArtifact(decoded);
        }
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  @override
  String toString() => 'StageArtifact(${json.keys.length} keys)';
}

/// One run of one stage, with its artifact.
@immutable
class StageRun {
  const StageRun({
    required this.id,
    required this.gameId,
    required this.stage,
    required this.status,
    this.artifact,
    this.supersededAt,
    this.finishedAt,
    this.failureCode,
    this.failureMessage,
  });

  final String id;
  final String gameId;
  final AnalysisStage stage;
  final JobStatus status;

  /// Null until the run finishes, and null whenever the run was read from an
  /// operation that does not select the artifact.
  final StageArtifact? artifact;

  /// Set once a newer run of the same stage finished. A superseded run is
  /// history: its artifact still describes older moves.
  final DateTime? supersededAt;

  final DateTime? finishedAt;

  /// A machine-readable reason when [status] is [JobStatus.failed].
  final String? failureCode;
  final String? failureMessage;

  bool get isSuperseded => supersededAt != null;

  @override
  String toString() =>
      'StageRun($id, game $gameId, ${stage.name}, ${status.name}'
      '${failureCode == null ? '' : ', $failureCode'})';
}

/// The run of a stage as the workflow query reports it: no artifact, but the
/// progress the worker reports while it is on it.
@immutable
class StageRunSummary {
  const StageRunSummary({
    required this.id,
    required this.status,
    required this.hasArtifact,
    required this.requestedAt,
    this.progressStage,
    this.progressDone,
    this.progressTotal,
    this.persona,
    this.language,
    this.startedAt,
    this.finishedAt,
    this.failureCode,
    this.failureMessage,
  });

  final String id;
  final JobStatus status;

  /// True once the artifact is stored and can be fetched or fed to the next
  /// stage.
  final bool hasArtifact;

  /// What the worker says it is doing; free text, shown only through a known
  /// mapping. Null unless the run is running.
  final String? progressStage;

  /// Units of the current step that are finished, and how many there are.
  /// Both null unless the worker has reported progress; [progressTotal] can
  /// be 0.
  final int? progressDone;
  final int? progressTotal;

  /// Coach character and language of a coaching run; null on the engine
  /// stages.
  final String? persona;
  final String? language;

  final DateTime requestedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  final String? failureCode;
  final String? failureMessage;

  /// How far the current step is, between 0 and 1; null when the worker has
  /// not said, so the UI shows an indeterminate bar.
  double? get progress {
    final done = progressDone;
    final total = progressTotal;
    if (done == null || total == null || total <= 0) return null;
    return (done / total).clamp(0.0, 1.0);
  }

  @override
  String toString() =>
      'StageRunSummary($id, ${status.name}'
      '${progressDone == null ? '' : ', $progressDone/$progressTotal'})';
}

/// One stage of the pipeline for one game.
@immutable
class WorkflowStage {
  const WorkflowStage({
    required this.stage,
    required this.state,
    required this.runnable,
    required this.usesModel,
    this.blockedBy,
    this.run,
  });

  final AnalysisStage stage;
  final AnalysisStageState state;

  /// True when this stage can be started right now.
  final bool runnable;

  /// The nearest earlier stage that is not ready; null when nothing blocks
  /// this one.
  final AnalysisStage? blockedBy;

  /// The server's own word on whether this stage is metered. The app does not
  /// derive it from [stage], so a pipeline change needs no app release.
  final bool usesModel;

  /// The run this state was read off, or null when the stage never ran.
  final StageRunSummary? run;

  @override
  String toString() => 'WorkflowStage(${stage.name}, ${state.name})';
}

/// The analysis pipeline of one game: the four stages in order, what each one
/// is doing and which one can be started next.
@immutable
class AnalysisWorkflow {
  const AnalysisWorkflow({
    required this.gameId,
    required this.stages,
    required this.isComplete,
    this.nextRunnableStage,
  });

  final String gameId;

  /// The stages in pipeline order, as the server sent them.
  final List<WorkflowStage> stages;

  /// The earliest stage that can be started and is not ready yet. Null when
  /// the pipeline is finished or is waiting on a run.
  final AnalysisStage? nextRunnableStage;

  /// True when all four stages are ready, so the analysis document is stored.
  final bool isComplete;

  WorkflowStage? stageOf(AnalysisStage stage) {
    for (final entry in stages) {
      if (entry.stage == stage) return entry;
    }
    return null;
  }

  /// [AnalysisStageState.notRun] for a stage the server did not report.
  AnalysisStageState stateOf(AnalysisStage stage) =>
      stageOf(stage)?.state ?? AnalysisStageState.notRun;

  /// Whether any stage is queued or running.
  bool get anyActive => stages.any((s) => s.state.isActive);

  /// The stage that is queued or running; the earliest one if somehow there
  /// are several.
  AnalysisStage? get activeStage {
    for (final entry in stages) {
      if (entry.state.isActive) return entry.stage;
    }
    return null;
  }

  /// The earliest stage whose last attempt failed.
  AnalysisStage? get failedStage {
    for (final entry in stages) {
      if (entry.state == AnalysisStageState.failed) return entry.stage;
    }
    return null;
  }

  /// The furthest engine stage that is ready: what the app can already show.
  AnalysisStage? get newestReadyEngineStage {
    AnalysisStage? newest;
    for (final stage in AnalysisStage.engineStages) {
      if (stateOf(stage) == AnalysisStageState.ready) newest = stage;
    }
    return newest;
  }

  /// The deep evaluation is stored, so the app has everything an engine can
  /// give: variations, accuracy and the key moments.
  bool get engineReady =>
      stateOf(AnalysisStage.deepEvaluation) == AnalysisStageState.ready;

  /// The coach has written; the analysis document is on the server.
  bool get coachReady =>
      stateOf(AnalysisStage.coaching) == AnalysisStageState.ready;

  /// The run id of every stage that is ready, by stage. This is what the
  /// tracker compares against what it has already fetched, and what the
  /// review screen listens on to know that something new arrived.
  Map<AnalysisStage, String> get readyRunIds => {
    for (final entry in stages)
      if (entry.state == AnalysisStageState.ready && entry.run != null)
        entry.stage: entry.run!.id,
  };

  @override
  String toString() =>
      'AnalysisWorkflow($gameId, '
      '${stages.map((s) => '${s.stage.name}:${s.state.name}').join(' ')})';
}

/// What the library needs to know about a game's pipeline, small enough to
/// store next to the cached game row.
///
/// Only the states, so a row written by an older build reads back whatever it
/// knew; unknown names read as [AnalysisStageState.unknown].
@immutable
class GameWorkflowSummary {
  const GameWorkflowSummary({required this.states, required this.isComplete});

  factory GameWorkflowSummary.of(AnalysisWorkflow workflow) =>
      GameWorkflowSummary(
        states: {for (final s in workflow.stages) s.stage: s.state},
        isComplete: workflow.isComplete,
      );

  /// Reads a row written by [toJson]. Never throws: damaged content reads as
  /// "nothing known".
  factory GameWorkflowSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['states'];
    return GameWorkflowSummary(
      states: {
        if (raw is Map)
          for (final MapEntry(:key, :value) in raw.entries)
            if (AnalysisStage.fromWire(key) case final stage
                when stage != AnalysisStage.unknown)
              stage: AnalysisStageState.fromWire(value),
      },
      isComplete: json['isComplete'] == true,
    );
  }

  final Map<AnalysisStage, AnalysisStageState> states;
  final bool isComplete;

  AnalysisStageState stateOf(AnalysisStage stage) =>
      states[stage] ?? AnalysisStageState.notRun;

  bool get engineReady =>
      stateOf(AnalysisStage.deepEvaluation) == AnalysisStageState.ready;

  bool get coachReady =>
      stateOf(AnalysisStage.coaching) == AnalysisStageState.ready;

  bool get anyActive => states.values.any((s) => s.isActive);

  AnalysisStage? get failedStage {
    for (final stage in AnalysisStage.pipeline) {
      if (stateOf(stage) == AnalysisStageState.failed) return stage;
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    // Written out rather than built in a collection literal: a stage this
    // build does not know has no wire name and is left out, and a literal of
    // `MapEntry` elements is a *set* of entries, which no JSON encoder takes.
    final wire = <String, String>{};
    for (final MapEntry(:key, :value) in states.entries) {
      final name = key.wire;
      if (name != null) {
        wire[name] = value.wire ?? 'UNKNOWN';
      }
    }
    return {'states': wire, 'isComplete': isComplete};
  }

  @override
  bool operator ==(Object other) =>
      other is GameWorkflowSummary &&
      other.isComplete == isComplete &&
      mapEquals(other.states, states);

  @override
  int get hashCode => Object.hash(isComplete, states.length);

  @override
  String toString() =>
      'GameWorkflowSummary('
      '${states.entries.map((e) => '${e.key.name}:${e.value.name}').join(' ')})';
}
