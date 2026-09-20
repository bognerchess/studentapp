// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/analysis/analysis_job_sink.dart';
import 'package:bogner_chess/core/api/analysis_api.dart';
import 'package:bogner_chess/core/api/games_api.dart';
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

class FakeAnalysisApi implements AnalysisApi {
  final List<({String gameId, String language})> calls = [];

  /// Outcomes for the next requests; when empty a request is accepted.
  final List<RequestAnalysisOutcome> outcomes = [];

  @override
  Future<RequestAnalysisOutcome> request({
    required String gameId,
    String language = 'en',
    String? deviceId,
  }) async {
    calls.add((gameId: gameId, language: language));
    if (outcomes.isNotEmpty) return outcomes.removeAt(0);
    return AnalysisAccepted(
      JobInfo(
        id: 'job-${calls.length}',
        gameId: gameId,
        status: JobStatus.queued,
        requestedAt: DateTime.utc(2026, 9, 20, 10),
      ),
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingJobSink implements AnalysisJobSink {
  final List<JobInfo> jobs = [];

  @override
  void track(JobInfo job) => jobs.add(job);
}
