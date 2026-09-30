// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/analytics/analytics.dart';
import 'package:bogner_chess/core/api/analysis_api.dart';
import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/auth/auth_providers.dart';
import 'package:bogner_chess/core/auth/auth_repository.dart';
import 'package:bogner_chess/features/analysis_status/domain/mobile_config_provider.dart';
import 'package:bogner_chess/features/analysis_status/domain/workflow_tracker_providers.dart';
import 'package:bogner_chess/features/library/domain/games_repository.dart';
import 'package:bogner_chess/features/library/domain/owner.dart';
import 'package:bogner_chess/features/usage/domain/usage_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'final_position.dart';

/// What the game screen shows.
@immutable
class GameDetailState {
  const GameDetailState({
    this.game,
    this.finalFen,
    this.plyCount,
    this.loading = true,
    this.loadError,
    this.notFound = false,
    this.requesting = false,
    this.deleting = false,
  });

  /// From the cache at first, then from the server.
  final GameSummary? game;

  /// Known once the moves were fetched.
  final String? finalFen;
  final int? plyCount;

  final bool loading;

  /// Why the server could not be asked. With a cached [game] the screen
  /// still works; without one it shows this.
  final ApiError? loadError;

  /// The server does not have the game (any more).
  final bool notFound;

  /// An analysis request or a delete is on its way.
  final bool requesting;
  final bool deleting;

  bool get busy => requesting || deleting;

  GameDetailState copyWith({
    GameSummary? game,
    String? finalFen,
    int? plyCount,
    bool? loading,
    ApiError? Function()? loadError,
    bool? notFound,
    bool? requesting,
    bool? deleting,
  }) {
    return GameDetailState(
      game: game ?? this.game,
      finalFen: finalFen ?? this.finalFen,
      plyCount: plyCount ?? this.plyCount,
      loading: loading ?? this.loading,
      loadError: loadError == null ? this.loadError : loadError(),
      notFound: notFound ?? this.notFound,
      requesting: requesting ?? this.requesting,
      deleting: deleting ?? this.deleting,
    );
  }
}

final gameDetailControllerProvider = NotifierProvider.autoDispose
    .family<GameDetailController, GameDetailState, String>(
      GameDetailController.new,
    );

class GameDetailController extends Notifier<GameDetailState> {
  GameDetailController(this.gameId);

  final String gameId;

  @override
  GameDetailState build() {
    ref.watch(currentOwnerProvider);
    unawaited(Future.microtask(_load));
    return const GameDetailState();
  }

  String? get _owner => ref.read(currentOwnerProvider);

  Future<void> _load() async {
    final owner = _owner;
    if (owner == null || !ref.mounted) {
      return;
    }
    final games = ref.read(gamesRepositoryProvider);
    final cached = await games.cached(owner, gameId);
    if (!ref.mounted) {
      return;
    }
    if (cached != null && state.game == null) {
      state = state.copyWith(game: cached);
    }
    try {
      final detail = await games.fetchDetail(owner, gameId);
      if (!ref.mounted) {
        return;
      }
      if (detail == null) {
        state = GameDetailState(loading: false, notFound: true, game: null);
        return;
      }
      state = state.copyWith(
        game: detail,
        finalFen: finalFenOf(detail.pgn),
        plyCount: detail.plyCount,
        loading: false,
        loadError: () => null,
      );
    } on ApiError catch (e) {
      if (ref.mounted) {
        state = state.copyWith(loading: false, loadError: () => e);
      }
    }
  }

  Future<void> reload() async {
    state = state.copyWith(loading: true, loadError: () => null);
    await _load();
  }

  /// Runs the three free engine stages of this game, back to back.
  ///
  /// Nothing here can be refused for quota: the engine stages are free and
  /// the backend meters only the coach. So there is no usage to invalidate,
  /// no device id and no language — the tracker writes the `pending_workflows`
  /// row and the poll that follows fires the first stage, which is what makes
  /// "Analyse" on a game whose base evaluation is already stored start the
  /// classification instead of repeating stage 1.
  ///
  /// A fair-use rate limit and a plain failure are still possible. They come
  /// back from the tracker, which knows them because it fired the mutation;
  /// null means nothing was started (nothing left to run, or the poller is
  /// idle because the app is in the background).
  Future<RequestAnalysisOutcome?> startFreeChain() async {
    if (state.requesting) {
      return const AnalysisRequestFailed(ApiNetworkError());
    }
    state = state.copyWith(requesting: true);
    try {
      final outcome = await ref
          .read(workflowTrackerProvider)
          .startChain(gameId);
      if (ref.mounted) {
        ref.read(analyticsProvider).track(AnalyticsEvents.analysisRequested, {
          'source': 'game_detail',
        });
      }
      return outcome;
    } finally {
      if (ref.mounted) {
        state = state.copyWith(requesting: false);
      }
    }
  }

  /// Runs the stage that stopped the pipeline once more.
  ///
  /// For an engine stage that is starting the chain again: the server's
  /// `nextRunnableStage` picks the failed stage up, so there is no need to
  /// name it. Coaching is the user's decision and goes through [askCoach].
  Future<RequestAnalysisOutcome?> retryStage(
    AnalysisStage stage, {
    String? languageCode,
  }) async {
    return stage.usesModel
        ? askCoach(languageCode: languageCode)
        : startFreeChain();
  }

  /// Asks the coach to write about this game. The one metered step, so this
  /// is the one call that can be refused.
  ///
  /// An accepted run goes to the workflow tracker; every other outcome is the
  /// screen's to explain. The AI consent round trip is the screen's as well
  /// (it needs the navigator): it calls this method again after the user
  /// agreed.
  ///
  /// [languageCode] is the language the app is showing (the coach writes in
  /// it when the server supports it); without one the device language is
  /// used.
  ///
  /// The request is always sent, also when the cached usage says the quota
  /// is gone: the server counts limit pressure when it refuses
  /// (`analysis_limit_hit`, once per person per day), and a client that
  /// refuses on its own would make that metric read zero. Show the numbers
  /// as a warning, never as a gate.
  Future<RequestAnalysisOutcome> askCoach({String? languageCode}) async {
    if (state.requesting) {
      return const AnalysisRequestFailed(ApiNetworkError());
    }
    state = state.copyWith(requesting: true);
    final analytics = ref.read(analyticsProvider);
    try {
      final language = coachLanguageOf(
        ref.read(mobileConfigProvider).value,
        languageCode ?? PlatformDispatcher.instance.locale.languageCode,
      );
      final outcome = await ref
          .read(stageApiProvider)
          .runCoaching(gameId, language: language);
      if (!ref.mounted) {
        return outcome;
      }
      switch (outcome) {
        case AnalysisAccepted(:final run):
          analytics.track(AnalyticsEvents.analysisRequested, {
            'language': language,
            'source': 'game_detail_coach',
          });
          await ref.read(workflowTrackerProvider).trackCoaching(gameId, run);
        case AnalysisLimitReached(:final window):
          analytics.track(AnalyticsEvents.analysisLimitHit, {
            'window': window.name,
          });
        case AnalysisPrerequisiteMissing():
        case AnalysisQueueFull():
        case AnalysisRateLimited():
        case AnalysisEmailNotVerified():
        case AnalysisAiConsentRequired():
        case AnalysisRequestFailed():
          break;
      }
      // Accepted or refused: the numbers under the button may have changed.
      if (ref.mounted) {
        ref.invalidate(usageProvider);
      }
      return outcome;
    } finally {
      if (ref.mounted) {
        state = state.copyWith(requesting: false);
      }
    }
  }

  /// After "I've confirmed my address": fetches fresh tokens, so that the
  /// `email_verified` claim the server reads is current, and asks again.
  Future<RequestAnalysisOutcome> recheckEmailAndAskCoach({
    String? languageCode,
  }) async {
    try {
      await ref.read(authRepositoryProvider).forceRefresh();
    } on AuthException catch (e) {
      return AnalysisRequestFailed(
        e.kind == AuthErrorKind.network
            ? const ApiNetworkError()
            : const ApiServerError(),
      );
    }
    if (!ref.mounted) {
      return const AnalysisRequestFailed(ApiNetworkError());
    }
    return askCoach(languageCode: languageCode);
  }

  /// Deletes the game on the server and in the cache.
  Future<DeleteGameOutcome> delete() async {
    final owner = _owner;
    if (owner == null || state.deleting) {
      return const DeleteGameFailed(ApiUnauthenticated());
    }
    state = state.copyWith(deleting: true);
    try {
      return await ref.read(gamesRepositoryProvider).delete(owner, gameId);
    } finally {
      if (ref.mounted) {
        state = state.copyWith(deleting: false);
      }
    }
  }
}
