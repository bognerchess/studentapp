// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/api/usage_api.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// The quota as the settings screen shows it (LIM-2). Asked again whenever
/// the settings tab is opened; no silent retries, the row has its own button.
///
/// Local to the settings on purpose: the usage feature has a summary widget
/// of its own, and the coordinator may put that one here instead.
final settingsUsageProvider = FutureProvider.autoDispose<AnalysisUsage>(
  (ref) => ref.watch(usageApiProvider).usage(),
  retry: (_, _) => null,
);

/// Used and allowed analyses for today and for this month, with the reset
/// times; an "Unlimited" badge for accounts without limits.
class SettingsUsage extends ConsumerWidget {
  const SettingsUsage({super.key});

  static const Key retryKey = Key('settings-usage-retry');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final usage = ref.watch(settingsUsageProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: switch (usage) {
        AsyncData(:final value) => _UsageBody(usage: value),
        AsyncError() => Row(
          children: [
            Expanded(
              child: Text(
                l10n.settingsUsageError,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              key: retryKey,
              onPressed: () => ref.invalidate(settingsUsageProvider),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
        _ => Semantics(
          label: l10n.settingsUsageLoading,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: LinearProgressIndicator(),
          ),
        ),
      },
    );
  }
}

class _UsageBody extends StatelessWidget {
  const _UsageBody({required this.usage});

  final AnalysisUsage usage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final unlimited = usage.dailyLimit == null && usage.monthlyLimit == null;
    final now = DateTime.now();
    final dailyReset = usage.dailyResetAt.toLocal();
    final monthlyReset = usage.monthlyResetAt.toLocal();
    final time = DateFormat.Hm(l10n.localeName).format(dailyReset);
    // "at 02:00" is only clear while the reset is within a day.
    final dailyResetText = dailyReset.difference(now).inHours.abs() < 24
        ? l10n.settingsUsageResetsAt(time)
        : l10n.settingsUsageResetsOn(
            DateFormat.MMMMd(l10n.localeName).add_Hm().format(dailyReset),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (unlimited) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.all_inclusive,
                  size: 16,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    l10n.settingsUsageUnlimited,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        _UsageRow(
          label: l10n.settingsUsageToday,
          used: usage.dailyUsed,
          limit: usage.dailyLimit,
          reset: usage.dailyLimit == null ? null : dailyResetText,
        ),
        const SizedBox(height: AppSpacing.md),
        _UsageRow(
          label: l10n.settingsUsageMonth,
          used: usage.monthlyUsed,
          limit: usage.monthlyLimit,
          reset: usage.monthlyLimit == null
              ? null
              : l10n.settingsUsageResetsOn(
                  DateFormat.MMMMd(l10n.localeName).format(monthlyReset),
                ),
        ),
        if (usage.queuedJobs > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.settingsUsageQueued(usage.queuedJobs, usage.maxQueuedJobs),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.label,
    required this.used,
    required this.limit,
    required this.reset,
  });

  final String label;
  final int used;
  final int? limit;
  final String? reset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final limit = this.limit;
    final reached = limit != null && used >= limit;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                limit == null
                    ? l10n.settingsUsageCount(used)
                    : l10n.settingsUsageOf(used, limit),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: reached ? theme.colorScheme.error : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (limit != null) ...[
            const SizedBox(height: AppSpacing.xs),
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: limit <= 0 ? 1 : (used / limit).clamp(0.0, 1.0),
                  color: reached ? theme.colorScheme.error : null,
                ),
              ),
            ),
          ],
          if (reset != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              reached ? '${l10n.settingsUsageLimitReached} $reset' : reset!,
              style: muted,
            ),
          ],
        ],
      ),
    );
  }
}
