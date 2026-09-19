// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/core/ui/widgets/app_scaffold.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The "Settings" tab. For now only the entries that lead to the account,
/// legal and about screens, and the version. WP-30 extends this file.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final appInfo = ref.watch(appInfoProvider).value;
    return AppScaffold(
      title: l10n.settingsTitle,
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.settingsAccount),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(AppRoutes.settingsAccount),
          ),
          const Divider(indent: AppSpacing.md, endIndent: AppSpacing.md),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.settingsLegal),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(AppRoutes.settingsLegal),
          ),
          const Divider(indent: AppSpacing.md, endIndent: AppSpacing.md),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsAbout),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(AppRoutes.settingsAbout),
          ),
          if (appInfo != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                l10n.settingsVersion(appInfo.version, appInfo.buildNumber),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
