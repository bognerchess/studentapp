// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:math' as math;

import 'package:bogner_chess/core/analytics/analytics.dart';
import 'package:bogner_chess/core/chess/board_thumbnail.dart';
import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/core/ui/widgets/app_scaffold.dart';
import 'package:bogner_chess/core/ui/widgets/empty_state.dart';
import 'package:bogner_chess/core/ui/widgets/error_retry.dart';
import 'package:bogner_chess/features/analysis_status/domain/workflow_tracker_providers.dart';
import 'package:bogner_chess/features/library/domain/games_repository.dart';
import 'package:bogner_chess/features/usage/usage.dart';
import 'package:bogner_chess/router.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/game_detail_controller.dart';
import 'analysis_request_flow.dart';
import 'game_detail_ids.dart';
import 'game_texts.dart';

/// One game of the library (`/games/:id`): who played, how it ended, the
/// final position, and the way to its analysis (AN-1, LIM-2). Read-only: the
/// API has no mutation to change a stored game.
class GameDetailScreen extends ConsumerWidget {
  const GameDetailScreen({required this.gameId, super.key});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(gameDetailControllerProvider(gameId));
    final game = state.game;

    return AppScaffold(
      title: l10n.libraryGameTitle,
      actions: [
        if (game != null)
          Identified(
            GameDetailIds.delete,
            child: IconButton(
              tooltip: l10n.gameDetailDelete,
              onPressed: state.busy ? null : () => _delete(context, ref),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
      ],
      body: switch ((game, state)) {
        (null, GameDetailState(notFound: true)) => EmptyState(
          icon: Icons.search_off,
          title: l10n.gameDetailNotFoundTitle,
          message: l10n.gameDetailNotFoundMessage,
        ),
        (null, GameDetailState(loadError: final _?)) => ErrorRetry(
          onRetry: ref
              .read(gameDetailControllerProvider(gameId).notifier)
              .reload,
        ),
        (null, _) => const Center(child: CircularProgressIndicator()),
        (final game?, _) => _Body(gameId: gameId, game: game, state: state),
      },
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.libraryDeleteTitle),
        content: Text(l10n.libraryDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.libraryDeleteCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.libraryDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref
        .read(gameDetailControllerProvider(gameId).notifier)
        .delete();
    messenger.hideCurrentSnackBar();
    switch (outcome) {
      case GameDeleted():
        messenger.showSnackBar(SnackBar(content: Text(l10n.libraryDeleted)));
        if (context.mounted) {
          context.canPop() ? context.pop() : context.go(AppRoutes.games);
        }
      case DeleteGameFailed():
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.libraryDeleteFailed)),
        );
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.gameId, required this.game, required this.state});

  final String gameId;
  final GameSummary game;
  final GameDetailState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflow = ref.watch(trackedWorkflowsProvider)[gameId];
    final fen = state.finalFen;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.read(gameDetailControllerProvider(gameId).notifier).reload(),
          ref.read(workflowTrackerProvider).refreshNow(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          _Header(game: game, plyCount: state.plyCount),
          const SizedBox(height: AppSpacing.md),
          _AnalysisCard(
            gameId: gameId,
            hasAnalysis: game.hasAnalysis,
            workflow: workflow,
            // What the cached row remembers, so that a cold open of a game
            // with a stored analysis shows "Open analysis" rather than the
            // "Analyse" button.
            summary: game.workflow,
            requesting: state.requesting,
          ),
          if (fen != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.l10n.gameDetailFinalPosition,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            LayoutBuilder(
              builder: (context, constraints) => Center(
                child: BoardThumbnail(
                  fen: fen,
                  size: math.min(constraints.maxWidth, 340),
                  orientation: game.playerColor == PlayerColor.black
                      ? Side.black
                      : Side.white,
                  semanticLabel: context.l10n.gameDetailFinalPosition,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.game, required this.plyCount});

  final GameSummary game;
  final int? plyCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final result = resultLine(l10n, game.result, game.playerColor);
    final plies = plyCount;
    final facts = <(IconData, String)>[
      if (game.playedDate case final date?)
        (Icons.event_outlined, formatGameDate(l10n, date)),
      if (game.eventName case final event?)
        (Icons.emoji_events_outlined, event),
      if (game.timeControl case final control?)
        (Icons.timer_outlined, timeControlText(l10n, control)),
      if (plies != null && plies > 0)
        (Icons.format_list_numbered, l10n.gameDetailMoves((plies + 1) ~/ 2)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PlayerLine(
          isWhite: true,
          name: game.whiteName ?? l10n.libraryWhite,
          rating: game.whiteRating,
          isUser: game.playerColor == PlayerColor.white,
        ),
        const SizedBox(height: AppSpacing.xs),
        _PlayerLine(
          isWhite: false,
          name: game.blackName ?? l10n.libraryBlack,
          rating: game.blackRating,
          isUser: game.playerColor == PlayerColor.black,
        ),
        if (result != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(result, style: theme.textTheme.titleMedium),
        ],
        if (facts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          for (final (icon, text) in facts)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _PlayerLine extends StatelessWidget {
  const _PlayerLine({
    required this.isWhite,
    required this.name,
    required this.rating,
    required this.isUser,
  });

  final bool isWhite;
  final String name;
  final int? rating;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Row(
      children: [
        // A disc with an outline reads in both themes (see WP-21).
        ExcludeSemantics(
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isWhite ? Colors.white : Colors.black,
              border: Border.all(color: theme.colorScheme.outline),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: isUser ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (rating != null)
                  TextSpan(
                    text: '  $rating',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            semanticsLabel:
                '${isWhite ? l10n.libraryWhite : l10n.libraryBlack}: $name'
                '${rating == null ? '' : ', $rating'}',
          ),
        ),
      ],
    );
  }
}

/// Where the analysis of one game stands, and the one thing to do next.
///
/// Five states and no more, because the user is not supposed to know that
/// there are steps: nothing yet, running, ready, out of date, failed. The live
/// workflow comes from the tracker while it is watching the game; [summary] is
/// what the library row remembered from an earlier session, so a cold open
/// shows "Open analysis" rather than the button. Without either there is only
/// [hasAnalysis], which says whether a coach document exists.
class _AnalysisCard extends ConsumerWidget {
  const _AnalysisCard({
    required this.gameId,
    required this.hasAnalysis,
    required this.workflow,
    required this.summary,
    required this.requesting,
  });

  final String gameId;

  /// What the server says about a stored coach document. The only thing left
  /// to go on when neither the tracker nor the library row knows the pipeline.
  final bool hasAnalysis;
  final AnalysisWorkflow? workflow;
  final GameWorkflowSummary? summary;
  final bool requesting;

  /// The state of every stage, from the best source there is.
  AnalysisStageState _stateOf(AnalysisStage stage) =>
      workflow?.stateOf(stage) ??
      summary?.stateOf(stage) ??
      AnalysisStageState.notRun;

  bool get _known => workflow != null || summary != null;

  /// The one state of the analysis: the server's own word while anybody knows
  /// it, else what a stored coach document implies.
  AnalysisWorkflowState get _state {
    final state = workflow?.workflowState ?? summary?.workflowState;
    if (state != null) {
      return state;
    }
    return hasAnalysis
        ? AnalysisWorkflowState.ready
        : AnalysisWorkflowState.idle;
  }

  bool get _coachReady =>
      _stateOf(AnalysisStage.coaching) == AnalysisStageState.ready ||
      (!_known && hasAnalysis);

  /// Something is stored that the review screen can already show, so the
  /// review can be opened while the rest is still being worked out.
  bool get _readable =>
      _coachReady ||
      AnalysisStage.engineStages.any(
        (s) => _stateOf(s) == AnalysisStageState.ready,
      );

  /// Why there is no coach text, when the server said so.
  AnalysisTargetReason? get _targetReason =>
      workflow?.targetReason ?? summary?.targetReason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final controller = ref.read(gameDetailControllerProvider(gameId).notifier);

    // Do not gate this on the cached usage numbers, however tempting: only
    // the server knows the quota, and the server is what counts the pressure
    // on it. Its mutation writes the `analysis_limit_hit` event (once per
    // person per day, inside the quota lock) when it decides not to ask the
    // coach, because the client-side event proved unreliable. An app that
    // stops asking at the limit makes that metric read zero, which looks
    // exactly like a product nobody bumps into. `UsageSummary` warns before
    // the tap; afterwards `targetReason` says what happened (LIM-2).
    void analyse() => unawaited(runAnalyse(context, controller));

    final List<Widget> children;
    switch (_state) {
      case AnalysisWorkflowState.stale:
        children = [
          _CardTitle(
            icon: Icons.history,
            color: colors.warning,
            text: l10n.gameDetailStaleTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.gameDetailStaleMessage, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          Identified(
            GameDetailIds.reanalyse,
            child: FilledButton.icon(
              onPressed: requesting ? null : analyse,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.gameDetailReanalyse),
            ),
          ),
        ];
      case AnalysisWorkflowState.failed:
        children = [
          _CardTitle(
            icon: Icons.error_outline,
            color: theme.colorScheme.error,
            text: l10n.gameDetailFailedTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.gameDetailFailedMessage,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Identified(
            GameDetailIds.retryAnalysis,
            child: FilledButton.icon(
              onPressed: requesting ? null : analyse,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.gameDetailTryAgain),
            ),
          ),
        ];
      case AnalysisWorkflowState.analysing:
        children = [
          _CardTitle(
            icon: Icons.hourglass_top,
            text: l10n.gameDetailRunningTitle,
          ),
          const SizedBox(height: AppSpacing.md),
          _Progress(
            value: workflow?.progress,
            phase: _phaseText(l10n),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.gameDetailLeaveHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ];
      case AnalysisWorkflowState.ready:
        children = [
          _CardTitle(
            icon: Icons.check_circle_outline,
            color: colors.success,
            text: l10n.gameDetailReadyMessage,
          ),
          if (_targetReason case final reason? when !_coachReady) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.gameDetailNoCoach(targetReasonText(l10n, reason)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const UsageSummary(textAlign: TextAlign.start),
          ],
          if (_coachReady && _isUnlimited(ref)) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: Identified(
                GameDetailIds.rerunCoach,
                child: TextButton.icon(
                  onPressed: requesting
                      ? null
                      : () => unawaited(runRerunCoach(context, controller)),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.gameDetailRerunCoach),
                ),
              ),
            ),
          ],
        ];
      case AnalysisWorkflowState.idle:
      case AnalysisWorkflowState.unknown:
        children = [
          Text(l10n.gameDetailAnalyseIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          const UsageSummary(textAlign: TextAlign.start),
          const SizedBox(height: AppSpacing.md),
          Identified(
            GameDetailIds.analyse,
            child: FilledButton.icon(
              onPressed: requesting ? null : analyse,
              icon: requesting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(l10n.gameDetailAnalyse),
            ),
          ),
        ];
    }

    return Semantics(
      identifier: GameDetailIds.workflowCard,
      container: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...children,
              // Shown next to the progress bar as well: the engine result is
              // in the cache long before the coach has written, and reading it
              // is the whole point of opening early.
              if (_readable) ...[
                const SizedBox(height: AppSpacing.md),
                Identified(
                  GameDetailIds.openAnalysis,
                  child: FilledButton.icon(
                    onPressed: () {
                      ref.read(analyticsProvider).track(
                        AnalyticsEvents.analysisReadyOpened,
                        {'source': 'game_detail'},
                      );
                      unawaited(context.push(AppRoutes.gameReview(gameId)));
                    },
                    icon: const Icon(Icons.school_outlined),
                    label: Text(l10n.gameDetailOpenAnalysis),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _isUnlimited(WidgetRef ref) =>
      ref.watch(usageProvider).value?.policy == UsagePolicy.unlimited;

  /// What the app says it is doing. Named after what the user gets, not after
  /// the stage that is running.
  String _phaseText(AppLocalizations l10n) => switch (_runningStage) {
    AnalysisStage.deepEvaluation => l10n.gameDetailPhaseCritical,
    AnalysisStage.coaching => l10n.gameDetailPhaseCoach,
    // Stages 1 and 2, a stage this build does not know, and the moment between
    // two stages, where nothing is running yet.
    _ => l10n.gameDetailPhaseReading,
  };

  AnalysisStage? get _runningStage {
    for (final stage in AnalysisStage.pipeline) {
      if (_stateOf(stage).isActive) return stage;
    }
    return null;
  }
}

/// How far the analysis has come, with one line saying what is happening.
///
/// Determinate whenever the server reports a number; a server that does not
/// say gets the indeterminate bar, which at least says something is moving.
class _Progress extends StatelessWidget {
  const _Progress({required this.value, required this.phase});

  final double? value;
  final String phase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: GameDetailIds.progress,
      container: true,
      label: phase,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: value),
            const SizedBox(height: AppSpacing.sm),
            Text(
              phase,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: color ?? theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: theme.textTheme.titleMedium)),
      ],
    );
  }
}
