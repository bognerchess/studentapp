// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/features/entry/ui/entry_identified.dart';
import 'package:material_ui/material_ui.dart';

/// Asks before a move played in the middle of the line cuts off what follows.
/// Completes with true for "replace"; dismissing the sheet keeps the moves.
Future<bool> showEntryOverwriteSheet(
  BuildContext context, {
  required int removedMoves,
  required String newSan,
  required String oldSan,
}) async {
  final replace = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    // Lets the sheet grow with large type instead of clipping it.
    isScrollControlled: true,
    builder: (context) {
      final l10n = context.l10n;
      final theme = Theme.of(context);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.entryOverwriteTitle(removedMoves),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.entryOverwriteMessage(newSan, oldSan),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              EntryIdentified(
                identifier: EntryIds.overwriteConfirm,
                label: l10n.entryOverwriteConfirm,
                onTap: () => Navigator.of(context).pop(true),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.entryOverwriteConfirm),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              EntryIdentified(
                identifier: EntryIds.overwriteCancel,
                label: l10n.entryOverwriteCancel,
                onTap: () => Navigator.of(context).pop(false),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.entryOverwriteCancel),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  return replace ?? false;
}
