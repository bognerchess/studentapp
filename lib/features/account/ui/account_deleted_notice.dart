// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/core/ui/widgets/empty_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/account_deletion.dart';

/// The last screen of an account deletion: "your account has been deleted".
/// Sits in `MaterialApp.builder` and covers the app while
/// [accountDeletedNoticeProvider] is true. Underneath, the sign-out has
/// already led to the sign-in screen, which is what "Done" reveals.
class AccountDeletedNotice extends ConsumerWidget {
  const AccountDeletedNotice({super.key, required this.child});

  final Widget child;

  static const Key doneKey = Key('account-deleted-done');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showing = ref.watch(accountDeletedNoticeProvider);
    // Always the same shape, so that the app below keeps its state when the
    // notice comes and goes.
    return Stack(
      children: [
        child,
        if (showing) const Positioned.fill(child: _Notice()),
      ],
    );
  }
}

class _Notice extends ConsumerWidget {
  const _Notice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // The app below is covered for the eye and the finger by the scaffold,
    // and for a screen reader by this.
    return BlockSemantics(
      child: Scaffold(
        body: SafeArea(
          child: CenteredMessage(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 56,
                color: AppColors.of(context).success,
              ),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  l10n.accountDeletedTitle,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.accountDeletedMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: AccountDeletedNotice.doneKey,
                onPressed: () =>
                    ref.read(accountDeletedNoticeProvider.notifier).dismiss(),
                child: Text(l10n.accountDeletedDone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
