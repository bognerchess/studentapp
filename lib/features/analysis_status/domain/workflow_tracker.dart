// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:convert';

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/analysis/stage_document_assembler.dart';
import 'package:bogner_chess/core/api/analysis_api.dart' show AnalysisApi;
import 'package:bogner_chess/core/api/stage_api.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/features/library/domain/games_repository.dart';
import 'package:flutter/foundation.dart';

// The tracker's public surface is made of these; a feature that reads
// `workflows` needs them without reaching into lib/core/api itself.
export 'package:bogner_chess/core/api/models/stage_models.dart';

/// What the tracker tells the rest of the app while a pipeline runs.
@immutable
sealed class WorkflowEvent {
  const WorkflowEvent(this.gameId);
  final String gameId;
}

/// A stage of [gameId] is stored and its result can be shown.
final class StageReadyEvent extends WorkflowEvent {
  const StageReadyEvent(super.gameId, this.stage);
  final AnalysisStage stage;

  @override
  String toString() => 'StageReadyEvent($gameId, ${stage.name})';
}

/// A stage of [gameId] failed. Running it again is the way forward; a
/// coaching stage that failed was refunded by the server.
final class StageFailedEvent extends WorkflowEvent {
  const StageFailedEvent(super.gameId, this.stage, {this.failureCode});
  final AnalysisStage stage;
  final String? failureCode;

  @override
  String toString() => 'StageFailedEvent($gameId, ${stage.name}, $failureCode)';
}

/// What was computed for [gameId] describes moves that have since changed.
/// The chain stops; the user decides whether to analyse again.
final class WorkflowStaleEvent extends WorkflowEvent {
  const WorkflowStaleEvent(super.gameId);

  @override
  String toString() => 'WorkflowStaleEvent($gameId)';
}

/// Drives and follows the staged analysis of the user's games.
///
/// One `gameAnalysisWorkflow` query per tracked game per tick — the pipeline
/// is per game and the server has no "my running workflows" field, so the
/// games to ask about come from `pending_workflows`. The first tick comes
/// after [defaultBaseInterval] (or what `mobileConfig` says); every further
/// one waits [backoffFactor] times longer, up to [maxInterval]. It only runs
/// while the app is in the foreground with its UI mounted ([setForeground]),
/// somebody is signed in and at least one game is tracked. A resume, a newly
/// tracked game and [refreshNow] poll at once and start the interval again.
///
/// Per tick, for each tracked game:
///
/// 1. A workflow that comes back null (the game is gone, or was never this
///    user's) is forgotten and its row deleted.
/// 2. Every stage whose state changed emits an event, and the new states are
///    written next to the cached game for the library badge.
/// 3. The artifact of a stage that just became ready is fetched **once**, by
///    run id: the ids it has already read are in `cached_analyses.stage_run_ids`.
///    When the deep evaluation is ready only that one is fetched — it contains
///    everything stages 1 and 2 would have said — and all three ids are
///    recorded as read. A late stage 2 on its own only patches the critical
///    plies into the stored document, which is why stage 2's artifact is worth
///    fetching at all: it is a handful of ply numbers.
/// 4. A ready coaching stage is the server's own document, fetched with
///    `AnalysisApi.analysis` and stored as the coach row; a coaching stage
///    that went stale drops that row, so the engine assembly shows again
///    rather than text written about other moves.
/// 5. **The chain.** With nothing in flight, the next runnable stage is
///    started, as long as it is an engine stage no further than the target.
///    The tracker never starts the coaching stage: that one costs the user
///    quota and is always a decision of theirs.
/// 6. It stops when the target is stored, when a stage up to the target
///    failed, or when what the pipeline was computed from has moved on. A
///    [startChain] on such a game is the user asking anyway, and gets one
///    attempt at whatever the server says is runnable.
class WorkflowTracker {
  WorkflowTracker({
    required StageApi api,
    required AnalysisApi analysisApi,
    required AppDatabase db,
    required GamesRepository games,
    Duration Function()? baseInterval,
  }) : this._(api, analysisApi, db, games, baseInterval);

  WorkflowTracker._(
    this._api,
    this._analysisApi,
    this._db,
    this._games,
    Duration Function()? baseInterval,
  ) : _baseInterval = baseInterval ?? (() => defaultBaseInterval);

  static const Duration defaultBaseInterval = Duration(seconds: 3);
  static const Duration maxInterval = Duration(seconds: 30);
  static const double backoffFactor = 1.5;

  /// How far a plain "Analyse this game" runs: the three free engine stages.
  static const AnalysisStage defaultTarget = AnalysisStage.deepEvaluation;

  static const _log = Log('workflows');

  final StageApi _api;
  final AnalysisApi _analysisApi;
  final AppDatabase _db;
  final GamesRepository _games;
  final Duration Function() _baseInterval;

  final ValueNotifier<Map<String, AnalysisWorkflow>> _workflows = ValueNotifier(
    const {},
  );
  final StreamController<WorkflowEvent> _events = StreamController.broadcast();

  /// The games being watched, and how far each one should run.
  final Map<String, AnalysisStage> _targets = {};

  /// Games with a stage mutation in flight; a second tick must not fire the
  /// same stage again.
  final Set<String> _starting = {};

  /// What the last stage command of a game answered, kept only until
  /// [startChain] returns it. This is how the screen that asked gets to
  /// explain a refusal, even though it is the poll that fires the mutation.
  final Map<String, RequestAnalysisOutcome> _outcomes = {};

  /// Games the user has just asked for again, read and cleared by the next
  /// tick. It is what separates "run this failed stage once more, because
  /// somebody tapped the button" from "the pipeline is stuck, stop".
  final Set<String> _restarted = {};

  StreamSubscription<List<PendingWorkflow>>? _rows;
  String? _owner;
  bool _foreground = true;
  bool _disposed = false;
  Timer? _timer;
  Duration? _interval;

  /// A wait the server asked for (a rate-limited stage command), honoured on
  /// the next schedule and then forgotten.
  Duration? _floor;

  Future<void>? _polling;
  bool _pollAgain = false;

  /// The pipeline of every watched game, as of the last poll.
  ValueListenable<Map<String, AnalysisWorkflow>> get workflows => _workflows;

  /// What happened while the tracker was watching. Broadcast, no replay.
  Stream<WorkflowEvent> get events => _events.stream;

  /// The wait before the next poll; null while the poller is idle.
  @visibleForTesting
  Duration? get currentInterval => _timer == null ? null : _interval;

  bool get hasActiveWorkflows => _targets.isNotEmpty;

  /// The games being watched, for a test and for a status line.
  @visibleForTesting
  Set<String> get trackedGames => Set.unmodifiable(_targets.keys);

  /// Who is signed in (null: nobody). Forgets the previous account, reads the
  /// games the new one has in flight and asks the server about them, which is
  /// what makes the chain survive an app kill.
  Future<void> setOwner(String? owner) async {
    if (_disposed || owner == _owner) {
      return;
    }
    _owner = owner;
    _stopTimer();
    unawaited(_rows?.cancel());
    _rows = null;
    _targets.clear();
    _starting.clear();
    _outcomes.clear();
    _restarted.clear();
    _workflows.value = const {};
    if (owner == null) {
      return;
    }
    try {
      await _db.pendingWorkflowsDao.removeFinished(owner);
      final rows = await _db.pendingWorkflowsDao.getActive(owner);
      if (_disposed || owner != _owner) {
        return;
      }
      _adopt(owner, rows);
      _rows = _db.pendingWorkflowsDao
          .watchActive(owner)
          .listen((rows) => _adopt(owner, rows));
    } on Object catch (e, s) {
      _warn('reading the games in flight failed', e, s);
    }
    await refreshNow();
  }

  /// Rows somebody else wrote — the submit queue after "Save & analyse", or
  /// this tracker in an earlier session. What is already watched is ignored.
  void _adopt(String owner, List<PendingWorkflow> rows) {
    if (_disposed || owner != _owner) {
      return;
    }
    var added = false;
    for (final row in rows) {
      final target = AnalysisStage.fromWire(row.targetStage);
      // A target this build does not know: watch the game as far as the free
      // stages go rather than not at all.
      final wanted = target == AnalysisStage.unknown ? defaultTarget : target;
      if (_targets[row.gameId] == wanted) {
        continue;
      }
      _targets[row.gameId] = wanted;
      added = true;
    }
    if (added) {
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

  /// Runs the analysis of [gameId] up to [target] — by default the three free
  /// engine stages — and follows it.
  ///
  /// The `pending_workflows` row is written **before** anything is started, so
  /// an app that is killed in between resumes the chain on the next start. The
  /// first stage is then started by the poll that follows, which is the one
  /// place that decides which stage is next: on a game whose base evaluation
  /// is already stored this starts the classification, not the evaluation
  /// again.
  ///
  /// This is also the retry. A stage whose last attempt failed, and a stage
  /// whose input moved on, are both runnable as far as the server is
  /// concerned; the tracker refuses to run them on its own but does so once
  /// when asked here.
  /// Returns what the server said about the stage the poll then started, so
  /// that the screen which asked can explain a refusal. Null when nothing was
  /// started — the poller is idle because the app is in the background, or
  /// there was nothing left to run.
  Future<RequestAnalysisOutcome?> startChain(
    String gameId, {
    AnalysisStage target = defaultTarget,
  }) async {
    final owner = _owner;
    if (_disposed || owner == null || target == AnalysisStage.unknown) {
      return null;
    }
    _targets[gameId] = target;
    _outcomes.remove(gameId);
    _restarted.add(gameId);
    try {
      await _db.pendingWorkflowsDao.upsert(
        owner,
        gameId: gameId,
        targetStage: target.wire!,
      );
    } on Object catch (e, s) {
      _warn('recording a workflow failed', e, s);
    }
    await refreshNow();
    return _outcomes.remove(gameId);
  }

  /// Follows the coaching stage of [gameId], after the user asked for it and
  /// the server accepted [run]. The tracker never starts this stage itself.
  Future<void> trackCoaching(String gameId, StageRun run) async {
    await startChain(gameId, target: AnalysisStage.coaching);
  }

  /// Polls now and starts the interval again. Called on resume, by the push
  /// handler and by pull-to-refresh. Does nothing while the app is in the
  /// background or nobody is signed in. Never throws.
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
    _workflows.dispose();
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
    if (_disposed || !_foreground || _owner == null || _targets.isEmpty) {
      return;
    }
    final previous = _interval;
    final next = previous == null ? _baseInterval() : previous * backoffFactor;
    var wait = next > maxInterval ? maxInterval : next;
    // A rate-limited command said how long to wait; that wins over the
    // cadence, once.
    final floor = _floor;
    if (floor != null) {
      if (floor > wait) {
        wait = floor;
      }
      _floor = null;
    }
    _interval = wait;
    _timer = Timer(wait, () async {
      _timer = null;
      await _poll();
      // Unless somebody (refreshNow, startChain) has scheduled the next one.
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
    if (_disposed || owner == null || _targets.isEmpty) {
      return;
    }
    for (final gameId in _targets.keys.toList()) {
      if (_disposed || owner != _owner) {
        return;
      }
      try {
        await _tick(owner, gameId);
      } on Object catch (e, s) {
        _warn('following $gameId failed', e, s);
      }
    }
    final watched = _targets.keys.toList();
    if (watched.isNotEmpty) {
      try {
        await _db.pendingWorkflowsDao.markPolled(owner, watched);
      } on Object catch (e, s) {
        _warn('stamping the poll time failed', e, s);
      }
    }
  }

  Future<void> _tick(String owner, String gameId) async {
    final target = _targets[gameId];
    if (target == null) {
      return;
    }
    // Read once per tick: this is the one tick that may run a stage whose
    // last attempt failed, or whose input has moved on.
    final restarted = _restarted.remove(gameId);

    final AnalysisWorkflow? workflow;
    try {
      workflow = await _api.workflow(gameId);
    } on ApiError catch (e) {
      // Offline, or a server that is having a bad minute: ask again later.
      _log.debug('polling $gameId failed: $e');
      return;
    }
    if (_disposed || owner != _owner || !_targets.containsKey(gameId)) {
      return;
    }
    if (workflow == null) {
      // The game is gone, or never was this user's.
      await _untrack(owner, gameId, remove: true);
      return;
    }

    _emitChanges(gameId, workflow);
    final previous = _workflows.value[gameId];
    _workflows.value = {..._workflows.value, gameId: workflow};
    await _rememberSummary(owner, gameId, previous, workflow);
    if (_disposed || owner != _owner) {
      return;
    }

    await _storeArtifacts(owner, gameId, workflow);
    await _followCoaching(owner, gameId, workflow);

    if (_disposed || owner != _owner) {
      return;
    }

    // Terminal, in the order that decides what the user is told.
    if (workflow.stateOf(target) == AnalysisStageState.ready) {
      await _untrack(owner, gameId, state: WorkflowState.done);
      return;
    }
    final failed = workflow.failedStage;
    final blockedByFailure = failed != null && failed.order <= target.order;
    final stale = _staleStageUpTo(workflow, target);
    final blocked = blockedByFailure || stale != null;

    // A pipeline that failed or went stale does not carry on by itself: the
    // server reports the stage as runnable, and running it would re-analyse
    // behind the user's back. [startChain] is the user saying otherwise, so
    // that tick gets one attempt at whatever is runnable.
    if (blocked && !restarted) {
      await _stop(owner, gameId, staleStage: blockedByFailure ? null : stale);
      return;
    }

    final started = await _chain(owner, gameId, workflow, target);
    if (_disposed || owner != _owner) {
      return;
    }
    if (blocked && !started) {
      // Asked again, but there is nothing left to run.
      await _stop(owner, gameId, staleStage: blockedByFailure ? null : stale);
    }
  }

  /// Stops watching [gameId] for the user to act on. A pipeline whose input
  /// moved on says so; a failed stage speaks through its own event.
  Future<void> _stop(
    String owner,
    String gameId, {
    AnalysisStage? staleStage,
  }) async {
    if (staleStage != null) {
      _emit(WorkflowStaleEvent(gameId));
    }
    await _untrack(owner, gameId, state: WorkflowState.failed);
  }

  /// Writes the pipeline next to the cached game whenever it changed, so that
  /// the library badge and the game screen show where it stands after a
  /// restart — the server's game list carries no workflow.
  Future<void> _rememberSummary(
    String owner,
    String gameId,
    AnalysisWorkflow? previous,
    AnalysisWorkflow workflow,
  ) async {
    final summary = GameWorkflowSummary.of(workflow);
    if (previous != null && GameWorkflowSummary.of(previous) == summary) {
      return;
    }
    try {
      await _games.applyWorkflow(owner, gameId, summary);
    } on Object catch (e, s) {
      _warn('storing the pipeline of $gameId failed', e, s);
    }
  }

  /// One event per stage whose state changed since the last poll. The first
  /// poll of a game says nothing: the user has just asked for it, and a game
  /// whose analysis was finished long ago would otherwise announce itself.
  void _emitChanges(String gameId, AnalysisWorkflow workflow) {
    final previous = _workflows.value[gameId];
    if (previous == null) {
      return;
    }
    for (final stage in workflow.stages) {
      final before = previous.stateOf(stage.stage);
      if (before == stage.state) {
        continue;
      }
      switch (stage.state) {
        case AnalysisStageState.ready:
          _emit(StageReadyEvent(gameId, stage.stage));
        case AnalysisStageState.failed:
          _emit(
            StageFailedEvent(
              gameId,
              stage.stage,
              failureCode: stage.run?.failureCode,
            ),
          );
        case AnalysisStageState.notRun:
        case AnalysisStageState.queued:
        case AnalysisStageState.running:
        case AnalysisStageState.stale:
        case AnalysisStageState.unknown:
          break;
      }
    }
  }

  AnalysisStage? _staleStageUpTo(
    AnalysisWorkflow workflow,
    AnalysisStage target,
  ) {
    for (final stage in AnalysisStage.pipeline) {
      if (stage.order > target.order) break;
      if (workflow.stateOf(stage) == AnalysisStageState.stale) return stage;
    }
    return null;
  }

  // ---- Artifacts ----

  /// Fetches what is ready and not read yet, and stores the document it makes.
  Future<void> _storeArtifacts(
    String owner,
    String gameId,
    AnalysisWorkflow workflow,
  ) async {
    // A ready coaching stage means the server has the whole document. Building
    // one out of the engine artifacts would cost a fetch of hundreds of
    // kilobytes and be replaced by `_followCoaching` in the same tick.
    if (workflow.coachReady) {
      return;
    }
    final ready = workflow.readyRunIds;
    final stored = await _db.analysisCacheDao.get(owner, gameId);
    if (_disposed || owner != _owner) {
      return;
    }
    // A coach document is better than anything assembled here; leave it.
    if (stored != null && stored.source == AnalysisSource.coach) {
      return;
    }
    final known = _runIdsOf(stored);

    final deepId = ready[AnalysisStage.deepEvaluation];
    if (deepId != null && known[AnalysisStage.deepEvaluation] != deepId) {
      // Stage 3 says everything stages 1 and 2 would have said, so the other
      // two are marked read without being fetched.
      final deep = await _artifactOf(deepId);
      if (deep == null || _disposed || owner != _owner) return;
      await _writeAssembly(
        owner,
        gameId,
        document: StageDocumentAssembler.build(deep: deep, analysisId: deepId),
        stage: AnalysisStage.deepEvaluation,
        runIds: {
          for (final MapEntry(:key, :value) in ready.entries)
            if (key.isEngineStage) key: value,
          AnalysisStage.deepEvaluation: deepId,
        },
      );
      return;
    }

    final baseId = ready[AnalysisStage.baseEvaluation];
    if (baseId != null && known[AnalysisStage.baseEvaluation] != baseId) {
      final base = await _artifactOf(baseId);
      if (base == null || _disposed || owner != _owner) return;
      final classificationId = ready[AnalysisStage.baseClassification];
      var plies = const <int>{};
      if (classificationId != null) {
        final classification = await _artifactOf(classificationId);
        if (_disposed || owner != _owner) return;
        if (classification != null) {
          plies = StageDocumentAssembler.criticalPliesOf(classification);
        }
      }
      await _writeAssembly(
        owner,
        gameId,
        document: StageDocumentAssembler.build(
          base: base,
          criticalPlies: plies,
          analysisId: baseId,
        ),
        stage: AnalysisStage.baseEvaluation,
        runIds: {
          AnalysisStage.baseEvaluation: baseId,
          if (classificationId != null && plies.isNotEmpty)
            AnalysisStage.baseClassification: classificationId,
        },
      );
      return;
    }

    // Stage 2 landed on its own, after a document was already stored: its
    // artifact is a handful of ply numbers, so patch rather than rebuild.
    final classificationId = ready[AnalysisStage.baseClassification];
    if (stored != null &&
        classificationId != null &&
        known[AnalysisStage.baseClassification] != classificationId) {
      final classification = await _artifactOf(classificationId);
      if (classification == null || _disposed || owner != _owner) return;
      final document = _decode(stored.payload);
      if (document == null) return;
      StageDocumentAssembler.withCriticalPlies(
        document,
        StageDocumentAssembler.criticalPliesOf(classification),
      );
      await _writeAssembly(
        owner,
        gameId,
        document: document,
        stage: AnalysisStage.fromWire(stored.stage),
        runIds: {...known, AnalysisStage.baseClassification: classificationId},
      );
    }
  }

  Future<Map<String, dynamic>?> _artifactOf(String runId) async {
    try {
      final run = await _api.artifact(runId);
      return run?.artifact?.json;
    } on ApiError catch (e) {
      // The next poll asks again; nothing is recorded as read.
      _log.debug('fetching artifact $runId failed: $e');
      return null;
    }
  }

  /// Stores [document] as the engine assembly of [gameId], if the parser can
  /// read it. An assembly the parser rejects is a bug on either side; storing
  /// it would only give the review screen something it cannot show.
  Future<void> _writeAssembly(
    String owner,
    String gameId, {
    required Map<String, dynamic> document,
    required AnalysisStage stage,
    required Map<AnalysisStage, String> runIds,
  }) async {
    final parsed = AnalysisParser.parse(document);
    if (parsed is! AnalysisSupported) {
      _log.warning('the assembled document of $gameId is not readable');
      return;
    }
    final written = await _db.analysisCacheDao.putEngine(
      owner,
      gameId,
      schemaVersion: parsed.document.schemaVersion,
      schemaMinor: parsed.document.schemaMinor,
      payload: jsonEncode(document),
      stage: stage.wire ?? '',
      stageRunIds: jsonEncode(_wireIds(runIds)),
    );
    if (written) {
      await _games.applyAnalysis(owner, gameId, hasAnalysis: true);
    }
  }

  /// The run ids by wire stage name, which is what the column holds. A stage
  /// this build does not know has no wire name and is left out.
  static Map<String, String> _wireIds(Map<AnalysisStage, String> runIds) {
    final ids = <String, String>{};
    for (final MapEntry(:key, :value) in runIds.entries) {
      final wire = key.wire;
      if (wire != null) {
        ids[wire] = value;
      }
    }
    return ids;
  }

  // ---- The coach's document ----

  Future<void> _followCoaching(
    String owner,
    String gameId,
    AnalysisWorkflow workflow,
  ) async {
    switch (workflow.stateOf(AnalysisStage.coaching)) {
      case AnalysisStageState.ready:
        final runId = workflow.readyRunIds[AnalysisStage.coaching];
        final stored = await _db.analysisCacheDao.get(owner, gameId);
        if (_disposed || owner != _owner) return;
        if (stored != null &&
            stored.source == AnalysisSource.coach &&
            (runId == null ||
                _runIdsOf(stored)[AnalysisStage.coaching] == runId)) {
          // Already fetched, and the coach has not written again since.
          return;
        }
        try {
          final analysis = await _analysisApi.analysis(gameId);
          if (analysis == null || _disposed || owner != _owner) return;
          await _db.analysisCacheDao.putCoach(
            owner,
            gameId,
            schemaVersion: analysis.schemaVersion,
            schemaMinor: analysis.schemaMinor,
            payload: analysis.rawJson,
            stageRunIds: runId == null
                ? null
                : jsonEncode(_wireIds({AnalysisStage.coaching: runId})),
          );
          await _games.applyAnalysis(owner, gameId, hasAnalysis: true);
        } on ApiError catch (e) {
          _log.debug('fetching the coach document of $gameId failed: $e');
        }
      case AnalysisStageState.stale:
        // The text was written about moves that have since changed. Dropping
        // it lets the engine assembly show instead, which is at least about
        // this game.
        await _db.analysisCacheDao.clearCoach(owner, gameId);
      case AnalysisStageState.notRun:
      case AnalysisStageState.queued:
      case AnalysisStageState.running:
      case AnalysisStageState.failed:
      case AnalysisStageState.unknown:
        break;
    }
  }

  // ---- The chain ----

  /// Returns whether a stage command went out.
  Future<bool> _chain(
    String owner,
    String gameId,
    AnalysisWorkflow workflow,
    AnalysisStage target,
  ) async {
    if (workflow.anyActive || _starting.contains(gameId)) {
      return false;
    }
    final next = workflow.nextRunnableStage;
    if (next == null ||
        !next.isEngineStage ||
        next.order > target.order ||
        !(workflow.stageOf(next)?.runnable ?? false)) {
      return false;
    }
    _starting.add(gameId);
    final RequestAnalysisOutcome outcome;
    try {
      outcome = await switch (next) {
        AnalysisStage.baseEvaluation => _api.runBaseEvaluation(gameId),
        AnalysisStage.baseClassification => _api.runBaseClassification(gameId),
        _ => _api.runDeepEvaluation(gameId),
      };
    } finally {
      _starting.remove(gameId);
    }
    if (_disposed || owner != _owner || !_targets.containsKey(gameId)) {
      return true;
    }
    _outcomes[gameId] = outcome;
    switch (outcome) {
      case AnalysisStageAccepted():
        // The next poll sees it queued; no need to guess a state here.
        break;
      case AnalysisRateLimited(:final retryAfter):
        // Fair use on the engine commands. Wait what the server asked for,
        // then carry on where we left off.
        _floor = retryAfter;
        _log.debug('$gameId: rate limited, waiting ${retryAfter.inSeconds} s');
      case AnalysisPrerequisiteMissing():
      case AnalysisAccepted():
      case AnalysisLimitReached():
      case AnalysisQueueFull():
      case AnalysisEmailNotVerified():
      case AnalysisAiConsentRequired():
      case AnalysisRequestFailed():
        // Nothing the tracker can do about it; the user has to ask again.
        _emit(StageFailedEvent(gameId, next, failureCode: _codeOf(outcome)));
        await _untrack(owner, gameId, state: WorkflowState.failed);
    }
    return true;
  }

  static String? _codeOf(RequestAnalysisOutcome outcome) => switch (outcome) {
    AnalysisPrerequisiteMissing() => 'stage_input_missing',
    AnalysisRequestFailed() => null,
    _ => null,
  };

  // ---- Bookkeeping ----

  /// Stops watching [gameId]: either the row is deleted (the game is gone) or
  /// it is left behind in [state] for the UI to read.
  Future<void> _untrack(
    String owner,
    String gameId, {
    WorkflowState state = WorkflowState.done,
    bool remove = false,
  }) async {
    _targets.remove(gameId);
    if (remove && _workflows.value.containsKey(gameId)) {
      _workflows.value = {..._workflows.value}..remove(gameId);
    }
    try {
      if (remove) {
        await _db.pendingWorkflowsDao.remove(owner, gameId);
      } else {
        await _db.pendingWorkflowsDao.setState(owner, gameId, state);
      }
    } on Object catch (e, s) {
      _warn('closing the workflow of $gameId failed', e, s);
    }
  }

  void _emit(WorkflowEvent event) {
    if (!_disposed && !_events.isClosed) {
      _events.add(event);
    }
  }

  /// The stage runs a stored assembly was built from.
  static Map<AnalysisStage, String> _runIdsOf(CachedAnalysis? row) {
    final decoded = _decode(row?.stageRunIds ?? '');
    if (decoded == null) return const {};
    final ids = <AnalysisStage, String>{};
    for (final MapEntry(:key, :value) in decoded.entries) {
      final stage = AnalysisStage.fromWire(key);
      if (value is String && stage != AnalysisStage.unknown) {
        ids[stage] = value;
      }
    }
    return ids;
  }

  static Map<String, dynamic>? _decode(String raw) {
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  void _warn(String message, Object error, StackTrace stack) {
    // A closed database after dispose is the end of the app or of a test.
    if (!_disposed) {
      _log.warning(message, error: error, stackTrace: stack);
    }
  }
}
