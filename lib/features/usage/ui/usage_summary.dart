// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/usage_providers.dart';

/// How much room [UsageSummary] takes.
enum UsageSummaryStyle {
  /// One line of secondary text, e.g. under the "Analyse" button. Shows
  /// nothing for an account without limits and nothing while the numbers are
  /// not known.
  line,

  /// A titled block with the daily and the monthly line, for the settings
  /// screen. Says "Unlimited analyses" for an account without limits.
  block,
}

/// Remaining analyses and when the limit resets (LIM-2).
///
/// Reads [usageProvider] itself; drop it anywhere. Reset instants are shown
/// in the device's time zone.
class UsageSummary extends ConsumerWidget {
  const UsageSummary({
    super.key,
    this.style = UsageSummaryStyle.line,
    this.textAlign = TextAlign.center,
  });

  final UsageSummaryStyle style;
  final TextAlign textAlign;

  static const String semanticsId = 'usage-summary';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(usageProvider);
    return switch (style) {
      UsageSummaryStyle.line => _line(context, usage.value),
      UsageSummaryStyle.block => _block(context, usage),
    };
  }

  Widget _line(BuildContext context, AnalysisUsage? usage) {
    final text = usage == null ? null : usageHeadline(context.l10n, usage);
    if (text == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final exhausted = !_hasQuota(usage!);
    return Semantics(
      identifier: semanticsId,
      child: Text(
        text,
        textAlign: textAlign,
        style: theme.textTheme.bodySmall?.copyWith(
          color: exhausted
              ? AppColors.of(context).warning
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _block(BuildContext context, AsyncValue<AnalysisUsage> usage) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final value = usage.value;
    final lines = <String>[
      if (value == null)
        if (usage.hasError) l10n.usageUnavailable else '…'
      else if (_isUnlimited(value))
        l10n.usageUnlimited
      else ...[?usageDailyLine(l10n, value), ?usageMonthlyLine(l10n, value)],
    ];
    return Semantics(
      identifier: semanticsId,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.usageTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          for (final line in lines) Text(line, style: secondary),
        ],
      ),
    );
  }
}

bool _isUnlimited(AnalysisUsage usage) =>
    usage.dailyLimit == null && usage.monthlyLimit == null;

bool _hasQuota(AnalysisUsage usage) =>
    (usage.dailyRemaining ?? 1) > 0 && (usage.monthlyRemaining ?? 1) > 0;

/// The one line that matters most: the month when it is used up, else the
/// day, else the month. Null for an account without limits.
String? usageHeadline(AppLocalizations l10n, AnalysisUsage usage) {
  if (usage.monthlyRemaining == 0) {
    return usageMonthlyLine(l10n, usage);
  }
  return usageDailyLine(l10n, usage) ?? usageMonthlyLine(l10n, usage);
}

String? usageDailyLine(AppLocalizations l10n, AnalysisUsage usage) {
  final limit = usage.dailyLimit;
  final remaining = usage.dailyRemaining;
  if (limit == null || remaining == null) {
    return null;
  }
  final time = DateFormat.jm(l10n.localeName)
      .format(usage.dailyResetAt.toLocal());
  return remaining == 0
      ? l10n.usageDailyNone(time)
      : l10n.usageDailyLeft(remaining, limit, time);
}

String? usageMonthlyLine(AppLocalizations l10n, AnalysisUsage usage) {
  final limit = usage.monthlyLimit;
  final remaining = usage.monthlyRemaining;
  if (limit == null || remaining == null) {
    return null;
  }
  final date = DateFormat.MMMd(l10n.localeName)
      .format(usage.monthlyResetAt.toLocal());
  return remaining == 0
      ? l10n.usageMonthlyNone(date)
      : l10n.usageMonthlyLeft(remaining, limit, date);
}
