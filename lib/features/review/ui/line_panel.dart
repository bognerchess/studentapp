// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:material_ui/material_ui.dart';

import 'review_colors.dart';
import 'review_ids.dart';
import 'review_l10n.dart';

/// The colour that stands for a line, matching its arrows on the board:
/// green for the best line, red for the punishment, blue for an alternative.
Color lineColor(BuildContext context, VariationKind kind) {
  final colors = ReviewColors.of(context);
  final light = Theme.of(context).brightness == Brightness.light;
  return switch (kind) {
    VariationKind.bestLine => colors.positive,
    VariationKind.refutation => colors.blunder,
    VariationKind.alternative =>
      light ? const Color(0xFF1E5FB8) : const Color(0xFFA8C8FF),
    VariationKind.unknown => colors.neutral,
  };
}

/// The line viewer's panel: what the line is, its moves (the one on the
/// board highlighted, each one tappable), and where it ends up, in words.
/// The step buttons are in the control row under the board.
class LinePanel extends StatelessWidget {
  const LinePanel({
    super.key,
    required this.variation,
    required this.label,
    required this.index,
    required this.onSelect,
  });

  final Variation variation;

  /// The coach's name for the line ("Better"), if a comment refers to it.
  final String? label;

  /// How many moves of the line are on the board.
  final int index;

  /// A tap on move `n` (1-based).
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = lineColor(context, variation.kind);
    final kind = l10n.reviewLineKind(variation.kind.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Icon(Icons.circle, size: 10, color: color),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    if (label != null)
                      TextSpan(
                        text: '$label  ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    TextSpan(
                      text: kind,
                      style: label == null
                          ? const TextStyle(fontWeight: FontWeight.w700)
                          : TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                style: theme.textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: _moves(context, color),
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        Semantics(
          container: true,
          identifier: ReviewIds.lineEval,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: l10n.evalWords(variation.eval)),
                TextSpan(
                  text: '   ${variation.eval.displayText}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  List<Widget> _moves(BuildContext context, Color color) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final start = variation.startPosition;
    final widgets = <Widget>[];
    for (final (i, move) in variation.moves.indexed) {
      final white = (start.turn == Side.white) == i.isEven;
      final number =
          start.fullmoves + (i + (start.turn == Side.black ? 1 : 0)) ~/ 2;
      final prefix = white
          ? '$number. '
          : i == 0
          ? '$number... '
          : '';
      final current = i + 1 == index;
      final played = i + 1 <= index;
      widgets.add(
        ReviewIdentified(
          identifier: ReviewIds.lineMove(i + 1),
          label: '$prefix${move.san}',
          selected: current,
          onTap: () => onSelect(i + 1),
          child: InkWell(
            onTap: () => onSelect(i + 1),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: current ? color : null,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: Text(
                  '$prefix${move.san}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: current
                        ? scheme.surface
                        : played
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}
