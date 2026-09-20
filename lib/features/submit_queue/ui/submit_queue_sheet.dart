// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/features/submit_queue/domain/draft_meta.dart';
import 'package:bogner_chess/features/submit_queue/domain/submit_models.dart';
import 'package:bogner_chess/features/submit_queue/domain/submit_queue_providers.dart';
import 'package:bogner_chess/features/submit_queue/ui/submit_queue_texts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The games that are not on the server yet, each with its state, the reason
/// of the last failure, and Retry / Delete.
Future<void> showSubmitQueueSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const SubmitQueueSheet(),
  );
}

class SubmitQueueSheet extends ConsumerWidget {
  const SubmitQueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final drafts = ref.watch(submitQueueDraftsProvider).value ?? const [];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.submitQueueSheetTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (drafts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Text(l10n.submitQueueSheetEmpty),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: drafts.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      SubmitQueueDraftTile(draft: drafts[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One waiting or failed draft: who played, what state it is in and why, and
/// what can be done about it. Public so that the library can show the same
/// row in its own list.
class SubmitQueueDraftTile extends ConsumerWidget {
  const SubmitQueueDraftTile({super.key, required this.draft});

  final Draft draft;

  static Key retryKey(String draftId) =>
      ValueKey('submit-draft-retry-$draftId');
  static Key deleteKey(String draftId) =>
      ValueKey('submit-draft-delete-$draftId');

  static String titleOf(AppLocalizations l10n, Draft draft) {
    final metadata = DraftMeta.decode(draft.metaJson).metadata;
    final white = metadata.whiteName;
    final black = metadata.blackName;
    if (white == null && black == null) return l10n.submitQueueDraftUntitled;
    return l10n.submitQueueDraftPlayers(
      white ?? l10n.submitQueueDraftUnknownPlayer,
      black ?? l10n.submitQueueDraftUnknownPlayer,
    );
  }

  static String stateOf(AppLocalizations l10n, Draft draft) {
    final error = draft.lastError;
    return switch (draft.state) {
      DraftState.submitting => l10n.submitQueueStateUploading,
      DraftState.failed => l10n.submitQueueStateFailed(
        submitErrorText(l10n, SubmitError.parse(error)),
      ),
      _ when error != null => l10n.submitQueueStateRetrying(
        submitErrorText(l10n, SubmitError.parse(error)),
      ),
      _ => l10n.submitQueueStateWaiting,
    };
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.submitQueueDeleteTitle),
        content: Text(l10n.submitQueueDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.submitQueueCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.submitQueueDelete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(submitQueueProvider).delete(draft.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final failed = draft.state == DraftState.failed;
    final busy = draft.state == DraftState.submitting;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titleOf(l10n, draft), style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            stateOf(l10n, draft),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: failed
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (!busy)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                children: [
                  TextButton(
                    key: deleteKey(draft.id),
                    onPressed: () => unawaited(_delete(context, ref)),
                    child: Text(l10n.submitQueueDelete),
                  ),
                  if (failed)
                    TextButton(
                      key: retryKey(draft.id),
                      onPressed: () => unawaited(
                        ref.read(submitQueueProvider).retry(draft.id),
                      ),
                      child: Text(l10n.submitQueueRetry),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
