// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/push/push_platform.dart';
import 'package:bogner_chess/core/push/push_service.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// For the settings screen: when iOS says notifications are denied, the app
/// cannot ask again, so it says where to change that and opens the Settings
/// app. Takes no space in every other case.
class PushDeniedHint extends ConsumerWidget {
  const PushDeniedHint({super.key});

  static const Key openSettingsKey = Key('pushDeniedHint.openSettings');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(pushPermissionStatusProvider).value;
    if (status != PushPermissionStatus.denied) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pushSettingsDeniedHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TextButton(
            key: openSettingsKey,
            onPressed: () => ref.read(pushServiceProvider).openSystemSettings(),
            child: Text(l10n.pushSettingsOpenSettings),
          ),
        ],
      ),
    );
  }
}
