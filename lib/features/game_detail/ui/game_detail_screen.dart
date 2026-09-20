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
import 'package:bogner_chess/features/analysis_status/domain/job_tracker_providers.dart';
import 'package:bogner_chess/features/library/domain/games_repository.dart';
import 'package:bogner_chess/features/library/domain/library_models.dart';
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
    final tracked = ref.watch(trackedJobsProvider)[gameId];
    final job = newestJob(tracked, game.latestJob);
    final status = statusOfGame(hasAnalysis: game.hasAnalysis, job: job);
    final fen = state.finalFen;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.read(gameDetailControllerProvider(gameId).notifier).reload(),
          ref.read(jobTrackerProvider).refreshNow(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          _Header(game: game, plyCount: state.plyCount),
          const SizedBox(height: AppSpacing.md),
          _AnalysisCard(
            gameId: gameId,
            status: status,
            job: job,
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

/// The way to the analysis, by state: request it, watch the job, open the
/// result, or try again after a failure.
class _AnalysisCard extends ConsumerWidget {
  const _AnalysisCard({
    required this.gameId,
    required this.status,
    required this.job,
    required this.requesting,
  });

  final String gameId;
  final LibraryStatus status;
  final JobInfo? job;
  final bool requesting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    void request() => runAnalysisRequest(context, ref, gameId);

    final List<Widget> children = switch (status) {
      LibraryStatus.analysing => [
        _CardTitle(
          icon: Icons.hourglass_top,
          text: job?.status == JobStatus.queued
              ? l10n.gameDetailQueuedTitle
              : l10n.gameDetailRunningTitle,
        ),
        const SizedBox(height: AppSpacing.md),
        const LinearProgressIndicator(),
        const SizedBox(height: AppSpacing.md),
        Text(_progressText(l10n, job), style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.gameDetailLeaveHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      LibraryStatus.analysisReady => [
        _CardTitle(
          icon: Icons.check_circle_outline,
          color: colors.success,
          text: l10n.gameDetailReadyMessage,
        ),
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
      LibraryStatus.analysisFailed => [
        _CardTitle(
          icon: Icons.error_outline,
          color: theme.colorScheme.error,
          text: l10n.gameDetailFailedTitle,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.gameDetailFailedMessage, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        Identified(
          GameDetailIds.retryAnalysis,
          child: FilledButton.icon(
            onPressed: requesting ? null : request,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.commonRetry),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const UsageSummary(),
      ],
      _ => [
        Text(l10n.gameDetailAnalyseHint, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        Identified(
          GameDetailIds.analyse,
          child: FilledButton.icon(
            onPressed: requesting ? null : request,
            icon: requesting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(l10n.gameDetailAnalyse),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const UsageSummary(),
      ],
    };

    return Semantics(
      identifier: status == LibraryStatus.analysing
          ? GameDetailIds.jobCard
          : null,
      container: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  static String _progressText(AppLocalizations l10n, JobInfo? job) {
    if (job?.status == JobStatus.queued) {
      final ahead = job?.queuePosition ?? 0;
      return ahead <= 0
          ? l10n.gameDetailQueuedNext
          : l10n.gameDetailQueuedPosition(ahead);
    }
    // Stage names are the server's; anything unknown gets the neutral text.
    return switch (job?.stage) {
      'engine' => l10n.gameDetailStageEngine,
      'coach' => l10n.gameDetailStageCoach,
      _ => l10n.gameDetailStageOther,
    };
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
