// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/analysis/analysis_view.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'review_colors.dart';
import 'review_ids.dart';
import 'review_l10n.dart';

/// The game in three lessons (AN-6), each with chips that jump to the moves
/// it is about, and below them the move-quality table of both sides.
class SummaryTab extends StatelessWidget {
  const SummaryTab({
    super.key,
    required this.document,
    required this.onEvidence,
  });

  final AnalysisDocument document;

  /// A tap on an evidence chip, with its ply.
  final ValueChanged<int> onEvidence;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lessons = document.lessons;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.reviewLessonsTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (lessons.isEmpty)
            Text(
              l10n.reviewLessonsEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          for (final (index, lesson) in lessons.indexed) ...[
            if (index > 0) const SizedBox(height: AppSpacing.sm),
            _LessonCard(
              number: index + 1,
              lesson: lesson,
              document: document,
              onEvidence: onEvidence,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.reviewQualityTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _QualityTable(document: document),
        ],
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.number,
    required this.lesson,
    required this.document,
    required this.onEvidence,
  });

  final int number;
  final Lesson lesson;
  final AnalysisDocument document;
  final ValueChanged<int> onEvidence;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final themeLabel = l10n.themeWords(lesson.theme);
    final evidence = [
      for (final ply in lesson.evidencePlies) ?document.nodeAt(ply),
    ];

    return Semantics(
      container: true,
      identifier: ReviewIds.lesson(number),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm + 4,
            AppSpacing.sm + 4,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    textScaler: TextScaler.noScaling,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        lesson.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      lesson.text,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                    if (themeLabel != null || evidence.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final node in evidence)
                            ReviewIdentified(
                              identifier: ReviewIds.lessonEvidence(
                                number,
                                node.ply,
                              ),
                              label: l10n.reviewLessonEvidence(node.moveLabel),
                              onTap: () => onEvidence(node.ply),
                              child: ActionChip(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => onEvidence(node.ply),
                                avatar: Icon(
                                  Icons.my_location,
                                  size: 16,
                                  color: scheme.primary,
                                ),
                                label: Text(
                                  l10n.reviewLessonEvidence(node.moveLabel),
                                ),
                              ),
                            ),
                          if (themeLabel != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                themeLabel,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Accuracy and the number of moves of each quality, White against Black.
class _QualityTable extends StatelessWidget {
  const _QualityTable({required this.document});

  final AnalysisDocument document;

  static const List<MoveClassification> _rows = [
    MoveClassification.best,
    MoveClassification.good,
    MoveClassification.book,
    MoveClassification.inaccuracy,
    MoveClassification.mistake,
    MoveClassification.blunder,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = ReviewColors.of(context);
    final white = document.classificationCounts(Side.white);
    final black = document.classificationCounts(Side.black);
    final percent = NumberFormat('0.0', l10n.localeName);
    String accuracy(Side side) {
      final value = document.accuracyOf(side);
      return value == null ? '–' : '${percent.format(value)} %';
    }

    final head = theme.textTheme.labelLarge?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final number = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // Two fixed number columns, wide enough for "100.0 %" at any type size;
    // the label takes the rest and wraps if it has to.
    final numberWidth = MediaQuery.textScalerOf(context).scale(64);
    Widget row(Widget label, String left, String right, {TextStyle? style}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(child: label),
              for (final value in [left, right])
                SizedBox(
                  width: numberWidth,
                  child: Text(
                    value,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    textAlign: TextAlign.end,
                    style: style ?? number,
                  ),
                ),
            ],
          ),
        );

    return Column(
      children: [
        row(
          const SizedBox.shrink(),
          l10n.reviewSideName('white'),
          l10n.reviewSideName('black'),
          style: head,
        ),
        row(
          Text(l10n.reviewAccuracy, style: theme.textTheme.bodyMedium),
          accuracy(Side.white),
          accuracy(Side.black),
        ),
        for (final classification in _rows)
          row(
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: colors.ofClassification(classification),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    l10n.classificationWords(classification),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            '${white[classification] ?? 0}',
            '${black[classification] ?? 0}',
          ),
      ],
    );
  }
}
