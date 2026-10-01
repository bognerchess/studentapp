// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/analytics/analysis_analytics.dart';
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

  /// Analyses this game: one request, and the server runs the whole thing.
  ///
  /// It is the first analysis, the retry of a failed one and the "analyse
  /// again" after the moves changed, all three — the server queues whatever is
  /// missing and resumes where it stopped. Nothing here can be refused for
  /// quota: when a gate of the coach is closed the engine result is produced
  /// anyway and the answer carries `targetReason`, which the screen explains.
  ///
  /// [languageCode] is the language the app is showing (the coach writes in it
  /// when the server supports it); without one the device language is used.
  ///
  /// The request is always sent, also when the cached usage says the quota is
  /// gone: the server counts limit pressure when it refuses the coach
  /// (`analysis_limit_hit`, once per person per day), and a client that stops
  /// asking on its own would make that metric read zero. Show the numbers as a
  /// warning, never as a gate.
  Future<RequestAnalysisOutcome> analyse({String? languageCode}) async {
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
          .analyseGame(gameId, language: language);
      if (!ref.mounted) {
        return outcome;
      }
      switch (outcome) {
        case AnalysisAccepted(:final workflow):
          analytics.analysisRequested(source: 'game_detail');
          if (workflow?.targetStage == AnalysisStage.coaching) {
            analytics.coachRequested(language);
          }
          // `analysis_limit_hit` is not written here. The server writes it
          // when it decides not to ask the coach, inside the quota lock and
          // once per person per day; a client event would double-count and
          // would have to guess the window.
          await ref.read(workflowTrackerProvider).track(gameId);
        case AnalysisPrerequisiteMissing():
        case AnalysisLimitReached():
        case AnalysisQueueFull():
        case AnalysisRateLimited():
        case AnalysisEmailNotVerified():
        case AnalysisAiConsentRequired():
        case AnalysisRequestFailed():
          // `analyseGame` cannot answer with the quota, the queue cap, the
          // e-mail check or the consent; those arrive as `targetReason` above.
          // The cases stay because the outcome is shared with `runCoaching`.
          break;
      }
      // The coach may have been asked, so the numbers under the button may
      // have changed.
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

  /// Writes the coach's text again over a finished analysis.
  ///
  /// Only for an account whose policy is unlimited: every run spends a quota,
  /// and this is here for developing the coach's voice, not for the player. It
  /// is the one place left that starts a single stage.
  Future<RequestAnalysisOutcome> rerunCoach({String? languageCode}) async {
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
        case AnalysisAccepted():
          analytics.coachRequested(language);
          await ref.read(workflowTrackerProvider).track(gameId);
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
  /// `email_verified` claim the server reads is current, and analyses again.
  /// The second request is what gets the coach, which the first one had to go
  /// without.
  Future<RequestAnalysisOutcome> recheckEmailAndAnalyse({
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
    return analyse(languageCode: languageCode);
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
