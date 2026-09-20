// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

/// Keys for tests and the simulator's `inspect`.
abstract final class PushExplainerKeys {
  static const Key sheet = Key('pushExplainer.sheet');
  static const Key allow = Key('pushExplainer.allow');
  static const Key notNow = Key('pushExplainer.notNow');
}

/// Says in the app's own words why it would like to send notifications,
/// before iOS asks its one and only time. Completes with true when the user
/// wants them; "Not now" and dismissing the sheet are false, and then the
/// system prompt is not shown, so it stays available for later.
Future<bool> showPushExplainerSheet(BuildContext context) async {
  final wanted = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    // Lets the sheet grow with large type instead of clipping it.
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) => const PushExplainerSheet(),
  );
  return wanted ?? false;
}

class PushExplainerSheet extends StatelessWidget {
  const PushExplainerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      key: PushExplainerKeys.sheet,
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
            ExcludeSemantics(
              child: Icon(
                Icons.notifications_active_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              header: true,
              child: Text(
                l10n.pushExplainerTitle,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.pushExplainerBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: PushExplainerKeys.allow,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.pushExplainerAllow),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              key: PushExplainerKeys.notNow,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.pushExplainerNotNow),
            ),
          ],
        ),
      ),
    );
  }
}
