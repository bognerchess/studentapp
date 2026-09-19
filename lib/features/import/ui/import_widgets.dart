// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/chess/board_thumbnail.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/pgn/pgn_import.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/features/import/ui/import_texts.dart';
import 'package:material_ui/material_ui.dart';

String _localeOf(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag();

/// "White – Black" of any game, importable or not.
String importPlayersOf(AppLocalizations l10n, PgnGameResult game) =>
    importPlayersLine(l10n, game.headers);

/// Shown under the empty field.
class ImportHint extends StatelessWidget {
  const ImportHint({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      context.l10n.importEmptyHint,
      key: const ValueKey('import-hint'),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Shown while a large text is checked in the background.
class ImportChecking extends StatelessWidget {
  const ImportChecking({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('import-checking'),
      children: [
        const SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(context.l10n.importChecking)),
      ],
    );
  }
}

/// What is wrong and where, in plain words. Announced to assistive
/// technology when it appears, because it appears while the user is typing
/// somewhere else.
class ImportErrorPanel extends StatelessWidget {
  const ImportErrorPanel({
    super.key,
    required this.title,
    required this.error,
    this.players,
  });

  final String title;
  final PgnImportError error;

  /// The game the error is about, when the text has several.
  final String? players;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final where = importErrorWhere(l10n, error);
    final onPanel = colors.onErrorContainer;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Card(
        key: const ValueKey('import-error'),
        margin: EdgeInsets.zero,
        color: colors.errorContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: onPanel),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: onPanel,
                      ),
                    ),
                    if (players case final players?) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        players,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: onPanel,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      importErrorMessage(l10n, error),
                      key: const ValueKey('import-error-message'),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: onPanel,
                      ),
                    ),
                    if (where != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        where,
                        key: const ValueKey('import-error-where'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: onPanel,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.importErrorFixHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onPanel,
                        ),
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

/// The preview of the one game that "Continue" will hand over.
class ImportPreviewCard extends StatelessWidget {
  const ImportPreviewCard({super.key, required this.game});

  final PgnImportedGame game;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final event = pgnTag(game.headers, 'Event');

    return Card(
      key: const ValueKey('import-preview'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: AppColors.of(context).success,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.importPreviewTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BoardThumbnail(
                  fen: game.finalFen,
                  size: 112,
                  lastMove: game.lastMove,
                  semanticLabel: l10n.importFinalPosition,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        importPlayersLine(
                          l10n,
                          game.headers,
                          withRatings: true,
                        ),
                        key: const ValueKey('import-preview-players'),
                        style: theme.textTheme.titleSmall,
                      ),
                      if (event != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(event, style: theme.textTheme.bodyMedium),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        importFactsLine(l10n, game, _localeOf(context)),
                        key: const ValueKey('import-preview-facts'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            for (final warning in game.warnings) ...[
              const SizedBox(height: AppSpacing.md),
              _Warning(
                key: ValueKey('import-warning-${warning.name}'),
                text: switch (warning) {
                  PgnImportWarning.variationsRemoved =>
                    l10n.importWarningVariations,
                  PgnImportWarning.commentsRemoved =>
                    l10n.importWarningComments,
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 20,
          color: AppColors.of(context).warning,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

/// "3 games found" and what to do about it.
class ImportChooserHeader extends StatelessWidget {
  const ImportChooserHeader({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.importGamesFound(count),
            key: const ValueKey('import-games-found'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.importChooseGame,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One game in the chooser. A game that failed the check is listed too, and
/// tapping it explains why.
class ImportGameRow extends StatelessWidget {
  const ImportGameRow({super.key, required this.game, required this.onTap});

  final PgnGameResult game;
  final VoidCallback onTap;

  static const double _thumbnail = 56;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final game = this.game;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                switch (game) {
                  PgnImportedGame() => BoardThumbnail(
                    fen: game.finalFen,
                    size: _thumbnail,
                    lastMove: game.lastMove,
                  ),
                  PgnRejectedGame() => SizedBox.square(
                    dimension: _thumbnail,
                    child: Icon(Icons.error_outline, color: colors.error),
                  ),
                },
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        importPlayersOf(l10n, game),
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      switch (game) {
                        PgnImportedGame() => Text(
                          importFactsLine(l10n, game, _localeOf(context)),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        PgnRejectedGame() => Text(
                          l10n.importGameNotImportable,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.error,
                          ),
                        ),
                      },
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
