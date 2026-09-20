// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:math' as math;

import 'package:bogner_chess/core/analysis/analysis_job_sink.dart';
import 'package:bogner_chess/core/api/analysis_api.dart';
import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/connectivity/connectivity.dart';
import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;

import 'draft_meta.dart';
import 'submit_models.dart';

/// Uploads finished drafts, one at a time, whenever there is a chance that
/// it works (AC-3: "a game can be entered without connection and submitted
/// later").
///
/// One draft goes through: `ready` → `submitting` → import the game (unless
/// the server has it already) → request the analysis (if wanted) →
/// `submitted`. The import is idempotent per `client_game_id`, so a lost
/// answer or a killed app only costs a repetition.
///
/// What ends how:
///
/// * **Imported, analysis accepted**: submitted; the job goes to the
///   [AnalysisJobSink].
/// * **Imported, analysis refused** (limit, full queue, rate limit, e-mail
///   address not verified, AI consent missing): submitted all the same,
///   because the game is saved. The reason is kept in the draft's metadata
///   ([DraftMeta.analysisHold]) and the user starts the analysis from the
///   game. The queue never asks again by itself.
/// * **The server cannot read the moves, or refuses the game**: failed for
///   good, with a [SubmitError] the UI can explain.
/// * **Network, server trouble, rate limit on the import**: back to `ready`
///   with a back-off of 5 s, 15 s, 1 min, 5 min and then 30 min; after
///   [maxAttempts] attempts the draft is `failed` and waits for Retry.
///   A failed analysis *request* never makes a saved game look failed: when
///   it runs out of attempts the draft is submitted with
///   [AnalysisHold.requestFailed].
///
/// While the device reports no network the queue does not even try, so that
/// an afternoon in a playing hall without reception does not use up the
/// attempts. Retry from the UI tries regardless.
///
/// Runs are single-flight; a [kick] during a run causes one more pass after
/// it. Everything is scoped to the signed-in owner, and a run stops as soon
/// as somebody else is signed in.
class SubmitQueue {
  SubmitQueue({
    required this._database,
    required this._games,
    required this._analysis,
    required this._owner,
    required this._connectivity,
    required this._jobSink,
    void Function()? onLibraryChanged,
    String Function()? coachLanguage,
  }) : _onLibraryChanged = onLibraryChanged ?? _nothing,
       _coachLanguage = coachLanguage ?? _english;

  static void _nothing() {}
  static String _english() => 'en';

  /// The delay after the first, second, ... failed attempt; the last one
  /// repeats.
  static const List<Duration> backoff = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 30),
  ];

  /// After this many failed attempts a draft is `failed`.
  static const int maxAttempts = 8;

  /// Submitted drafts are only kept for [DraftMeta.analysisHold]; after this
  /// long nobody needs that any more.
  static const Duration keepSubmittedFor = Duration(days: 7);

  static const _log = Log('submit-queue');

  final AppDatabase Function() _database;
  final GamesApi Function() _games;
  final AnalysisApi Function() _analysis;
  final String? Function() _owner;
  final ConnectivitySource _connectivity;
  final AnalysisJobSink Function() _jobSink;
  final void Function() _onLibraryChanged;
  final String Function() _coachLanguage;

  final ValueNotifier<SubmitQueueStatus> _status = ValueNotifier(
    SubmitQueueStatus.idle,
  );
  final StreamController<SubmitEvent> _events = StreamController.broadcast();
  final Set<String> _recovered = {};

  Future<void>? _current;
  bool _again = false;
  bool _forceNext = false;
  bool _started = false;
  bool _disposed = false;
  Timer? _timer;
  String? _watchedOwner;
  StreamSubscription<List<Draft>>? _watch;
  StreamSubscription<bool>? _connectivityChanges;
  AppLifecycleListener? _lifecycle;

  /// Counts and state for the queue surface.
  ValueListenable<SubmitQueueStatus> get status => _status;

  /// Uploads that ended, for a message on whatever screen is showing.
  Stream<SubmitEvent> get events => _events.stream;

  DraftsDao get _drafts => _database().draftsDao;

  // ---- Life cycle ---------------------------------------------------------

  /// Call once when the app starts: recovers drafts a killed app left in
  /// `submitting`, listens for the network coming back and for the app
  /// returning to the foreground, and makes a first pass.
  void start({bool observeLifecycle = true}) {
    if (_started || _disposed) return;
    _started = true;
    _connectivityChanges = _connectivity.changes.listen(_onConnectivity);
    if (observeLifecycle) {
      _lifecycle = AppLifecycleListener(onResume: onAppResumed);
    }
    unawaited(kick());
  }

  /// The app is in the foreground again. Time has passed and the network may
  /// be another one: every back-off ends.
  void onAppResumed() => unawaited(_clearBackoffAndKick());

  /// Somebody signed in or out.
  void onOwnerChanged() {
    _timer?.cancel();
    _timer = null;
    if (_owner() == null) {
      unawaited(_stopWatching());
      _status.value = SubmitQueueStatus(offline: _status.value.offline);
      return;
    }
    unawaited(kick());
  }

  void _onConnectivity(bool online) {
    _status.value = _status.value.copyWith(offline: !online);
    if (online) unawaited(_clearBackoffAndKick());
  }

  Future<void> _clearBackoffAndKick() async {
    final owner = _owner();
    if (owner == null || _disposed) return;
    try {
      await _drafts.clearBackoff(owner);
    } on Object catch (error, stackTrace) {
      _log.warning('clearBackoff', error: error, stackTrace: stackTrace);
    }
    await kick();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _lifecycle?.dispose();
    unawaited(_connectivityChanges?.cancel());
    unawaited(_stopWatching());
    unawaited(_events.close());
    _status.dispose();
  }

  // ---- Putting games into the queue ---------------------------------------

  /// "Save" at the end of the board path: the draft the entry screen has
  /// autosaved gets its metadata and becomes `ready`. Returns false when
  /// nobody is signed in or the draft is not being edited any more (it was
  /// sent already); nothing has changed then.
  Future<bool> enqueueEntry({
    required String draftId,
    required String pgnMoves,
    required GameMetadata metadata,
    required Side orientation,
    required bool analyse,
  }) async {
    final owner = _owner();
    if (owner == null) return false;
    final db = _database();
    final dao = db.draftsDao;
    final queued = await db.transaction(() async {
      // The autosave normally created the row long ago. If it never landed
      // (a failing disk is the only reason), the game is saved here.
      final draft =
          await dao.get(owner, draftId) ??
          await dao.create(owner, id: draftId, pgn: pgnMoves);
      if (draft.state != DraftState.editing) return false;
      final meta = DraftMeta.decode(draft.metaJson);
      await dao.autosave(
        owner,
        draftId,
        pgn: pgnMoves,
        metaJson: DraftMeta(
          metadata: metadata,
          source: DraftSource.board,
          cursorPly: meta.cursorPly,
          orientation: orientation,
        ).encode(),
        wantsAnalysis: analyse,
      );
      return dao.markReady(owner, draftId);
    });
    if (queued) unawaited(kick());
    return queued;
  }

  /// "Save" at the end of the import path: a new draft that is `ready` at
  /// once. Returns its id, or null when nobody is signed in.
  Future<String?> enqueueImport({
    required String movetext,
    required GameMetadata metadata,
    required DraftSource source,
    required bool analyse,
  }) async {
    final owner = _owner();
    if (owner == null) return null;
    final draft = await _drafts.create(
      owner,
      pgn: movetext,
      metaJson: DraftMeta(metadata: metadata, source: source).encode(),
      wantsAnalysis: analyse,
      ready: true,
    );
    unawaited(kick());
    return draft.id;
  }

  /// The metadata stored with a draft, for the form of a resumed game.
  Future<DraftMeta?> metaOf(String draftId) async {
    final owner = _owner();
    if (owner == null) return null;
    final draft = await _drafts.get(owner, draftId);
    return draft == null ? null : DraftMeta.decode(draft.metaJson);
  }

  // ---- What the user can do about a draft ---------------------------------

  /// Retry from the UI: every failed draft is ready again, every back-off
  /// ends, and the queue tries even if the device claims to be offline.
  Future<void> retryAll() async {
    final owner = _owner();
    if (owner == null) return;
    final dao = _drafts;
    final failed = await dao.getAll(owner, states: const {DraftState.failed});
    for (final draft in failed) {
      await dao.retry(owner, draft.id);
    }
    await dao.clearBackoff(owner);
    await kick(force: true);
  }

  /// Retry of one failed draft.
  Future<void> retry(String draftId) async {
    final owner = _owner();
    if (owner == null) return;
    await _drafts.retry(owner, draftId);
    await _drafts.clearBackoff(owner);
    await kick(force: true);
  }

  /// Throws the draft away. A draft that is being sent right now is left
  /// alone (returns false); it can be deleted as a game a moment later.
  Future<bool> delete(String draftId) async {
    final owner = _owner();
    if (owner == null) return false;
    final draft = await _drafts.get(owner, draftId);
    if (draft == null || draft.state == DraftState.submitting) return false;
    return _drafts.remove(owner, draftId);
  }

  // ---- The run -------------------------------------------------------------

  /// Makes a pass over the queue, or notes that one more is wanted when a
  /// pass is under way. Completes when the queue is at rest again. Never
  /// throws. [force] ignores "the device is offline".
  Future<void> kick({bool force = false}) {
    if (_disposed) return Future.value();
    if (force) _forceNext = true;
    final current = _current;
    if (current != null) {
      _again = true;
      return current;
    }
    return _current = _drain();
  }

  Future<void> _drain() async {
    try {
      do {
        _again = false;
        final force = _forceNext;
        _forceNext = false;
        await _pass(force: force);
      } while (_again && !_disposed);
    } on Object catch (error, stackTrace) {
      // The database is the only thing that throws here.
      _log.error('run failed', error: error, stackTrace: stackTrace);
    } finally {
      _current = null;
      if (!_disposed) {
        _status.value = _status.value.copyWith(uploading: false);
      }
    }
  }

  Future<void> _pass({required bool force}) async {
    final owner = _owner();
    if (owner == null) return;
    final dao = _drafts;

    if (_recovered.add(owner)) {
      final recovered = await dao.recoverInterrupted(owner);
      if (recovered > 0) _log.info('recovered $recovered interrupted');
      await _prune(owner);
    }
    _watchDrafts(owner);

    final online = await _connectivity.isOnline();
    if (_disposed) return;
    _status.value = _status.value.copyWith(offline: !online);
    if (!online && !force) return;

    while (!_disposed && _owner() == owner) {
      final draft = await dao.nextSubmittable(owner);
      if (draft == null) break;
      // False: somebody changed it in between (deleted, reopened).
      if (!await dao.markSubmitting(owner, draft.id)) continue;
      _status.value = _status.value.copyWith(uploading: true);
      bool goOn;
      try {
        goOn = await _submit(owner, draft);
      } on Object catch (error, stackTrace) {
        _log.error('submit failed', error: error, stackTrace: stackTrace);
        await _fail(owner, draft, const SubmitError(SubmitErrorKind.internal));
        goOn = false;
      }
      if (!goOn) break;
    }
    if (_disposed) return;
    _status.value = _status.value.copyWith(uploading: false);
    await _armTimer(owner);
  }

  /// Sends one draft that is `submitting`. Returns whether the run should go
  /// on with the next draft (false after trouble that would hit it as well).
  Future<bool> _submit(String owner, Draft draft) async {
    final dao = _drafts;
    final meta = DraftMeta.decode(draft.metaJson);

    var gameId = draft.serverGameId;
    if (gameId == null) {
      if (!await _stillOwner(owner)) return false;
      final outcome = await _games().import(
        metadata: meta.metadata,
        movetext: draft.pgn,
        clientGameId: draft.clientGameId,
        source: meta.source.importSource,
      );
      switch (outcome) {
        case GameImported(:final game):
          gameId = game.id;
          await dao.setServerGameId(owner, draft.id, gameId);
          _onLibraryChanged();
        case ImportPgnInvalid(:final moveNumber, :final san):
          await _fail(
            owner,
            draft,
            SubmitError(
              SubmitErrorKind.pgnInvalid,
              moveNumber: moveNumber,
              san: san,
            ),
          );
          return true;
        case ImportRateLimited(:final retryAfter):
          await _fail(
            owner,
            draft,
            const SubmitError(SubmitErrorKind.rateLimited),
            atLeast: retryAfter,
          );
          return false;
        case ImportFailed(:final error):
          final submitError = _errorOf(error);
          await _fail(owner, draft, submitError);
          return !submitError.isTransient;
      }
    }

    AnalysisHold? hold;
    var analysis = SubmittedAnalysis.notRequested;
    if (draft.wantsAnalysis) {
      if (!await _stillOwner(owner)) return false;
      final outcome = await _analysis().request(
        gameId: gameId,
        language: _coachLanguage(),
      );
      switch (outcome) {
        case AnalysisAccepted(:final job):
          analysis = SubmittedAnalysis.started;
          _jobSink().track(job);
        case AnalysisLimitReached():
          hold = AnalysisHold.limitReached;
        case AnalysisQueueFull():
          hold = AnalysisHold.queueFull;
        case AnalysisRateLimited():
          hold = AnalysisHold.rateLimited;
        case AnalysisEmailNotVerified():
          hold = AnalysisHold.emailNotVerified;
        case AnalysisAiConsentRequired():
          hold = AnalysisHold.aiConsentRequired;
        case AnalysisRequestFailed(:final error):
          final submitError = _errorOf(error);
          final nextAttemptAt = submitError.isTransient
              ? _nextAttemptAt(draft.attempts)
              : null;
          if (nextAttemptAt != null) {
            // The game is saved (server_game_id is set); only the request
            // is repeated.
            await dao.markSubmitFailed(
              owner,
              draft.id,
              error: submitError.encode(),
              nextAttemptAt: nextAttemptAt,
            );
            return false;
          }
          hold = AnalysisHold.requestFailed;
      }
      if (hold != null) analysis = SubmittedAnalysis.held;
    }

    await dao.markSubmitted(
      owner,
      draft.id,
      serverGameId: gameId,
      metaJson: hold == null ? null : meta.withAnalysisHold(hold).encode(),
    );
    _log.info('submitted (analysis ${analysis.name}, hold ${hold?.name})');
    _emit(
      GameUploaded(draft.id, gameId: gameId, analysis: analysis, hold: hold),
    );
    return true;
  }

  /// Between two steps somebody else may have signed in. Their token must
  /// not carry this owner's game: the draft goes back to `ready` untouched.
  Future<bool> _stillOwner(String owner) async {
    if (_owner() == owner) return true;
    // Single-flight: the only `submitting` draft of this owner is ours.
    await _drafts.recoverInterrupted(owner);
    return false;
  }

  Future<void> _fail(
    String owner,
    Draft draft,
    SubmitError error, {
    Duration? atLeast,
  }) async {
    final nextAttemptAt = error.isTransient
        ? _nextAttemptAt(draft.attempts, atLeast: atLeast)
        : null;
    await _drafts.markSubmitFailed(
      owner,
      draft.id,
      error: error.encode(),
      nextAttemptAt: nextAttemptAt,
    );
    _log.info(
      'attempt ${draft.attempts + 1} failed (${error.kind.name}), '
      '${nextAttemptAt == null ? 'gave up' : 'will retry'}',
    );
    if (nextAttemptAt == null) _emit(UploadFailed(draft.id, error));
  }

  /// When to try again after one more failure, or null to give up.
  DateTime? _nextAttemptAt(int attemptsSoFar, {Duration? atLeast}) {
    if (attemptsSoFar + 1 >= maxAttempts) return null;
    var delay = backoff[math.min(attemptsSoFar, backoff.length - 1)];
    if (atLeast != null && atLeast > delay) delay = atLeast;
    return _database().now().add(delay);
  }

  static SubmitError _errorOf(ApiError error) => switch (error) {
    ApiNetworkError() => const SubmitError(SubmitErrorKind.network),
    ApiUnauthenticated() => const SubmitError(SubmitErrorKind.unauthenticated),
    ApiServerError() ||
    ApiGraphQLError() => const SubmitError(SubmitErrorKind.server),
    ApiRejected(:final retryAfter?) when retryAfter > Duration.zero =>
      const SubmitError(SubmitErrorKind.rateLimited),
    ApiRejected(:final isRetryable) => SubmitError(
      isRetryable ? SubmitErrorKind.server : SubmitErrorKind.rejected,
    ),
  };

  Future<void> _armTimer(String owner) async {
    _timer?.cancel();
    _timer = null;
    final end = await _drafts.nextBackoffEnd(owner);
    if (end == null || _disposed) return;
    var delay = end.difference(_database().now());
    // The database keeps whole seconds; never spin.
    if (delay < const Duration(seconds: 1)) delay = const Duration(seconds: 1);
    _timer = Timer(delay, () => unawaited(kick()));
  }

  /// Forgets submitted drafts nobody needs any more.
  Future<void> _prune(String owner) async {
    final dao = _drafts;
    final limit = _database().now().subtract(keepSubmittedFor);
    final submitted = await dao.getAll(
      owner,
      states: const {DraftState.submitted},
    );
    for (final draft in submitted) {
      if (draft.updatedAt.isBefore(limit)) await dao.remove(owner, draft.id);
    }
  }

  // ---- Status ---------------------------------------------------------------

  void _watchDrafts(String owner) {
    if (_watchedOwner == owner || _disposed) return;
    unawaited(_watch?.cancel());
    _watchedOwner = owner;
    _watch = _drafts
        .watchAll(
          owner,
          states: const {
            DraftState.ready,
            DraftState.submitting,
            DraftState.failed,
          },
        )
        .listen(
          _onDrafts,
          onError: (Object error, StackTrace stackTrace) =>
              _log.warning('watch', error: error, stackTrace: stackTrace),
        );
  }

  Future<void> _stopWatching() async {
    _watchedOwner = null;
    final watch = _watch;
    _watch = null;
    await watch?.cancel();
  }

  void _onDrafts(List<Draft> drafts) {
    if (_disposed) return;
    final now = _database().now();
    var waiting = 0;
    var failed = 0;
    var anyDue = false;
    DateTime? earliest;
    for (final draft in drafts) {
      switch (draft.state) {
        case DraftState.failed:
          failed++;
        case DraftState.submitting:
          waiting++;
          anyDue = true;
        case DraftState.ready:
          waiting++;
          final at = draft.nextAttemptAt;
          if (at == null || !at.isAfter(now)) {
            anyDue = true;
          } else if (earliest == null || at.isBefore(earliest)) {
            earliest = at;
          }
        case DraftState.editing || DraftState.submitted:
          break;
      }
    }
    _status.value = _status.value.copyWith(
      waiting: waiting,
      failed: failed,
      nextAttemptAt: () => anyDue ? null : earliest,
    );
  }

  void _emit(SubmitEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
