// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/api/stage_api.dart';
import 'package:bogner_chess/core/connectivity/connectivity.dart';
import 'package:bogner_chess/core/game/game_metadata.dart';

/// A connectivity source the test switches.
class FakeConnectivity implements ConnectivitySource {
  FakeConnectivity({this.online = true});

  bool online;
  final StreamController<bool> _changes = StreamController.broadcast(
    sync: true,
  );

  void set({required bool online}) {
    this.online = online;
    _changes.add(online);
  }

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get changes => _changes.stream;
}

typedef ImportCall = ({
  GameMetadata metadata,
  String movetext,
  String clientGameId,
  ImportSource source,
});

/// A server that stores games by `clientGameId`, like the real one. Queue
/// [failures] to let the next imports end differently.
class FakeGamesApi implements GamesApi {
  final List<ImportCall> calls = [];

  /// Stored games by client id: the server side of idempotency.
  final Map<String, GameSummary> stored = {};

  /// Outcomes for the next imports, first in first out. Null means "store it
  /// and answer normally".
  final List<ImportOutcome?> failures = [];

  /// When set, the next import waits for it (single-flight tests).
  Completer<void>? gate;

  /// With this set, the game is stored but the answer is an error: the
  /// response got lost on the way back.
  bool loseNextAnswer = false;

  @override
  Future<ImportOutcome> import({
    required GameMetadata metadata,
    required String movetext,
    required String clientGameId,
    required ImportSource source,
  }) async {
    calls.add((
      metadata: metadata,
      movetext: movetext,
      clientGameId: clientGameId,
      source: source,
    ));
    await gate?.future;
    if (failures.isNotEmpty) {
      final failure = failures.removeAt(0);
      if (failure != null) return failure;
    }
    final game = stored.putIfAbsent(
      clientGameId,
      () => GameSummary(
        id: 'game-${stored.length + 1}',
        clientGameId: clientGameId,
        playerColor: metadata.playerColor ?? PlayerColor.white,
        result: metadata.result,
        hasAnalysis: false,
      ),
    );
    if (loseNextAnswer) {
      loseNextAnswer = false;
      return const ImportFailed(ApiNetworkError(ApiNetworkCause.timeout));
    }
    return GameImported(game);
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The staged commands the queue uses: only `runBaseEvaluation`.
class FakeStageApi implements StageApi {
  final List<String> started = [];

  /// Outcomes for the next commands; when empty a command is accepted.
  final List<RequestAnalysisOutcome> outcomes = [];

  @override
  Future<RequestAnalysisOutcome> analyseGame(
    String gameId, {
    String language = 'en',
    String? persona,
  }) async {
    started.add(gameId);
    if (outcomes.isNotEmpty) return outcomes.removeAt(0);
    return AnalysisAccepted(
      workflow: AnalysisWorkflow(
        gameId: gameId,
        state: AnalysisWorkflowState.analysing,
        targetStage: AnalysisStage.coaching,
        stages: const [],
        isComplete: false,
      ),
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
