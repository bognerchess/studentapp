// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/analytics/analytics.dart';
import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/connectivity/connectivity.dart';
import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/pgn/pgn_import.dart';
import 'package:bogner_chess/features/entry/domain/entry_result.dart';
import 'package:bogner_chess/features/import/domain/import_result.dart';
import 'package:bogner_chess/features/new_game/domain/new_game_save_request.dart';
import 'package:bogner_chess/features/submit_queue/domain/draft_meta.dart';
import 'package:bogner_chess/features/submit_queue/domain/submit_queue_providers.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The glue of the new-game flow: entry or import → metadata → the submit
/// queue → the library. The screens know nothing of each other; the router
/// hands their callbacks to this class.
///
/// Nothing here waits for the upload. "Save" writes to the database, kicks
/// the queue and leaves; the only network call is the question whether the
/// AI consent is on record, and that one gives up after [consentTimeout].
class NewGameFlow {
  NewGameFlow(this._ref);

  static const Duration consentTimeout = Duration(seconds: 4);

  static const _log = Log('new-game');

  final Ref _ref;

  /// The account the server has confirmed the consent for. It is not asked
  /// again in this session. (Withdrawing happens in Settings, and the queue
  /// copes with a refusal anyway.)
  String? _consentOnRecordFor;

  String? get _sub => switch (_ref.read(authStateProvider)) {
    SignedIn(:final sub) => sub,
    SignedOut() => null,
  };

  Analytics get _analytics => _ref.read(analyticsProvider);

  String? get _accountName => switch (_ref.read(authStateProvider)) {
    SignedIn(:final name) => name,
    SignedOut() => null,
  };

  /// "Enter moves" on the New game tab.
  void startEntry(BuildContext context) {
    _analytics.track(AnalyticsEvents.gameEntryStarted, const {
      'source': 'board',
    });
    context.go(AppRoutes.newGameEntry);
  }

  /// Done on the entry screen. The draft is flushed at this point.
  Future<void> entryDone(BuildContext context, EntryResult result) async {
    _analytics.track(AnalyticsEvents.gameEntryCompleted, {
      'source': 'board',
      'ply_count': result.plyCount,
    });
    GameMetadata? stored;
    try {
      final meta = await _ref.read(submitQueueProvider).metaOf(result.draftId);
      if (meta != null && meta.metadata != const GameMetadata()) {
        stored = meta.metadata;
      }
    } on Object catch (error, stackTrace) {
      _log.warning('draft meta', error: error, stackTrace: stackTrace);
    }
    if (!context.mounted) return;
    unawaited(
      context.push(
        AppRoutes.newGameMetadata,
        extra: NewGameSaveRequest.entry(
          result,
          defaultPlayerName: _accountName,
          stored: stored,
        ),
      ),
    );
  }

  /// Continue on the import screen.
  void importDone(BuildContext context, ImportResult result) {
    _analytics.track(AnalyticsEvents.pgnImported, {
      'origin': result.origin.name,
      'ply_count': result.plyCount,
      'variations_removed': result.warnings.contains(
        PgnImportWarning.variationsRemoved,
      ),
      'comments_removed': result.warnings.contains(
        PgnImportWarning.commentsRemoved,
      ),
    });
    unawaited(
      context.push(
        AppRoutes.newGameMetadata,
        extra: NewGameSaveRequest.import(result, accountName: _accountName),
      ),
    );
  }

  /// "Save & analyse" ([analyse]) or "Save only" on the metadata screen.
  Future<void> save(
    BuildContext context,
    NewGameSaveRequest request,
    GameMetadata metadata, {
    required bool analyse,
  }) async {
    // Everything that needs the context is taken before the first await:
    // a document opened from outside may replace this screen at any time,
    // and the game is saved regardless.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final l10n = context.l10n;

    final online = await _ref.read(connectivityProvider).isOnline();
    var wantsAnalysis = analyse;
    if (analyse && online && context.mounted) {
      wantsAnalysis = await _ensureAiConsent(context);
    }

    final source = switch (request.import?.origin) {
      null => DraftSource.board,
      ImportOrigin.text => DraftSource.pgn,
      ImportOrigin.file => DraftSource.file,
      ImportOrigin.external => DraftSource.share,
    };
    final queue = _ref.read(submitQueueProvider);
    bool saved;
    try {
      if (request.entry case final entry?) {
        saved = await queue.enqueueEntry(
          draftId: entry.draftId,
          pgnMoves: entry.pgnMoves,
          metadata: metadata,
          orientation: entry.orientation,
          analyse: wantsAnalysis,
        );
      } else {
        final id = await queue.enqueueImport(
          movetext: request.import!.movetext,
          metadata: metadata,
          source: source,
          analyse: wantsAnalysis,
        );
        saved = id != null;
      }
    } on Object catch (error, stackTrace) {
      _log.error('save failed', error: error, stackTrace: stackTrace);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.newGameSaveFailed)));
      return;
    }

    if (saved) {
      _analytics.track(AnalyticsEvents.gameSubmitted, {
        'source': source.name,
        'analyse': wantsAnalysis,
        'ply_count': request.plyCount,
        'online': online,
      });
    }
    final message = !saved
        ? l10n.newGameAlreadySaved
        : !online
        ? l10n.newGameSavedOffline
        : analyse && !wantsAnalysis
        ? l10n.newGameSavedWithoutConsent
        : wantsAnalysis
        ? l10n.newGameSavedAnalysing
        : l10n.newGameSavedUploading;

    // On to the library. The New game tab forgets this flow by itself: its
    // screens sit on the root navigator, not in the tab (tested).
    router.go(AppRoutes.games);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Whether the analysis may be asked for. True when the consent is on
  /// record, when the user gives it now, and when the server cannot be asked
  /// (the queue finds out later and keeps the game either way). False only
  /// when the user was asked and did not agree.
  Future<bool> _ensureAiConsent(BuildContext context) async {
    final sub = _sub;
    if (sub == null || _consentOnRecordFor == sub) return true;
    try {
      final status = await _ref
          .read(legalApiProvider)
          .aiConsent()
          .timeout(consentTimeout);
      if (!status.required) {
        _consentOnRecordFor = sub;
        return true;
      }
    } on Object catch (error) {
      _log.info('consent state unknown (${error.runtimeType})');
      return true;
    }
    if (!context.mounted) return true;
    final accepted = await context.push<bool>(AppRoutes.consentAi);
    if (accepted ?? false) {
      _consentOnRecordFor = sub;
      return true;
    }
    return false;
  }
}

final newGameFlowProvider = Provider<NewGameFlow>(NewGameFlow.new);
