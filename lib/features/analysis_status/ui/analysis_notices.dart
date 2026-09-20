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

  void _listenTo(JobTracker tracker) {
    if (identical(tracker, _tracker)) {
      return;
    }
    _tracker = tracker;
    unawaited(_events?.cancel());
    _events = tracker.events.listen(_onEvent);
  }

  late final JobTrackerUiMounted _mounted;

  @override
  void initState() {
    super.initState();
    _mounted = ref.read(jobTrackerUiMountedProvider.notifier);
    // Providers must not change while the tree is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mounted.set(mounted: true);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    // The tracker stops polling; its timers must not outlive the UI.
    final notifier = _mounted;
    unawaited(Future.microtask(() => notifier.set(mounted: false)));
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

  @override
  Widget build(BuildContext context) {
    _listenTo(ref.watch(jobTrackerProvider));
    return widget.child;
  }
}
