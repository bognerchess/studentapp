// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import 'review_ids.dart';

/// One round icon button of the control rows: a 48-point target with a
/// tooltip, one semantics node, and a quiet disabled state.
class ReviewIconButton extends StatelessWidget {
  const ReviewIconButton({
    super.key,
    required this.identifier,
    required this.label,
    required this.icon,
    required this.onTap,
    this.emphasized = false,
  });

  final String identifier;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  /// The key-moment buttons stand out from the plain steppers.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ReviewIdentified(
      identifier: identifier,
      label: label,
      onTap: onTap,
      child: IconButton(
        tooltip: label,
        onPressed: onTap,
        icon: Icon(icon),
        iconSize: 26,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
        style: emphasized
            ? IconButton.styleFrom(
                foregroundColor: scheme.onSecondaryContainer,
                backgroundColor: scheme.secondaryContainer,
                disabledBackgroundColor: scheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
              )
            : null,
      ),
    );
  }
}

/// The row under the graph: previous key moment, start, back, forward, end,
/// next key moment. The key-moment buttons sit at the edges, under the
/// thumbs.
class ReviewControls extends StatelessWidget {
  const ReviewControls({
    super.key,
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onLast,
    required this.onPreviousMoment,
    required this.onNextMoment,
    this.showMoments = true,
  });

  /// Null disables a button.
  final VoidCallback? onFirst;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onLast;
  final VoidCallback? onPreviousMoment;
  final VoidCallback? onNextMoment;

  /// False for an analysis without moments (newer major version).
  final bool showMoments;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (showMoments)
          ReviewIconButton(
            identifier: ReviewIds.previousMoment,
            label: l10n.reviewPreviousMoment,
            icon: Icons.keyboard_double_arrow_left,
            onTap: onPreviousMoment,
            emphasized: true,
          ),
        ReviewIconButton(
          identifier: ReviewIds.first,
          label: l10n.reviewGoToStart,
          icon: Icons.first_page,
          onTap: onFirst,
        ),
        ReviewIconButton(
          identifier: ReviewIds.previous,
          label: l10n.reviewPreviousMove,
          icon: Icons.chevron_left,
          onTap: onPrevious,
        ),
        ReviewIconButton(
          identifier: ReviewIds.next,
          label: l10n.reviewNextMove,
          icon: Icons.chevron_right,
          onTap: onNext,
        ),
        ReviewIconButton(
          identifier: ReviewIds.last,
          label: l10n.reviewGoToEnd,
          icon: Icons.last_page,
          onTap: onLast,
        ),
        if (showMoments)
          ReviewIconButton(
            identifier: ReviewIds.nextMoment,
            label: l10n.reviewNextMoment,
            icon: Icons.keyboard_double_arrow_right,
            onTap: onNextMoment,
            emphasized: true,
          ),
      ],
    );
  }
}

/// The control row while the line viewer is open: leave, step back, step on.
class LineControls extends StatelessWidget {
  const LineControls({
    super.key,
    required this.onExit,
    required this.onPrevious,
    required this.onNext,
  });

  final VoidCallback onExit;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ReviewIdentified(
              identifier: ReviewIds.lineExit,
              label: l10n.reviewLineBack,
              onTap: onExit,
              child: FilledButton.tonalIcon(
                onPressed: onExit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                ),
                icon: const Icon(Icons.close, size: 20),
                label: Text(
                  l10n.reviewLineBack,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        ReviewIconButton(
          identifier: ReviewIds.linePrevious,
          label: l10n.reviewLinePrevious,
          icon: Icons.chevron_left,
          onTap: onPrevious,
          emphasized: true,
        ),
        const SizedBox(width: AppSpacing.sm),
        ReviewIconButton(
          identifier: ReviewIds.lineNext,
          label: l10n.reviewLineNext,
          icon: Icons.chevron_right,
          onTap: onNext,
          emphasized: true,
        ),
      ],
    );
  }
}
