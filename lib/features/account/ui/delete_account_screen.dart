// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/links/link_launcher.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/core/ui/widgets/empty_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/account_deletion.dart';

/// Account deletion: what it means, type-to-confirm, and what the server
/// said. The account is the bognerchess.com account, not an app account, and
/// the screen says so before anything else.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  static const Key fieldKey = Key('delete-account-field');
  static const Key confirmKey = Key('delete-account-confirm');
  static const Key supportKey = Key('delete-account-support');
  static const Key backKey = Key('delete-account-back');
  static const Key scrollKey = Key('delete-account-scroll');

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final TextEditingController _confirmation = TextEditingController();

  @override
  void initState() {
    super.initState();
    _confirmation.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  // Lower case is accepted: the word is a speed bump, not a password.
  bool get _confirmed =>
      _confirmation.text.trim().toUpperCase() == kDeleteConfirmationWord;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(accountDeletionProvider);
    final busy = state is DeletionInProgress;

    return PopScope(
      // No way out while the request is under way: its answer decides
      // whether this device still has an account.
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.accountDeleteTitle)),
        body: SafeArea(
          child: switch (state) {
            DeletionBlocked(:final reason) => _Blocked(
              reason: reason,
              onBack: () => Navigator.of(context).pop(),
            ),
            _ => _Explanation(
              controller: _confirmation,
              confirmed: _confirmed,
              busy: busy,
              failure: state is DeletionFailed ? state.error : null,
              onDelete: () {
                FocusScope.of(context).unfocus();
                unawaited(ref.read(accountDeletionProvider.notifier).delete());
              },
            ),
          },
        ),
      ),
    );
  }
}

class _Explanation extends StatelessWidget {
  const _Explanation({
    required this.controller,
    required this.confirmed,
    required this.busy,
    required this.failure,
    required this.onDelete,
  });

  final TextEditingController controller;
  final bool confirmed;
  final bool busy;
  final ApiError? failure;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final failure = this.failure;

    return SingleChildScrollView(
      key: DeleteAccountScreen.scrollKey,
      padding: const EdgeInsets.all(AppSpacing.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber, color: colors.onErrorContainer),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.accountDeleteSameAccountTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colors.onErrorContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.accountDeleteSameAccountBody,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Bullets(
            title: l10n.accountDeleteWhatGoesTitle,
            icon: Icons.delete_outline,
            items: [
              l10n.accountDeleteGoesGames,
              l10n.accountDeleteGoesProfile,
              l10n.accountDeleteGoesDevice,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Bullets(
            title: l10n.accountDeleteWhatStaysTitle,
            icon: Icons.receipt_long_outlined,
            items: [l10n.accountDeleteStaysInvoices],
          ),
          const SizedBox(height: AppSpacing.md),
          _Bullets(
            title: l10n.accountDeleteGoodToKnowTitle,
            icon: Icons.info_outline,
            items: [
              l10n.accountDeleteIrreversible,
              l10n.accountDeleteMayBeBlocked,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.accountDeleteTypeInstruction(kDeleteConfirmationWord),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: DeleteAccountScreen.fieldKey,
            controller: controller,
            enabled: !busy,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: l10n.accountDeleteFieldLabel(kDeleteConfirmationWord),
              hintText: kDeleteConfirmationWord,
            ),
          ),
          if (failure != null) ...[
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                failure is ApiNetworkError
                    ? l10n.accountDeleteFailedOffline
                    : l10n.accountDeleteFailed,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: DeleteAccountScreen.confirmKey,
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: confirmed && !busy ? onDelete : null,
            child: busy
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: l10n.accountDeleteInProgress,
                    ),
                  )
                : Text(
                    failure == null
                        ? l10n.accountDeleteConfirm
                        : l10n.accountDeleteRetry,
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.titleSmall),
              ),
            ),
          ],
        ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.xs,
              left: 20 + AppSpacing.sm,
            ),
            child: Text(item, style: theme.textTheme.bodyMedium),
          ),
      ],
    );
  }
}

/// The server refused. Says why, in words, and where to turn.
class _Blocked extends ConsumerWidget {
  const _Blocked({required this.reason, required this.onBack});

  final DeletionBlockReason reason;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final explanation = switch (reason) {
      DeletionBlockReason.kidAccount => l10n.accountDeleteBlockedKid,
      DeletionBlockReason.hasDependents => l10n.accountDeleteBlockedDependents,
      DeletionBlockReason.activeMembership =>
        l10n.accountDeleteBlockedMembership,
      DeletionBlockReason.openInvoices => l10n.accountDeleteBlockedInvoices,
      DeletionBlockReason.other => l10n.accountDeleteBlockedOther,
    };
    final mail = Uri(
      scheme: 'mailto',
      path: kSupportEmail,
      // Not queryParameters: that writes a space as "+", which mail apps
      // show as a plus. Nothing personal goes into the link.
      query: 'subject=${Uri.encodeComponent(l10n.accountDeleteSupportSubject)}',
    );

    return CenteredMessage(
      children: [
        Icon(Icons.block, size: 56, color: theme.colorScheme.error),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            l10n.accountDeleteBlockedTitle,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          explanation,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.accountDeleteBlockedNothingDeleted,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          key: DeleteAccountScreen.supportKey,
          onPressed: () => unawaited(
            ref
                .read(linkLauncherProvider)(mail)
                .catchError((Object _) => false),
          ),
          icon: const Icon(Icons.mail_outline),
          label: Text(l10n.accountDeleteContactSupport),
        ),
        const SizedBox(height: AppSpacing.xs),
        // For whoever has no mail app set up: the address to copy.
        SelectableText(
          kSupportEmail,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          key: DeleteAccountScreen.backKey,
          onPressed: onBack,
          child: Text(l10n.accountBack),
        ),
      ],
    );
  }
}
