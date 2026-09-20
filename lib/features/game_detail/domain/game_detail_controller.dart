// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/analytics/analytics.dart';
import 'package:bogner_chess/core/api/analysis_api.dart';
import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/auth/auth_providers.dart';
import 'package:bogner_chess/core/auth/auth_repository.dart';
import 'package:bogner_chess/core/device/device_id.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/features/analysis_status/domain/job_tracker_providers.dart';
import 'package:bogner_chess/features/analysis_status/domain/mobile_config_provider.dart';
import 'package:bogner_chess/features/library/domain/games_repository.dart';
import 'package:bogner_chess/features/library/domain/owner.dart';
import 'package:bogner_chess/features/usage/domain/usage_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'final_position.dart';

const _log = Log('game');

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

  /// Asks for the analysis of this game. An accepted job goes to the job
  /// tracker; every other outcome is the screen's to explain. The AI consent
  /// round trip is the screen's as well (it needs the navigator): it calls
  /// this method again after the user agreed.
  Future<RequestAnalysisOutcome> requestAnalysis() async {
    if (state.requesting) {
      return const AnalysisRequestFailed(ApiNetworkError());
    }
    state = state.copyWith(requesting: true);
    final analytics = ref.read(analyticsProvider);
    try {
      String? deviceId;
      try {
        deviceId = await ref.read(deviceIdProvider.future);
      } on Object catch (e) {
        // The request is worth more than the per-device rate limit.
        _log.warning('no device id', error: e);
      }
      final language = coachLanguageOf(
        ref.read(mobileConfigProvider).value,
        PlatformDispatcher.instance.locale.languageCode,
      );
      final outcome = await ref
          .read(analysisApiProvider)
          .request(gameId: gameId, language: language, deviceId: deviceId);
      if (!ref.mounted) {
        return outcome;
      }
      switch (outcome) {
        case AnalysisAccepted(:final job):
          analytics.track(AnalyticsEvents.analysisRequested, {
            'language': language,
            'source': 'game_detail',
          });
          await ref.read(jobTrackerProvider).track(job);
        case AnalysisLimitReached(:final window):
          analytics.track(AnalyticsEvents.analysisLimitHit, {
            'window': window.name,
          });
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
  Future<RequestAnalysisOutcome> recheckEmailAndRequest() async {
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
    return requestAnalysis();
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
