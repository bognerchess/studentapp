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
  const StageReadyEvent(super.gameId, this.stage, {this.took});
  final AnalysisStage stage;

  /// How long the run took, from when it was requested to when it finished;
  /// null when the server did not report both.
  final Duration? took;

  @override
  String toString() => 'StageReadyEvent($gameId, ${stage.name})';
}

/// A stage of [gameId] failed. Analysing the game again is the way forward —
/// the server resumes at the stage that failed — and a coaching stage that
/// failed was refunded by the server.
final class StageFailedEvent extends WorkflowEvent {
  const StageFailedEvent(super.gameId, this.stage, {this.failureCode});
  final AnalysisStage stage;
  final String? failureCode;

  @override
  String toString() => 'StageFailedEvent($gameId, ${stage.name}, $failureCode)';
}

/// What was computed for [gameId] describes moves that have since changed.
/// The user decides whether to analyse again.
final class WorkflowStaleEvent extends WorkflowEvent {
  const WorkflowStaleEvent(super.gameId);

  @override
  String toString() => 'WorkflowStaleEvent($gameId)';
}

/// Follows the analysis of the user's games.
///
/// It only watches. The chain itself is the server's: `analyseGame` starts it
/// and runs it to the end, so this class fires no mutation at all — one
/// `gameAnalysisWorkflow` query per tracked game per tick, and the artifacts
/// of whatever became ready.
///
/// The pipeline is per game and the server has no "my running workflows"
/// field, so the games to ask about come from `pending_workflows`. The first
/// tick comes after [defaultBaseInterval] (or what `mobileConfig` says); every
/// further one waits [backoffFactor] times longer, up to [maxInterval]. It only
/// runs while the app is in the foreground with its UI mounted
/// ([setForeground]), somebody is signed in and at least one game is tracked. A
/// resume, a newly tracked game and [refreshNow] poll at once and start the
/// interval again.
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
/// 5. It stops once `state` says nothing is running any more — READY, STALE or
///    FAILED — and everything that is ready has been stored. An IDLE game that
///    stays idle over two ticks is dropped as well: whoever asked for it did
///    not get through.
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

  /// What the `pending_workflows` row records as the aim of a tracked game.
  /// The server decides how far the chain actually goes; the column is kept
  /// because the table has it, and it says what the user asked for.
  static const AnalysisStage defaultTarget = AnalysisStage.coaching;

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

  /// The games being watched.
  final Set<String> _tracked = {};

  /// Games whose last poll said IDLE. Nothing runs for them, but the request
  /// that was supposed to start something may simply not have landed yet, so
  /// the first idle tick is forgiven and the second gives up.
  final Set<String> _idle = {};

  StreamSubscription<List<PendingWorkflow>>? _rows;
  String? _owner;
  bool _foreground = true;
  bool _disposed = false;
  Timer? _timer;
  Duration? _interval;

  Future<void>? _polling;
  bool _pollAgain = false;

  /// The pipeline of every watched game, as of the last poll.
  ValueListenable<Map<String, AnalysisWorkflow>> get workflows => _workflows;

  /// What happened while the tracker was watching. Broadcast, no replay.
  Stream<WorkflowEvent> get events => _events.stream;

  /// The wait before the next poll; null while the poller is idle.
  @visibleForTesting
  Duration? get currentInterval => _timer == null ? null : _interval;

  bool get hasActiveWorkflows => _tracked.isNotEmpty;

  /// The games being watched, for a test and for a status line.
  @visibleForTesting
  Set<String> get trackedGames => Set.unmodifiable(_tracked);

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
    _tracked.clear();
    _idle.clear();
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
  ///
  /// `target_stage` is not read: how far the chain goes is the server's
  /// decision now, and the column only records what the user asked for.
  void _adopt(String owner, List<PendingWorkflow> rows) {
    if (_disposed || owner != _owner) {
      return;
    }
    var added = false;
    for (final row in rows) {
      if (_tracked.add(row.gameId)) {
        added = true;
      }
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

  /// Watches the analysis of [gameId] and stores what lands.
  ///
  /// It starts nothing. The caller has already called `analyseGame` (the game
  /// screen) or is about to (the submit queue); this records the game in
  /// `pending_workflows`, so an app that is killed resumes watching on the next
  /// start, and polls at once.
  ///
  /// Calling it on a game that is already watched only brings the next poll
  /// forward, which is what "Try again" and "Run the coach again" need.
  Future<void> track(String gameId) async {
    final owner = _owner;
    if (_disposed || owner == null) {
      return;
    }
    _tracked.add(gameId);
    _idle.remove(gameId);
    try {
      await _db.pendingWorkflowsDao.upsert(
        owner,
        gameId: gameId,
        targetStage: defaultTarget.wire!,
      );
    } on Object catch (e, s) {
      _warn('recording a workflow failed', e, s);
    }
    await refreshNow();
  }

  /// Stores what the server already holds for [gameId] without starting
  /// anything: the artifacts of the finished engine stages, and the coach
  /// document when there is one.
  ///
  /// For a game this tracker is not watching: it finished while this device
  /// was not looking (another device ran it, or the artifacts could not be
  /// fetched at the time and the pipeline was done before they could be
  /// asked for again). The review asks for this before giving up on a game
  /// whose stages the server reports as ready. Never throws.
  Future<void> syncArtifacts(String gameId) async {
    final owner = _owner;
    if (_disposed || owner == null) {
      return;
    }
    final AnalysisWorkflow? workflow;
    try {
      workflow = await _api.workflow(gameId);
    } on ApiError catch (e) {
      _log.debug('syncing $gameId failed: $e');
      return;
    }
    if (workflow == null || _disposed || owner != _owner) {
      return;
    }
    try {
      await _storeArtifacts(owner, gameId, workflow);
      await _followCoaching(owner, gameId, workflow);
    } on Object catch (e, s) {
      _warn('syncing $gameId failed', e, s);
      return;
    }
    if (_disposed || owner != _owner) {
      return;
    }
    final previous = _workflows.value[gameId];
    _workflows.value = {..._workflows.value, gameId: workflow};
    await _rememberSummary(owner, gameId, previous, workflow);
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
    if (_disposed || !_foreground || _owner == null || _tracked.isEmpty) {
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
    if (_disposed || owner == null || _tracked.isEmpty) {
      return;
    }
    for (final gameId in _tracked.toList()) {
      if (_disposed || owner != _owner) {
        return;
      }
      try {
        await _tick(owner, gameId);
      } on Object catch (e, s) {
        _warn('following $gameId failed', e, s);
      }
    }
    final watched = _tracked.toList();
    if (watched.isNotEmpty) {
      try {
        await _db.pendingWorkflowsDao.markPolled(owner, watched);
      } on Object catch (e, s) {
        _warn('stamping the poll time failed', e, s);
      }
    }
  }

  /// One look at [gameId]: what changed, what is there to store, and whether
  /// there is anything left to wait for.
  Future<void> _tick(String owner, String gameId) async {
    if (!_tracked.contains(gameId)) {
      return;
    }
    final AnalysisWorkflow? workflow;
    try {
      workflow = await _api.workflow(gameId);
    } on ApiError catch (e) {
      // Offline, or a server that is having a bad minute: ask again later.
      _log.debug('polling $gameId failed: $e');
      return;
    }
    if (_disposed || owner != _owner || !_tracked.contains(gameId)) {
      return;
    }
    if (workflow == null) {
      // The game is gone, or never was this user's.
      await _untrack(owner, gameId, remove: true);
      return;
    }

    _emitChanges(gameId, workflow);
    final previous = _workflows.value[gameId];

    // The documents first, then the pipeline. A screen that learns a stage is
    // READY goes looking for what that stage produced, so publishing the
    // state before storing the artifact tells it to look at a cache that is
    // still empty — and nothing asks a second time until the *next* stage
    // lands. On a tick where nothing new is ready both calls return at once,
    // so the progress of a running stage is not held up by this.
    await _storeArtifacts(owner, gameId, workflow);
    await _followCoaching(owner, gameId, workflow);
    if (_disposed || owner != _owner || !_tracked.contains(gameId)) {
      return;
    }

    _workflows.value = {..._workflows.value, gameId: workflow};
    await _rememberSummary(owner, gameId, previous, workflow);
    if (_disposed || owner != _owner || !_tracked.contains(gameId)) {
      return;
    }

    final state = workflow.workflowState;
    if (state.isActive) {
      _idle.remove(gameId);
      return;
    }
    // Nothing runs. Keep watching only while something that is ready has not
    // been fetched yet: the artifact of the last stage usually lands one tick
    // after the state does.
    if (!await _isStored(owner, gameId, workflow)) {
      return;
    }
    if (_disposed || owner != _owner || !_tracked.contains(gameId)) {
      return;
    }
    switch (state) {
      case AnalysisWorkflowState.stale:
        _emit(WorkflowStaleEvent(gameId));
        await _untrack(owner, gameId, state: WorkflowState.failed);
      case AnalysisWorkflowState.failed:
        // The failure itself was announced by [_emitChanges].
        await _untrack(owner, gameId, state: WorkflowState.failed);
      case AnalysisWorkflowState.ready:
        await _untrack(owner, gameId, state: WorkflowState.done);
      case AnalysisWorkflowState.idle:
        // Whoever asked for this game has not got through. One tick of grace,
        // because the row can be written before the mutation is answered.
        if (!_idle.add(gameId)) {
          await _untrack(owner, gameId, state: WorkflowState.failed);
        }
      case AnalysisWorkflowState.analysing:
      case AnalysisWorkflowState.unknown:
        // [workflowState] never returns these here: `analysing` is active and
        // `unknown` is resolved against the stage states.
        break;
    }
  }

  /// Whether everything the server reports as ready is in the cache, so there
  /// is nothing left to fetch for [gameId].
  Future<bool> _isStored(
    String owner,
    String gameId,
    AnalysisWorkflow workflow,
  ) async {
    final ready = workflow.readyRunIds;
    if (ready.isEmpty) {
      return true;
    }
    final stored = await _db.analysisCacheDao.get(owner, gameId);
    if (_disposed || owner != _owner) {
      return true;
    }
    if (stored == null) {
      return false;
    }
    final known = _runIdsOf(stored);
    if (workflow.coachReady) {
      final coachId = ready[AnalysisStage.coaching];
      return stored.source == AnalysisSource.coach &&
          (coachId == null || known[AnalysisStage.coaching] == coachId);
    }
    // A coach document is better than any assembly and is never replaced by
    // one, so there is nothing more to fetch while it is there.
    if (stored.source == AnalysisSource.coach) {
      return true;
    }
    final deepId = ready[AnalysisStage.deepEvaluation];
    if (deepId != null) {
      return known[AnalysisStage.deepEvaluation] == deepId;
    }
    final baseId = ready[AnalysisStage.baseEvaluation];
    return baseId == null || known[AnalysisStage.baseEvaluation] == baseId;
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
          _emit(StageReadyEvent(gameId, stage.stage, took: _tookOf(stage.run)));
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

  /// From requested to finished, which is what a user waits; null unless the
  /// server reported both.
  static Duration? _tookOf(StageRunSummary? run) {
    final finished = run?.finishedAt;
    if (run == null || finished == null) {
      return null;
    }
    final took = finished.difference(run.requestedAt);
    return took.isNegative ? null : took;
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

  // ---- Bookkeeping ----

  /// Stops watching [gameId]: either the row is deleted (the game is gone) or
  /// it is left behind in [state] for the UI to read.
  Future<void> _untrack(
    String owner,
    String gameId, {
    WorkflowState state = WorkflowState.done,
    bool remove = false,
  }) async {
    _tracked.remove(gameId);
    _idle.remove(gameId);
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
