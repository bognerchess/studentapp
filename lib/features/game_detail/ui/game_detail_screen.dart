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
            // with a stored engine analysis shows the strip rather than the
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

/// Where the pipeline of one game stands, and the one thing to do next.
///
/// The live workflow comes from the tracker while it is watching the game;
/// [summary] is what the library row remembered from an earlier session, so a
/// cold open shows the strip rather than the "Analyse" button. Without either
/// there is only [hasAnalysis], which says whether a coach document exists.
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

  /// The stage whose result is out of date, if any is: the moves changed
  /// under it, or an earlier stage ran again.
  AnalysisStage? get _staleStage {
    for (final stage in AnalysisStage.pipeline) {
      if (_stateOf(stage) == AnalysisStageState.stale) return stage;
    }
    return null;
  }

  AnalysisStage? get _failedStage {
    for (final stage in AnalysisStage.pipeline) {
      if (_stateOf(stage) == AnalysisStageState.failed) return stage;
    }
    return null;
  }

  AnalysisStage? get _activeStage {
    for (final stage in AnalysisStage.pipeline) {
      if (_stateOf(stage).isActive) return stage;
    }
    return null;
  }

  bool get _coachReady =>
      _stateOf(AnalysisStage.coaching) == AnalysisStageState.ready ||
      (!_known && hasAnalysis);

  bool get _deepReady =>
      _stateOf(AnalysisStage.deepEvaluation) == AnalysisStageState.ready;

  /// Something is stored that the review screen can already show.
  bool get _readable =>
      _coachReady ||
      AnalysisStage.engineStages.any(
        (s) => _stateOf(s) == AnalysisStageState.ready,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final controller = ref.read(gameDetailControllerProvider(gameId).notifier);

    void chain() => unawaited(runFreeChain(context, controller));

    // Do not gate this on the cached usage numbers, however tempting: only
    // the server knows the quota, and the server is what counts the pressure
    // on it. Its mutation writes the `analysis_limit_hit` event (once per
    // person per day, inside the quota lock) when it refuses, because the
    // client-side event proved unreliable. An app that stops asking at the
    // limit makes that metric read zero, which looks exactly like a product
    // nobody bumps into. `UsageSummary` below warns before the tap; the
    // refusal comes back typed and `_LimitSheet` explains it (LIM-2).
    void askCoach() => unawaited(runCoachRequest(context, controller));

    final failed = _failedStage;
    final stale = _staleStage;
    final active = _activeStage;

    final List<Widget> children;
    if (stale != null) {
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
            onPressed: requesting ? null : chain,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.gameDetailReanalyse),
          ),
        ),
      ];
    } else if (failed != null) {
      children = [
        _CardTitle(
          icon: Icons.error_outline,
          color: theme.colorScheme.error,
          text: l10n.gameDetailStepFailedTitle,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          stageFailureText(l10n, _failureCodeOf(failed)),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        _StageStrip(workflow: workflow, summary: summary),
        const SizedBox(height: AppSpacing.md),
        Identified(
          GameDetailIds.retryStage,
          child: FilledButton.icon(
            onPressed: requesting
                ? null
                : () => unawaited(runStageRetry(context, controller, failed)),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.gameDetailRetryStage),
          ),
        ),
        if (failed.usesModel) ...[
          const SizedBox(height: AppSpacing.sm),
          const UsageSummary(),
        ],
      ];
    } else if (active != null) {
      children = [
        _CardTitle(
          icon: Icons.hourglass_top,
          text: l10n.gameDetailRunningTitle,
        ),
        const SizedBox(height: AppSpacing.md),
        _StageStrip(workflow: workflow, summary: summary),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.gameDetailLeaveHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ];
    } else if (_coachReady) {
      // A finished analysis has nothing left to offer — except to whoever is
      // developing the coach's voice, who wants to read the new text in
      // place. Every run spends a quota, so only an account that has none to
      // spend is offered it. `_activeStage` is checked above this branch, so
      // the card turns into the strip as soon as the new run is published.
      final unlimited =
          ref.watch(usageProvider).value?.policy == UsagePolicy.unlimited;
      children = [
        _CardTitle(
          icon: Icons.check_circle_outline,
          color: colors.success,
          text: l10n.gameDetailReadyMessage,
        ),
        if (unlimited) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: Identified(
              GameDetailIds.rerunCoach,
              child: TextButton.icon(
                onPressed: requesting ? null : askCoach,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.gameDetailRerunCoach),
              ),
            ),
          ),
        ],
      ];
    } else if (_deepReady) {
      children = [
        _StageStrip(workflow: workflow, summary: summary),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.gameDetailAskCoachHint, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        Identified(
          GameDetailIds.askCoach,
          child: FilledButton.icon(
            onPressed: requesting ? null : askCoach,
            icon: const Icon(Icons.school_outlined),
            label: Text(l10n.gameDetailAskCoach),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const UsageSummary(),
      ];
    } else if (_readable) {
      // Stage 1 or 2 is stored and the chain has stopped: the eval graph and
      // the key positions are there to look at, and the rest can be resumed.
      children = [
        _StageStrip(workflow: workflow, summary: summary),
        const SizedBox(height: AppSpacing.md),
        Identified(
          GameDetailIds.analyse,
          child: FilledButton.icon(
            onPressed: requesting ? null : chain,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(l10n.gameDetailAnalyse),
          ),
        ),
      ];
    } else {
      children = [
        Text(l10n.gameDetailStagedHint, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        Identified(
          GameDetailIds.analyse,
          child: FilledButton.icon(
            onPressed: requesting ? null : chain,
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

  String? _failureCodeOf(AnalysisStage stage) =>
      workflow?.stageOf(stage)?.run?.failureCode;
}

/// The four stages of the pipeline, one row each: what it is, where it
/// stands, and a progress bar while it runs.
///
/// A deliberate reversal of the WP-26-28 decision not to show a progress bar:
/// back then there was one opaque job and a bar would have been a decoration.
/// Now each stage reports `progressDone` / `progressTotal`, so the bar shows
/// something real; a stage that reports nothing gets the indeterminate one,
/// which at least says "this is the step that is moving".
class _StageStrip extends StatelessWidget {
  const _StageStrip({required this.workflow, required this.summary});

  final AnalysisWorkflow? workflow;
  final GameWorkflowSummary? summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      identifier: GameDetailIds.stageStrip,
      container: true,
      label: l10n.gameDetailStageStripLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final stage in AnalysisStage.pipeline)
            _StageRow(
              stage: stage,
              state:
                  workflow?.stateOf(stage) ??
                  summary?.stateOf(stage) ??
                  AnalysisStageState.notRun,
              run: workflow?.stageOf(stage)?.run,
            ),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage, required this.state, this.run});

  final AnalysisStage stage;
  final AnalysisStageState state;
  final StageRunSummary? run;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final name = stageName(l10n, stage);
    final (icon, color) = switch (state) {
      AnalysisStageState.ready => (Icons.check_circle_outline, colors.success),
      AnalysisStageState.failed => (
        Icons.error_outline,
        theme.colorScheme.error,
      ),
      AnalysisStageState.stale => (Icons.history, colors.warning),
      AnalysisStageState.queued ||
      AnalysisStageState.running ||
      AnalysisStageState.unknown => (
        Icons.hourglass_top,
        theme.colorScheme.primary,
      ),
      AnalysisStageState.notRun => (
        Icons.radio_button_unchecked,
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    final progress = state == AnalysisStageState.running ? run?.progress : null;
    final text = switch (state) {
      AnalysisStageState.notRun => l10n.gameDetailStageStateNotRun,
      AnalysisStageState.queued => l10n.gameDetailStageStateWaiting,
      AnalysisStageState.running => _runningText(l10n),
      AnalysisStageState.ready => l10n.gameDetailStageStateReady,
      AnalysisStageState.stale => l10n.gameDetailStageStateStale,
      AnalysisStageState.failed => l10n.gameDetailStageStateFailed,
      AnalysisStageState.unknown => l10n.gameDetailStageStateWaiting,
    };
    return Semantics(
      identifier: GameDetailIds.stageRow(stage),
      container: true,
      label: l10n.gameDetailStageRowSemantics(name, text),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Both flexible: "Noch nicht gestartet" next to
                  // "Schlüsselstellungen" does not fit on an SE at text
                  // scale 1.3, and a fixed state column would clip it.
                  Expanded(
                    flex: 3,
                    child: Text(name, style: theme.textTheme.bodyMedium),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: Text(
                      text,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (state.isActive && state != AnalysisStageState.queued) ...[
                const SizedBox(height: AppSpacing.xs),
                LinearProgressIndicator(value: progress),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _runningText(AppLocalizations l10n) {
    final done = run?.progressDone;
    final total = run?.progressTotal;
    if (done != null && total != null && total > 0) {
      return l10n.gameDetailStageStateProgress(done, total);
    }
    return l10n.gameDetailStageStateRunning;
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
