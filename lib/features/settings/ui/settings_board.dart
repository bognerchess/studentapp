// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/chess/board_theme_preference.dart';
import 'package:bogner_chess/core/chess/board_view.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Piece set and board colours, with a board that shows the choice at once.
/// The choice applies to every board of the app (`boardThemeProvider`).
class SettingsBoard extends ConsumerWidget {
  const SettingsBoard({super.key});

  static const Key previewKey = Key('settings-board-preview');

  static Key pieceSetKey(BoardPieceSet set) => Key('board-pieces-${set.name}');
  static Key colorsKey(BoardColors colors) =>
      Key('board-colors-${colors.name}');

  /// A Ruy Lopez after 3. Bb5: every piece type is visible, and the last
  /// move shows the highlight colour of the scheme.
  static final Position _position = Chess.fromSetup(
    Setup.parseFen(
      'r1bqkbnr/pppp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3',
    ),
  );
  static const Move _lastMove = NormalMove(from: Square.f1, to: Square.b5);

  /// The names of the sets are names, not words: the same in every language.
  static String pieceSetName(BoardPieceSet set) => switch (set) {
    BoardPieceSet.cburnett => 'Cburnett',
    BoardPieceSet.merida => 'Merida',
    BoardPieceSet.rhosgfx => 'Rhos',
  };

  static String colorsName(AppLocalizations l10n, BoardColors colors) =>
      switch (colors) {
        BoardColors.brown => l10n.settingsBoardColorsBrown,
        BoardColors.blue => l10n.settingsBoardColorsBlue,
        BoardColors.green => l10n.settingsBoardColorsGreen,
        BoardColors.ic => l10n.settingsBoardColorsOlive,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final boardTheme = ref.watch(boardThemeProvider);
    final notifier = ref.read(boardThemeProvider.notifier);
    final label = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Semantics(
              container: true,
              image: true,
              label: l10n.settingsBoardPreviewLabel(
                pieceSetName(boardTheme.pieceSet),
                colorsName(l10n, boardTheme.colors),
              ),
              // 64 labelled squares are right on a board one plays on, and
              // noise on a picture of one.
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: BoardView(
                    key: previewKey,
                    size: 192,
                    position: _position,
                    lastMove: _lastMove,
                    theme: boardTheme,
                    showCoordinates: false,
                    animate: false,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.settingsBoardPieces, style: label),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final set in BoardPieceSet.values)
                ChoiceChip(
                  key: pieceSetKey(set),
                  label: Text(pieceSetName(set)),
                  selected: boardTheme.pieceSet == set,
                  onSelected: (_) => unawaited(notifier.select(pieceSet: set)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.settingsBoardColors, style: label),
          const SizedBox(height: AppSpacing.xs),
          // Four names do not fit next to each other as chips; four swatches
          // with the name underneath do, at text scale 1.3 on an iPhone SE too.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final colors in BoardColors.values)
                Expanded(
                  child: _ColorsOption(
                    key: colorsKey(colors),
                    colors: colors,
                    name: colorsName(l10n, colors),
                    selected: boardTheme.colors == colors,
                    onTap: () => unawaited(notifier.select(colors: colors)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One colour scheme: a small checkerboard with its name underneath.
class _ColorsOption extends StatelessWidget {
  const _ColorsOption({
    super.key,
    required this.colors,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final BoardColors colors;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final squares = boardSquareColorsOf(colors);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: name,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.sm + 3),
                  border: Border.all(
                    width: 2,
                    color: selected ? scheme.primary : Colors.transparent,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: SizedBox.square(
                    dimension: 44,
                    child: Column(
                      children: [
                        for (final row in [0, 1])
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final column in [0, 1])
                                  Expanded(
                                    child: ColoredBox(
                                      color: (row + column).isEven
                                          ? squares.light
                                          : squares.dark,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                name,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
