// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:math' as math;

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/analysis/analysis_view.dart';
import 'package:bogner_chess/core/chess/board_theme_preference.dart';
import 'package:bogner_chess/core/chess/board_view.dart';
import 'package:bogner_chess/core/chess/san_localizer.dart';
import 'package:bogner_chess/core/l10n/board_labels.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/core/ui/widgets/error_retry.dart';
import 'package:bogner_chess/features/analysis_status/domain/workflow_tracker_providers.dart';
import 'package:bogner_chess/features/game_detail/game_detail.dart';
import 'package:bogner_chess/features/usage/usage.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/review_board.dart';
import '../domain/review_controller.dart';
import '../domain/review_repository.dart';
import 'coach_tab.dart';
import 'eval_graph.dart';
import 'moves_tab.dart';
import 'review_colors.dart';
import 'review_controls.dart';
import 'review_ids.dart';
import 'review_l10n.dart';
import 'summary_tab.dart';

/// The review screen of one analysed game (AN-3 to AN-7): the board, the
/// evaluation graph, and below them the coach, the moves and the summary.
///
/// The coach is the star and the engine is its evidence: the screen opens on
/// the coach tab, the prominent buttons and a swipe move between the moments
/// the coach picked, and evaluations appear in words.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key, required this.gameId});

  /// The server id of the game, from the route `/games/:id/review`.
  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final data = ref.watch(reviewDataProvider(gameId));
    void retry() => ref.invalidate(reviewDataProvider(gameId));

    // A stage that landed is a document with more in it — or, on a screen
    // that was opened before the first one was stored, the first document
    // there is. This listen sits here, above every state of the screen: in
    // the body it would only run once something had loaded, and a review
    // opened while the engine was still on stage 1 would stay on "nothing
    // available" although the assembly arrived seconds later.
    //
    // The run ids are compared as one string, because two equal maps are not
    // `==` and the tracker hands over a new map on every poll.
    ref.listen(
      trackedWorkflowsProvider.select(
        (workflows) => _readyRunIds(workflows[gameId]),
      ),
      (previous, next) {
        if (previous != next) {
          ref.invalidate(reviewDataProvider(gameId));
        }
      },
    );

    // A document that is being reloaded — a stage landed, so there is more to
    // show — keeps the screen up. Only a load with nothing to show at all
    // falls back to the skeleton, or the reader would watch it flash three
    // times while the pipeline runs.
    final loaded = data is AsyncError<ReviewData> ? null : data.value;
    return switch (loaded) {
      final value? when value.result is! AnalysisInvalid => _ReviewBody(
        gameId: gameId,
      ),
      final _? => _Frame(
        child: ErrorRetry(message: l10n.reviewInvalidMessage, onRetry: retry),
      ),
      null => switch (data) {
        AsyncError() => _Frame(child: ErrorRetry(onRetry: retry)),
        _ => const _Frame(child: _Skeleton()),
      },
    };
  }

  /// The ready run ids as one comparable string; null when no pipeline of
  /// this game is being watched.
  static String? _readyRunIds(AnalysisWorkflow? workflow) {
    if (workflow == null) return null;
    final parts = [
      for (final MapEntry(:key, :value) in workflow.readyRunIds.entries)
        '${key.name}:$value',
    ]..sort();
    return parts.join(',');
  }
}

/// App bar and safe area for the states without a document.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.reviewTitle)),
      body: SafeArea(child: child),
    );
  }
}

/// The shape of the screen while the analysis loads. Static on purpose: a
/// cached analysis is there within a frame or two.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget block({double? height, double? width}) => Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    );
    return Semantics(
      label: context.l10n.reviewLoading,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final board = _boardSize(constraints, fixed: 150);
          return Column(
            children: [
              SizedBox.square(
                dimension: board,
                child: ColoredBox(color: scheme.surfaceContainerHigh),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      block(height: EvalGraph.defaultHeight),
                      const SizedBox(height: AppSpacing.md),
                      block(height: 20, width: 180),
                      const SizedBox(height: AppSpacing.sm),
                      Flexible(child: block(height: 64)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The height the panel below the board is guaranteed: 150 points on the
/// smallest iPhone, growing with the screen up to what a typical coach
/// comment needs to be read without scrolling.
double _minPanelHeight(double bodyHeight) =>
    (150 + (bodyHeight - 590) * 0.4).clamp(150.0, 220.0);

/// The board is as wide as the screen unless the panel below needs the
/// height: the coach's text matters more than the last few points of board.
/// Then it shrinks, down to a limit.
double _boardSize(BoxConstraints constraints, {required double fixed}) {
  final byHeight =
      constraints.maxHeight - fixed - _minPanelHeight(constraints.maxHeight);
  return math.max(
    math.min(constraints.maxWidth, byHeight),
    math.min(constraints.maxWidth, 200),
  );
}

class _ReviewBody extends ConsumerStatefulWidget {
  const _ReviewBody({required this.gameId});

  final String gameId;

  @override
  ConsumerState<_ReviewBody> createState() => _ReviewBodyState();
}

class _ReviewBodyState extends ConsumerState<_ReviewBody> {
  static const BoardTheme _boardTheme = BoardTheme();

  @override
  void initState() {
    super.initState();
    // Without this the first board has no pieces for a frame.
    unawaited(precacheBoardTheme(_boardTheme).catchError((Object _) {}));
  }

  /// The coaching stage is started where it is explained: `game_detail` owns
  /// the quota, e-mail and consent sheets, and reaches them through its
  /// feature barrel.
  void _askCoach() {
    final controller = ref.read(
      gameDetailControllerProvider(widget.gameId).notifier,
    );
    unawaited(runCoachRequest(context, controller));
  }

  /// A failed step runs again: the free chain, which the server resumes at
  /// whatever stage it stopped on.
  void _retryStage() {
    final controller = ref.read(
      gameDetailControllerProvider(widget.gameId).notifier,
    );
    unawaited(runFreeChain(context, controller));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Keeps the game screen's controller alive for as long as this screen is
    // up, so that a coach request started from here survives its own await.
    ref.listen(gameDetailControllerProvider(widget.gameId), (_, _) {});
    final provider = reviewControllerProvider(widget.gameId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final document = controller.document;
    final partial = controller.partial;

    ref.listen(provider.select((s) => s.feedbackFailures), (previous, next) {
      if (previous != null && next > previous) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.reviewFeedbackFailed)));
      }
    });

    final workflow = ref.watch(trackedWorkflowsProvider)[widget.gameId];
    // Whoever is developing the coach's voice reads the new text here, so the
    // banner keeps a way to ask for one over a finished pipeline. It costs a
    // quota per run, so only an account without one is offered it. The quota
    // is only asked about when there is a finished pipeline to offer it on,
    // so an ordinary review still opens without that request.
    final stage = _StageBannerState.of(
      workflow,
      controller.data.source,
      canRerunCoach:
          workflow?.isComplete == true &&
          ref.watch(usageProvider).value?.policy == UsagePolicy.unlimited,
    );

    final board = document != null
        ? ReviewBoard.of(document, state)
        : ReviewBoard.ofPartial(partial!, state);
    final textScale = MediaQuery.textScalerOf(context).scale(100) / 100;
    final statusHeight = 22 * textScale.clamp(1.0, 2.0);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40 + 14 * textScale.clamp(1.0, 1.6),
        titleSpacing: 0,
        title: _Header(
          header: controller.data.header,
          document: document,
          fallbackResult: document?.result ?? partial?.result,
        ),
        actions: [_Menu(state: state, controller: controller)],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fixed =
                statusHeight +
                (document == null ? 0 : EvalGraph.defaultHeight + 8) +
                _ControlBar.height +
                (document == null ? 72 : _TabSelector.height) +
                (stage == null ? 0 : _StageBanner.heightOf(stage, textScale)) +
                4;
            final boardSize = _boardSize(constraints, fixed: fixed);
            return Column(
              children: [
                BoardView(
                  size: boardSize,
                  position: board.position,
                  orientation: board.orientation,
                  lastMove: board.lastMove,
                  arrows: board.arrows,
                  glyphs: board.glyphs,
                  theme: ref.watch(boardThemeProvider),
                  animate: state.animate,
                  semanticsLabels: boardLabelsOf(l10n),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: statusHeight,
                        child: _StatusLine(
                          document: document,
                          partial: partial,
                          state: state,
                          variation: controller.currentVariation,
                        ),
                      ),
                      if (document != null) ...[
                        EvalGraph(
                          series: document.evalSeries(),
                          currentPly: state.ply,
                          markers: _markers(context, document),
                          onPlySelected: controller.goTo,
                          semanticLabel: l10n.reviewGraphLabel,
                          semanticValueOf: (ply) =>
                              _evalWordsAt(context, l10n, document, ply),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (stage != null && document != null) ...[
                        _StageBanner(
                          state: stage,
                          onAskCoach: _askCoach,
                          onRetry: _retryStage,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (document != null)
                        _TabSelector(
                          selected: state.tab,
                          onSelect: controller.setTab,
                        )
                      else
                        const _UpdateBanner(),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
                Expanded(
                  child: _FadingEdge(
                    child: switch ((document, state.tab)) {
                      (_?, ReviewTab.coach) => CoachTab(
                        gameId: widget.gameId,
                        onAskCoach: _askCoach,
                      ),
                      (final document?, ReviewTab.summary) => SummaryTab(
                        document: document,
                        source: controller.data.source,
                        onEvidence: controller.showEvidence,
                      ),
                      _ => MovesTab(
                        moves: document != null
                            ? _movesOf(context, document)
                            : _movesOfPartial(context, partial!),
                        currentPly: state.ply,
                        onSelect: controller.goTo,
                      ),
                    },
                  ),
                ),
                _ControlBar(
                  child: state.inLine
                      ? LineControls(
                          onExit: controller.exitLine,
                          onPrevious: controller.canLineBack
                              ? controller.linePrevious
                              : null,
                          onNext: controller.canLineForward
                              ? controller.lineNext
                              : null,
                        )
                      : ReviewControls(
                          showMoments: document != null,
                          onFirst: controller.canGoBack
                              ? controller.first
                              : null,
                          onPrevious: controller.canGoBack
                              ? controller.previous
                              : null,
                          onNext: controller.canGoForward
                              ? controller.next
                              : null,
                          onLast: controller.canGoForward
                              ? controller.last
                              : null,
                          onPreviousMoment: controller.previousMomentPly != null
                              ? controller.previousMoment
                              : null,
                          onNextMoment: controller.nextMomentPly != null
                              ? controller.nextMoment
                              : null,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _evalWordsAt(
    BuildContext context,
    AppLocalizations l10n,
    AnalysisDocument document,
    int ply,
  ) {
    final node = document.nodeAt(ply);
    final eval = node?.evalAfter ?? document.nodes.firstOrNull?.evalBefore;
    return [
      if (node != null)
        context.displaySanInText(node.moveLabel)
      else
        l10n.reviewStartPosition,
      if (eval != null) l10n.evalWords(eval),
    ].join(', ');
  }

  static List<EvalGraphMarker> _markers(
    BuildContext context,
    AnalysisDocument document,
  ) {
    final colors = ReviewColors.of(context);
    return [
      for (final node in document.nodes)
        if (node.isCritical)
          EvalGraphMarker(node.ply, colors.ofGlyph(document.glyphFor(node))),
    ];
  }

  static List<MoveListEntry> _movesOf(
    BuildContext context,
    AnalysisDocument document,
  ) {
    final l10n = context.l10n;
    final colors = ReviewColors.of(context);
    return [
      for (final node in document.nodes)
        () {
          final glyph = document.glyphFor(node);
          final hasComment = node.commentIds.isNotEmpty;
          return MoveListEntry(
            ply: node.ply,
            moveNumber: node.moveNumber,
            isWhite: node.side == Side.white,
            san: context.displaySan(node.san),
            glyph: glyph?.symbol,
            glyphColor: colors.ofGlyph(glyph),
            hasComment: hasComment,
            semanticLabel: [
              context.displaySanInText(node.moveLabel),
              l10n.classificationWords(
                node.classification,
                praised: glyph == AnalysisGlyph.good,
              ),
              if (hasComment) l10n.reviewMoveHasComment,
            ].join(', '),
          );
        }(),
    ];
  }

  static List<MoveListEntry> _movesOfPartial(
    BuildContext context,
    PartialAnalysis partial,
  ) => [
    for (final move in partial.moves)
      () {
        final san = context.displaySan(move.san);
        return MoveListEntry(
          ply: move.ply,
          moveNumber: move.moveNumber,
          isWhite: move.side == Side.white,
          san: san,
          semanticLabel: move.side == Side.white
              ? '${move.moveNumber}. $san'
              : '${move.moveNumber}... $san',
        );
      }(),
  ];
}

/// Players, result and date, and the accuracy of both sides as small chips.
class _Header extends StatelessWidget {
  const _Header({
    required this.header,
    required this.document,
    required this.fallbackResult,
  });

  final GameHeaderInfo header;
  final AnalysisDocument? document;
  final GameResult? fallbackResult;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    String name(String? value, String side) =>
        value == null || value.trim().isEmpty
        ? l10n.reviewSideName(side)
        : value.trim();
    final date = header.date;
    final details = [
      ?l10n.resultWords(header.result, fallbackResult ?? GameResult.unfinished),
      if (date != null) DateFormat.yMd(l10n.localeName).format(date),
    ].join(' · ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${name(header.white, 'white')} – ${name(header.black, 'black')}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Row(
          children: [
            Flexible(
              child: Text(
                details,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final side in Side.values)
              if (document?.accuracyOf(side) case final accuracy?)
                _AccuracyChip(side: side, accuracy: accuracy),
          ],
        ),
      ],
    );
  }
}

class _AccuracyChip extends StatelessWidget {
  const _AccuracyChip({required this.side, required this.accuracy});

  final Side side;
  final double accuracy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = accuracy.round().toString();
    return Semantics(
      container: true,
      identifier: 'review-accuracy-${side.name}',
      label: l10n.reviewAccuracySemantics(side.name, value),
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: side == Side.white
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFF1B1B1B),
                  border: Border.all(color: scheme.outline),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$value %',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MenuAction { bestArrow, playedArrow, flip }

class _Menu extends StatelessWidget {
  const _Menu({required this.state, required this.controller});

  final ReviewState state;
  final ReviewController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasArrows = controller.document != null;
    return Semantics(
      identifier: ReviewIds.menu,
      child: PopupMenuButton<_MenuAction>(
        tooltip: l10n.reviewMenu,
        icon: const Icon(Icons.tune),
        onSelected: (action) => switch (action) {
          _MenuAction.bestArrow => controller.toggleBestArrow(),
          _MenuAction.playedArrow => controller.togglePlayedArrow(),
          _MenuAction.flip => controller.flipBoard(),
        },
        itemBuilder: (context) => [
          if (hasArrows) ...[
            CheckedPopupMenuItem(
              value: _MenuAction.bestArrow,
              checked: state.showBestArrow,
              child: Semantics(
                identifier: ReviewIds.menuBestArrow,
                child: Text(l10n.reviewShowBestArrow),
              ),
            ),
            CheckedPopupMenuItem(
              value: _MenuAction.playedArrow,
              checked: state.showPlayedArrow,
              child: Semantics(
                identifier: ReviewIds.menuPlayedArrow,
                child: Text(l10n.reviewShowPlayedArrow),
              ),
            ),
          ],
          PopupMenuItem(
            value: _MenuAction.flip,
            child: Semantics(
              identifier: ReviewIds.menuFlip,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.swap_vert),
                title: Text(l10n.reviewFlipBoard),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Which move is on the board, with its verdict, and what the position is
/// worth, in words.
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.document,
    required this.partial,
    required this.state,
    required this.variation,
  });

  final AnalysisDocument? document;
  final PartialAnalysis? partial;
  final ReviewState state;
  final Variation? variation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = ReviewColors.of(context);
    final document = this.document;
    final node = document?.nodeAt(state.ply);

    final String move;
    String? glyph;
    Color? glyphColor;
    String words = '';
    if (state.ply == 0) {
      move = l10n.reviewStartPosition;
    } else if (node != null) {
      move = context.displaySanInText(node.moveLabel);
      final g = document!.glyphFor(node);
      glyph = g?.symbol;
      glyphColor = colors.ofGlyph(g);
    } else {
      final partialMove = partial?.moves.elementAtOrNull(state.ply - 1);
      final san = partialMove == null
          ? ''
          : context.displaySan(partialMove.san);
      move = partialMove == null
          ? ''
          : partialMove.side == Side.white
          ? '${partialMove.moveNumber}. $san'
          : '${partialMove.moveNumber}... $san';
    }
    if (document != null && !state.inLine) {
      final eval = node?.evalAfter ?? document.nodes.firstOrNull?.evalBefore;
      if (eval != null) words = l10n.evalWords(eval);
    }

    final muted = theme.textTheme.labelLarge?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );
    return Row(
      children: [
        // The move is short; the limit only matters at very large type.
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.5,
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: move),
                if (glyph != null)
                  TextSpan(
                    text: glyph,
                    style: TextStyle(color: glyphColor),
                  ),
              ],
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: state.inLine ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            words,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            textAlign: TextAlign.end,
            style: muted,
          ),
        ),
      ],
    );
  }
}

/// Coach | Moves | Summary, as one compact segmented row.
class _TabSelector extends StatelessWidget {
  const _TabSelector({required this.selected, required this.onSelect});

  static const double height = 36;

  final ReviewTab selected;
  final ValueChanged<ReviewTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final tabs = [
      (ReviewTab.coach, ReviewIds.tabCoach, l10n.reviewTabCoach),
      (ReviewTab.moves, ReviewIds.tabMoves, l10n.reviewTabMoves),
      (ReviewTab.summary, ReviewIds.tabSummary, l10n.reviewTabSummary),
    ];
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          for (final (tab, identifier, label) in tabs)
            Expanded(
              child: _TabButton(
                identifier: identifier,
                label: label,
                selected: tab == selected,
                onTap: () => onSelect(tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.identifier,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String identifier;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ReviewIdentified(
      identifier: identifier,
      label: label,
      selected: selected,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? scheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.md - 3),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.12),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// The step buttons, pinned to the bottom edge where the thumb is.
class _ControlBar extends StatelessWidget {
  const _ControlBar({required this.child});

  static const double height = 52;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: child,
    );
  }
}

/// Lets the panel's content fade out towards the control bar while there is
/// more below, so that a text that goes on reads as "scroll me" and not as
/// cut off.
class _FadingEdge extends StatefulWidget {
  const _FadingEdge({required this.child});

  final Widget child;

  @override
  State<_FadingEdge> createState() => _FadingEdgeState();
}

class _FadingEdgeState extends State<_FadingEdge> {
  static const double _extent = 20;

  bool _moreBelow = false;

  bool _onMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return false;
    final moreBelow = metrics.extentAfter > 6;
    if (moreBelow != _moreBelow) setState(() => _moreBelow = moreBelow);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onMetrics(n.metrics),
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) => _onMetrics(n.metrics),
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (_moreBelow)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _extent,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [surface.withValues(alpha: 0), surface],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The analysis is of a newer major version: board and moves still work.
/// What the stage banner says, and what it offers.
enum _StageBannerState {
  running,
  lookingForKeyPositions,
  deepRunning,
  deepReady,
  coachWriting,
  complete,
  failed,
  stale;

  /// Null when there is no pipeline to report: nothing is being watched, or
  /// everything is stored.
  ///
  /// [canRerunCoach] is the one exception to "everything is stored": an
  /// account without a quota gets [complete], which is the way to read a new
  /// coach text in place while the voice is being developed.
  static _StageBannerState? of(
    AnalysisWorkflow? workflow,
    AnalysisSource _, {
    required bool canRerunCoach,
  }) {
    if (workflow == null) {
      return null;
    }
    for (final stage in AnalysisStage.pipeline) {
      if (workflow.stateOf(stage) == AnalysisStageState.stale) return stale;
    }
    if (workflow.failedStage != null) {
      return failed;
    }
    return switch (workflow.activeStage) {
      AnalysisStage.coaching => coachWriting,
      AnalysisStage.deepEvaluation => deepRunning,
      AnalysisStage.baseClassification => lookingForKeyPositions,
      AnalysisStage.baseEvaluation => running,
      // Nothing is moving: either the coach has written, which needs no
      // banner, or the engine is done and the coach is one tap away.
      _ =>
        workflow.coachReady
            ? (workflow.isComplete && canRerunCoach ? complete : null)
            : workflow.engineReady
            ? deepReady
            : null,
    };
  }

  /// The quota line belongs under the one state that can spend it.
  bool get showsUsage => this == deepReady;
}

/// One line above the tabs: where the pipeline of this game stands, and the
/// one thing to do about it.
///
/// Mutually exclusive with [_UpdateBanner], which only shows when there is no
/// document at all.
class _StageBanner extends StatelessWidget {
  const _StageBanner({
    required this.state,
    required this.onAskCoach,
    required this.onRetry,
  });

  final _StageBannerState state;
  final VoidCallback onAskCoach;
  final VoidCallback onRetry;

  /// What the board layout has to leave for it. Scaled like the status line,
  /// and capped, so a huge text setting shrinks the board only so far.
  static double heightOf(_StageBannerState state, double textScale) {
    final scale = textScale.clamp(1.0, 2.0);
    return (34 + (state.showsUsage ? 18 : 0)) * scale + AppSpacing.sm;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    // Null for the one state whose whole banner is its action: a finished
    // pipeline has no news, only the offer to write the coach text again.
    final (String, IconData, Color)? line = switch (state) {
      _StageBannerState.complete => null,
      _StageBannerState.running => (
        l10n.reviewStageRunning,
        Icons.hourglass_top,
        theme.colorScheme.onSurfaceVariant,
      ),
      _StageBannerState.lookingForKeyPositions => (
        l10n.reviewStageLookingForKeyPositions,
        Icons.hourglass_top,
        theme.colorScheme.onSurfaceVariant,
      ),
      _StageBannerState.deepRunning => (
        l10n.reviewStageDeepRunning,
        Icons.hourglass_top,
        theme.colorScheme.onSurfaceVariant,
      ),
      _StageBannerState.deepReady => (
        l10n.reviewStageDeepReady,
        Icons.check_circle_outline,
        theme.colorScheme.onSurfaceVariant,
      ),
      _StageBannerState.coachWriting => (
        l10n.reviewStageCoachWriting,
        Icons.edit_outlined,
        theme.colorScheme.onSurfaceVariant,
      ),
      _StageBannerState.failed => (
        l10n.reviewStageFailed,
        Icons.error_outline,
        theme.colorScheme.error,
      ),
      _StageBannerState.stale => (
        l10n.reviewStageStale,
        Icons.history,
        colors.warning,
      ),
    };
    // Its identifier, its label, what it does, and the icon it carries when
    // it stands on its own rather than at the end of a line of text.
    final (String, String, VoidCallback, IconData?)? action = switch (state) {
      _StageBannerState.deepReady => (
        ReviewIds.stageAskCoach,
        l10n.reviewAskCoach,
        onAskCoach,
        null,
      ),
      _StageBannerState.failed => (
        ReviewIds.stageRetry,
        l10n.reviewStageRetry,
        onRetry,
        null,
      ),
      _StageBannerState.complete => (
        ReviewIds.stageRerunCoach,
        l10n.gameDetailRerunCoach,
        onAskCoach,
        Icons.refresh,
      ),
      _ => null,
    };
    return Semantics(
      container: true,
      identifier: ReviewIds.stageBanner,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (line case (final text, final icon, final color)) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              if (action case (final id, final label, final onTap, final icon))
                // On its own the button takes the width, so that its label is
                // laid out against the screen and not against its own text.
                if (line == null)
                  Expanded(child: _button(id, label, onTap, icon))
                else
                  _button(id, label, onTap, icon),
            ],
          ),
          if (state.showsUsage) const UsageSummary(textAlign: TextAlign.start),
        ],
      ),
    );
  }

  /// The banner's action. One line always: [heightOf] reserves the banner's
  /// height before the board is measured, so a label that wrapped would push
  /// the panel below out of the layout. A long translation therefore ends in
  /// an ellipsis rather than in an overflow.
  Widget _button(
    String identifier,
    String label,
    VoidCallback onTap,
    IconData? icon,
  ) {
    final style = TextButton.styleFrom(
      alignment: icon == null ? null : Alignment.centerLeft,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      minimumSize: const Size(48, 28),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    return ReviewIdentified(
      identifier: identifier,
      label: label,
      onTap: onTap,
      child: icon == null
          ? TextButton(onPressed: onTap, style: style, child: text)
          : TextButton.icon(
              onPressed: onTap,
              style: style,
              icon: Icon(icon, size: 16),
              label: text,
            ),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return Semantics(
      container: true,
      identifier: ReviewIds.updateBanner,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 4,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.warning,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(
          children: [
            Icon(Icons.system_update, size: 20, color: colors.onWarning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                context.l10n.reviewUpdateBanner,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onWarning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
