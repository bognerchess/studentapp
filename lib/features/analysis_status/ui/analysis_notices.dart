// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/analytics/analytics.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/features/library/domain/games_repository.dart';
import 'package:bogner_chess/features/library/domain/owner.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/job_tracker_providers.dart';
import '../domain/workflow_tracker_providers.dart';

/// Tells the user, on whatever screen is showing, that an analysis has
/// finished ("Analysis ready", with a button that opens the review) or has
/// failed. It sits in `MaterialApp.builder` like `IncomingLinkNotices`, and
/// it is what creates the job tracker at start-up.
///
/// Nothing is shown for the game whose own screen is open: that screen
/// changes in place.
class AnalysisNotices extends ConsumerStatefulWidget {
  const AnalysisNotices({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AnalysisNotices> createState() => _AnalysisNoticesState();
}

class _AnalysisNoticesState extends ConsumerState<AnalysisNotices> {
  StreamSubscription<JobTrackerEvent>? _events;
  JobTracker? _tracker;

  StreamSubscription<WorkflowEvent>? _workflowEvents;
  WorkflowTracker? _workflowTracker;

  void _listenTo(JobTracker tracker) {
    if (identical(tracker, _tracker)) {
      return;
    }
    _tracker = tracker;
    unawaited(_events?.cancel());
    _events = tracker.events.listen(_onEvent);
  }

  void _listenToWorkflows(WorkflowTracker tracker) {
    if (identical(tracker, _workflowTracker)) {
      return;
    }
    _workflowTracker = tracker;
    unawaited(_workflowEvents?.cancel());
    _workflowEvents = tracker.events.listen(_onWorkflowEvent);
  }

  late final JobTrackerUiMounted _mounted;
  late final WorkflowTrackerUiMounted _workflowsMounted;

  @override
  void initState() {
    super.initState();
    _mounted = ref.read(jobTrackerUiMountedProvider.notifier);
    _workflowsMounted = ref.read(workflowTrackerUiMountedProvider.notifier);
    // Providers must not change while the tree is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mounted.set(mounted: true);
        _workflowsMounted.set(mounted: true);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    unawaited(_workflowEvents?.cancel());
    // The trackers stop polling; their timers must not outlive the UI.
    final notifier = _mounted;
    final workflows = _workflowsMounted;
    unawaited(
      Future.microtask(() {
        notifier.set(mounted: false);
        workflows.set(mounted: false);
      }),
    );
    super.dispose();
  }

  bool _isShowing(String gameId) {
    final config = ref.read(routerProvider).routerDelegate.currentConfiguration;
    final locations = {
      config.uri.path,
      if (config.matches.isNotEmpty) config.last.matchedLocation,
    };
    return locations.contains(AppRoutes.game(gameId)) ||
        locations.contains(AppRoutes.gameReview(gameId));
  }

  Future<void> _onEvent(JobTrackerEvent event) async {
    if (!mounted || _isShowing(event.gameId)) {
      return;
    }
    final owner = ref.read(currentOwnerProvider);
    final game = owner == null
        ? null
        : await ref.read(gamesRepositoryProvider).cached(owner, event.gameId);
    if (!mounted) {
      return;
    }
    final l10n = context.l10n;
    final router = ref.read(routerProvider);
    final opponent = game?.displayOpponentName;
    // `persist` defaults to `action != null`, which would make [duration]
    // a decoration: the notice would sit over the tab bar until somebody
    // tapped it, and every snack bar raised afterwards would wait behind it
    // for the rest of the session. It is news, not a decision to take.
    final snackBar = switch (event) {
      AnalysisReadyEvent() => SnackBar(
        content: Text(
          opponent == null
              ? l10n.analysisNoticeReady
              : l10n.analysisNoticeReadyOpponent(opponent),
        ),
        duration: const Duration(seconds: 8),
        persist: false,
        action: SnackBarAction(
          label: l10n.analysisNoticeOpen,
          onPressed: () {
            ref.read(analyticsProvider).track(
              AnalyticsEvents.analysisReadyOpened,
              {'source': 'banner'},
            );
            unawaited(router.push(AppRoutes.gameReview(event.gameId)));
          },
        ),
      ),
      AnalysisFailedEvent() => SnackBar(
        content: Text(l10n.analysisNoticeFailed),
        duration: const Duration(seconds: 8),
        persist: false,
        action: SnackBarAction(
          label: l10n.analysisNoticeView,
          onPressed: () => unawaited(router.push(AppRoutes.game(event.gameId))),
        ),
      ),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  /// The staged pipeline's news. Stages 1 and 2 say nothing: the card and the
  /// review banner fill in where the user can see them, and a snack bar per
  /// stage would be four interruptions per game. What is worth saying is that
  /// there is something to read (the deep evaluation, the coach), and that
  /// the pipeline stopped.
  Future<void> _onWorkflowEvent(WorkflowEvent event) async {
    if (!mounted || _isShowing(event.gameId)) {
      return;
    }
    final String text;
    final String? action;
    final bool toReview;
    switch (event) {
      case StageReadyEvent(:final stage):
        switch (stage) {
          case AnalysisStage.coaching:
            await _onEvent(AnalysisReadyEvent(event.gameId));
            return;
          case AnalysisStage.deepEvaluation:
            final opponent = await _opponentOf(event.gameId);
            if (!mounted) {
              return;
            }
            final l10n = context.l10n;
            text = opponent == null
                ? l10n.analysisNoticeEngineReady
                : l10n.analysisNoticeEngineReadyOpponent(opponent);
            action = l10n.analysisNoticeOpen;
            toReview = true;
          case AnalysisStage.baseEvaluation:
          case AnalysisStage.baseClassification:
          case AnalysisStage.unknown:
            return;
        }
      case StageFailedEvent():
        text = context.l10n.analysisNoticeStageFailed;
        action = context.l10n.analysisNoticeView;
        toReview = false;
      case WorkflowStaleEvent():
        text = context.l10n.analysisNoticeStale;
        action = context.l10n.analysisNoticeView;
        toReview = false;
    }
    if (!mounted) {
      return;
    }
    final router = ref.read(routerProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 8),
          persist: false,
          action: SnackBarAction(
            label: action,
            onPressed: () {
              if (toReview) {
                ref.read(analyticsProvider).track(
                  AnalyticsEvents.analysisReadyOpened,
                  {'source': 'banner'},
                );
              }
              unawaited(
                router.push(
                  toReview
                      ? AppRoutes.gameReview(event.gameId)
                      : AppRoutes.game(event.gameId),
                ),
              );
            },
          ),
        ),
      );
  }

  Future<String?> _opponentOf(String gameId) async {
    final owner = ref.read(currentOwnerProvider);
    if (owner == null) {
      return null;
    }
    final game = await ref.read(gamesRepositoryProvider).cached(owner, gameId);
    return game?.displayOpponentName;
  }

  @override
  Widget build(BuildContext context) {
    // Both trackers are created here, so both start polling at app start and
    // resume what an app kill interrupted. TODO(WP-60 B12): the job tracker
    // and its half of this widget go when the whole-game path does.
    _listenTo(ref.watch(jobTrackerProvider));
    _listenToWorkflows(ref.watch(workflowTrackerProvider));
    return widget.child;
  }
}
