// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/analysis/analysis_view.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

/// The colours of move quality on the review screen. The hues follow the
/// glyph badges `BoardView` paints, darkened or lightened until text in them
/// is readable on the app's surfaces (4.5:1).
@immutable
class ReviewColors {
  const ReviewColors._({
    required this.blunder,
    required this.mistake,
    required this.inaccuracy,
    required this.positive,
    required this.neutral,
  });

  factory ReviewColors.of(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    return ReviewColors._(
      blunder: light ? const Color(0xFFBA1A1A) : const Color(0xFFFFB4AB),
      mistake: light ? const Color(0xFFB45300) : const Color(0xFFFFB877),
      inaccuracy: light ? const Color(0xFF7A5F00) : const Color(0xFFECC44F),
      positive: AppColors.of(context).success,
      neutral: theme.colorScheme.onSurfaceVariant,
    );
  }

  final Color blunder;
  final Color mistake;
  final Color inaccuracy;
  final Color positive;
  final Color neutral;

  /// For a glyph suffix in the move list, a badge, a dot in the graph.
  Color ofGlyph(AnalysisGlyph? glyph) => switch (glyph) {
    AnalysisGlyph.blunder => blunder,
    AnalysisGlyph.mistake => mistake,
    AnalysisGlyph.inaccuracy => inaccuracy,
    AnalysisGlyph.good => positive,
    null => neutral,
  };

  Color ofClassification(MoveClassification classification) =>
      switch (classification) {
        MoveClassification.blunder => blunder,
        MoveClassification.mistake => mistake,
        MoveClassification.inaccuracy => inaccuracy,
        MoveClassification.best || MoveClassification.good => positive,
        MoveClassification.book || MoveClassification.unknown => neutral,
      };
}
