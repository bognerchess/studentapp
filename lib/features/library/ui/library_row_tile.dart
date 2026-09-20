// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/library_models.dart';

/// One row of the library: "White – Black", result, date and event, and the
/// status badge. The list has no final position to draw (the server's list
/// carries no moves), so the leading tile shows the result instead, tinted
/// by how it went for the user.
class LibraryRowTile extends StatelessWidget {
  const LibraryRowTile({
    required this.row,
    required this.identifier,
    required this.onTap,
    super.key,
  });

  final LibraryRow row;
  final String identifier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final players = l10n.libraryPlayersVs(
      row.whiteName ?? l10n.libraryWhite,
      row.blackName ?? l10n.libraryBlack,
    );
    final details = [
      if (row.playedDate case final date?)
        DateFormat.yMMMd(l10n.localeName).format(date.toLocalDateTime())
      else
        l10n.libraryDateUnknown,
      ?row.eventName,
    ].join(' · ');

    return MergeSemantics(
      child: Semantics(
        identifier: identifier,
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.page,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ResultTile(row: row),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        players,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        details,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs + 2),
                      LibraryStatusBadge(status: row.status),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.row});

  final LibraryRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    final playerColor = switch (row) {
      LibraryGameRow(:final game) => game.playerColor,
      LibraryDraftRow(:final metadata) => metadata.playerColor,
    };
    final won = switch (row.result) {
      GameResult.whiteWins => playerColor == PlayerColor.white,
      GameResult.blackWins => playerColor == PlayerColor.black,
      _ => null,
    };
    final decided =
        row.result == GameResult.whiteWins ||
        row.result == GameResult.blackWins;
    final (background, foreground) = switch ((decided, won)) {
      (true, true) => (colors.success, colors.onSuccess),
      (true, false) => (scheme.errorContainer, scheme.onErrorContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    final (token, spoken) = switch (row.result) {
      GameResult.whiteWins => ('1–0', l10n.metadataResultWhiteWinsA11y),
      GameResult.blackWins => ('0–1', l10n.metadataResultBlackWinsA11y),
      GameResult.draw => ('½–½', l10n.metadataResultDrawA11y),
      GameResult.unknown => ('*', l10n.metadataResultUnknown),
    };
    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              token,
              // The tile has a fixed size; the text must not grow out of it.
              textScaler: TextScaler.noScaling,
              style: theme.textTheme.titleSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The small pill that says where a game is on its way to an analysis.
class LibraryStatusBadge extends StatelessWidget {
  const LibraryStatusBadge({required this.status, super.key});

  final LibraryStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final (IconData icon, String label, Color color) = switch (status) {
      LibraryStatus.draft => (
        Icons.edit_outlined,
        l10n.libraryStatusDraft,
        scheme.onSurfaceVariant,
      ),
      LibraryStatus.waitingToUpload => (
        Icons.cloud_upload_outlined,
        l10n.libraryStatusWaiting,
        colors.warning,
      ),
      LibraryStatus.uploadFailed => (
        Icons.cloud_off_outlined,
        l10n.libraryStatusUploadFailed,
        scheme.error,
      ),
      LibraryStatus.analysing => (
        Icons.hourglass_top,
        l10n.libraryStatusAnalysing,
        scheme.primary,
      ),
      LibraryStatus.analysisReady => (
        Icons.check_circle_outline,
        l10n.libraryStatusReady,
        colors.success,
      ),
      LibraryStatus.analysisFailed => (
        Icons.error_outline,
        l10n.libraryStatusFailed,
        scheme.error,
      ),
      LibraryStatus.notAnalysed => (
        Icons.radio_button_unchecked,
        l10n.libraryStatusNotAnalysed,
        scheme.onSurfaceVariant,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
