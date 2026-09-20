// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/analysis/analysis_view.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/review_controller.dart';
import '../domain/review_repository.dart';
import 'line_panel.dart';
import 'review_colors.dart';
import 'review_ids.dart';
import 'review_l10n.dart';

/// The coach's panel: the comment on the current move, or the open line, or
/// (on a move the coach said nothing about) one engine fact and the way to
/// the next key moment. A horizontal swipe moves between key moments.
class CoachTab extends ConsumerWidget {
  const CoachTab({super.key, required this.gameId});

  final String gameId;

  /// Fling speed, in logical pixels per second, that counts as a swipe.
  static const double _swipeVelocity = 250;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = reviewControllerProvider(gameId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final document = controller.document;
    if (document == null) return const SizedBox.shrink();

    final variation = controller.currentVariation;
    final node = document.nodeAt(state.ply);
    final comments = document.commentsAt(state.ply);

    final Widget content;
    final Key contentKey;
    if (state.line != null && variation != null && node != null) {
      contentKey = ValueKey('line-${state.line!.variationId}');
      content = LinePanel(
        variation: variation,
        label: _labelOf(document, node, variation),
        index: state.line!.index,
        onSelect: controller.lineGoTo,
      );
    } else if (comments.isNotEmpty) {
      contentKey = ValueKey('comments-${state.ply}');
      final moments = document.criticalPlies;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, comment) in comments.indexed) ...[
            if (index > 0) const Divider(height: AppSpacing.lg),
            CommentCard(
              comment: comment,
              node: node!,
              glyph: document.glyphFor(node),
              momentIndex: moments.indexOf(state.ply) + 1,
              momentCount: moments.length,
              // Identifiers must be unique on screen: only the selected
              // comment carries the plain ones.
              primary:
                  comment.id == state.selectedCommentId ||
                  (index == 0 &&
                      !comments.any((c) => c.id == state.selectedCommentId)),
              rating: state.feedback[comment.id],
              onSelect: () => controller.selectComment(comment.id),
              onRate: (rating) => controller.rate(comment.id, rating),
              onShowLine: (variationId) {
                controller
                  ..selectComment(comment.id)
                  ..enterLine(variationId);
              },
            ),
          ],
        ],
      );
    } else {
      contentKey = ValueKey('fact-${state.ply}');
      content = _EngineFact(
        document: document,
        node: node,
        hasNextMoment: controller.nextMomentPly != null,
        onNextMoment: controller.nextMoment,
        onOpenSummary: () => controller.setTab(ReviewTab.summary),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < _swipeVelocity) return;
        final forward = velocity < 0;
        if (state.inLine) {
          forward ? controller.lineNext() : controller.linePrevious();
        } else {
          forward ? controller.nextMoment() : controller.previousMoment();
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        layoutBuilder: (current, previous) =>
            Stack(fit: StackFit.expand, children: [...previous, ?current]),
        child: SingleChildScrollView(
          key: contentKey,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.xs,
            AppSpacing.page,
            AppSpacing.sm + 4,
          ),
          child: content,
        ),
      ),
    );
  }

  /// The label the coach gave the line, or the kind in words for a line no
  /// comment refers to.
  static String? _labelOf(
    AnalysisDocument document,
    AnalysisNode node,
    Variation variation,
  ) {
    for (final comment in document.commentsOf(node)) {
      for (final line in comment.lines) {
        if (line.variationId == variation.id && line.label.isNotEmpty) {
          return line.label;
        }
      }
    }
    return null;
  }
}

/// One coach comment. A fallback comment (written from a template when the
/// model's text did not pass verification) looks exactly the same: the
/// player is not bothered with how the text came about.
class CommentCard extends StatelessWidget {
  const CommentCard({
    super.key,
    required this.comment,
    required this.node,
    required this.glyph,
    required this.momentIndex,
    required this.momentCount,
    required this.primary,
    required this.rating,
    required this.onSelect,
    required this.onRate,
    required this.onShowLine,
  });

  final CoachComment comment;
  final AnalysisNode node;
  final AnalysisGlyph? glyph;

  /// 1-based position among the key moments; 0 when the ply is not one.
  final int momentIndex;
  final int momentCount;
  final bool primary;
  final CommentRating? rating;
  final VoidCallback onSelect;
  final ValueChanged<CommentRating> onRate;
  final ValueChanged<String> onShowLine;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = ReviewColors.of(context);
    final themeLabel = l10n.themeWords(comment.theme);
    final verdictColor = comment.isPositive
        ? colors.positive
        : colors.ofGlyph(glyph);
    final suffix = primary ? '' : '-${comment.id}';

    return Semantics(
      container: true,
      identifier: '${ReviewIds.commentCard}$suffix',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: primary ? null : onSelect,
        // No box around the comment: the panel is the coach's, and a card
        // inside it would cost a line of text on a small phone.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      VerdictPill(
                        symbol: glyph?.symbol,
                        label: l10n.classificationWords(
                          node.classification,
                          praised: comment.isPositive,
                        ),
                        color: verdictColor,
                      ),
                      if (themeLabel != null) _ThemeChip(label: themeLabel),
                    ],
                  ),
                ),
                _Thumb(
                  identifier: '${ReviewIds.thumbUp}$suffix',
                  label: l10n.reviewThumbUp,
                  icon: Icons.thumb_up_outlined,
                  selectedIcon: Icons.thumb_up,
                  selected: rating == CommentRating.up,
                  onTap: () => onRate(CommentRating.up),
                ),
                _Thumb(
                  identifier: '${ReviewIds.thumbDown}$suffix',
                  label: l10n.reviewThumbDown,
                  icon: Icons.thumb_down_outlined,
                  selectedIcon: Icons.thumb_down,
                  selected: rating == CommentRating.down,
                  onTap: () => onRate(CommentRating.down),
                ),
              ],
            ),
            if (comment.title.isNotEmpty) ...[
              Text(
                comment.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text.rich(
              TextSpan(
                children: emphasizeMoves(comment.text, comment.movesMentioned),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            if (comment.lines.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final line in comment.lines)
                    if (node.variationById(line.variationId)
                        case final variation?)
                      _LineButton(
                        identifier:
                            '${ReviewIds.commentLine(variation.id)}$suffix',
                        label: line.label,
                        variation: variation,
                        onTap: () => onShowLine(variation.id),
                      ),
                ],
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.reviewCoachAiNote,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (momentIndex > 0)
                  Text(
                    '$momentIndex/$momentCount',
                    semanticsLabel: l10n.reviewMomentCounter(
                      momentIndex,
                      momentCount,
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// [text] with every move of [moves] (the comment's `moves_mentioned`) in
/// semi-bold, so that the eye finds on the board what the sentence is about.
List<InlineSpan> emphasizeMoves(String text, List<String> moves) {
  final tokens = moves.where((m) => m.isNotEmpty).toSet().toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  if (tokens.isEmpty) return [TextSpan(text: text)];
  final pattern = RegExp(
    '(?<![A-Za-z0-9])(?:${tokens.map(RegExp.escape).join('|')})'
    '(?![A-Za-z0-9+#=])',
  );
  final spans = <InlineSpan>[];
  var start = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > start) {
      spans.add(TextSpan(text: text.substring(start, match.start)));
    }
    spans.add(
      TextSpan(
        text: match.group(0),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
    start = match.end;
  }
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
  return spans;
}

/// "?? Blunder": the verdict on a move as a filled pill.
class VerdictPill extends StatelessWidget {
  const VerdictPill({
    super.key,
    required this.label,
    required this.color,
    this.symbol,
  });

  final String? symbol;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          symbol == null ? label : '$symbol  $label',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.surface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _LineButton extends StatelessWidget {
  const _LineButton({
    required this.identifier,
    required this.label,
    required this.variation,
    required this.onTap,
  });

  final String identifier;
  final String label;
  final Variation variation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = label.isEmpty
        ? l10n.reviewLineKind(variation.kind.name)
        : label;
    return ReviewIdentified(
      identifier: identifier,
      label: l10n.reviewShowLine('$name, ${variation.moves.first.san}'),
      onTap: onTap,
      child: ActionChip(
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        avatar: Icon(
          Icons.play_arrow_rounded,
          size: 18,
          color: lineColor(context, variation.kind),
        ),
        label: Text('$name · ${variation.moves.first.san}'),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.identifier,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String identifier;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The icon sits in the middle of a 44-point target; the shift lines the
    // right-hand icon up with the text margin.
    return Transform.translate(
      offset: const Offset(10, 0),
      child: ReviewIdentified(
        identifier: identifier,
        label: label,
        toggled: selected,
        onTap: onTap,
        child: IconButton(
          tooltip: label,
          isSelected: selected,
          onPressed: onTap,
          iconSize: 22,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: EdgeInsets.zero,
          color: scheme.onSurfaceVariant,
          icon: Icon(icon),
          selectedIcon: Icon(selectedIcon, color: scheme.primary),
        ),
      ),
    );
  }
}

/// What the coach tab shows on a move without a comment: the engine's
/// verdict in one line, and the way on.
class _EngineFact extends StatelessWidget {
  const _EngineFact({
    required this.document,
    required this.node,
    required this.hasNextMoment,
    required this.onNextMoment,
    required this.onOpenSummary,
  });

  final AnalysisDocument document;

  /// Null on the start position.
  final AnalysisNode? node;
  final bool hasNextMoment;
  final VoidCallback onNextMoment;
  final VoidCallback onOpenSummary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = ReviewColors.of(context);
    final node = this.node;

    final List<Widget> head;
    if (node == null) {
      head = [
        Text(
          l10n.reviewStartPositionTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.reviewStartPositionHint,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ];
    } else {
      final glyph = document.glyphFor(node);
      final best = node.best;
      final showBest =
          best != null &&
          best.san != node.san &&
          glyph != null &&
          glyph != AnalysisGlyph.good;
      head = [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              node.moveLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            VerdictPill(
              symbol: glyph?.symbol,
              label: l10n.classificationWords(node.classification),
              color: colors.ofClassification(node.classification),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          [
            if (showBest) l10n.reviewFactBetterWas(best.san),
            '${l10n.evalWords(node.evalAfter)}.',
          ].join(' '),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ];
    }

    final nextLabel = !hasNextMoment
        ? l10n.reviewOpenSummary
        : node == null
        ? l10n.reviewFirstMoment
        : l10n.reviewNextMoment;
    final onNext = hasNextMoment ? onNextMoment : onOpenSummary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          identifier: ReviewIds.engineFact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: head,
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        ReviewIdentified(
          identifier: ReviewIds.coachNext,
          label: nextLabel,
          onTap: onNext,
          child: FilledButton.tonalIcon(
            onPressed: onNext,
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            icon: Icon(
              hasNextMoment ? Icons.keyboard_double_arrow_right : Icons.school,
            ),
            label: Text(nextLabel),
          ),
        ),
      ],
    );
  }
}
