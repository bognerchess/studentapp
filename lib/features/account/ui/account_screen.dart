// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/auth/auth_providers.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/core/ui/widgets/app_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'delete_account_screen.dart';

/// Who is signed in, sign-out, and the way to the account deletion.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  static const Key signOutKey = Key('account-sign-out');
  static const Key signOutConfirmKey = Key('account-sign-out-confirm');
  static const Key deleteKey = Key('account-delete');

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.accountSignOutConfirmTitle),
        content: Text(l10n.accountSignOutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.accountCancel),
          ),
          FilledButton(
            key: signOutConfirmKey,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.accountSignOut),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // Never throws. Clearing the tokens, removing the cached games (drafts
    // stay) and the redirect to the sign-in screen all follow from it.
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final auth = ref.watch(authStateProvider);
    final (name, email, verified) = switch (auth) {
      SignedIn(:final name, :final email, :final emailVerified) => (
        name,
        email,
        emailVerified,
      ),
      SignedOut() => (null, null, null),
    };
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return AppScaffold(
      title: l10n.accountTitle,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MergeSemantics(
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: colors.primaryContainer,
                            foregroundColor: colors.onPrimaryContainer,
                            child: const Icon(Icons.person_outline),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name ?? email ?? l10n.settingsAccountSignedIn,
                                  style: theme.textTheme.titleMedium,
                                ),
                                if (name != null && email != null)
                                  Text(email, style: muted),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (verified == false) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.mark_email_unread_outlined,
                            size: 18,
                            color: AppColors.of(context).warning,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              l10n.accountEmailNotVerified,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.accountSameAccount, style: muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              key: signOutKey,
              onPressed: () => unawaited(_signOut(context, ref)),
              icon: const Icon(Icons.logout),
              label: Text(l10n.accountSignOut),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.accountSignOutHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              header: true,
              child: Text(
                l10n.accountDeleteSection,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.accountDeleteTeaser, style: muted),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: deleteKey,
                style: TextButton.styleFrom(foregroundColor: colors.error),
                // Above the tab bar: nothing else should be one tap away
                // while somebody decides about this.
                onPressed: () => unawaited(
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const DeleteAccountScreen(),
                    ),
                  ),
                ),
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(l10n.accountDelete),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
