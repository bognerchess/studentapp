// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/analysis_api.dart';
import 'package:bogner_chess/core/api/stage_api.dart' show AnalysisTargetReason;
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/features/usage/usage.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/game_detail_controller.dart';
import 'game_detail_ids.dart';
import 'game_texts.dart';

/// Analyses the [controller]'s game and explains whatever is missing.
/// [context] must be below a navigator and a scaffold messenger.
///
/// One request runs the whole thing, so there is nothing to say when it works:
/// the card turns into a progress bar and then into "Open analysis". What is
/// left to explain is why there will be no coach text, which the server sends
/// as `targetReason` rather than as an error — the engine analysis runs either
/// way, and every sheet says so.
///
/// A missing AI consent is the one reason with a way out on this screen: the
/// consent screen opens and, when the user agrees, the game is analysed again,
/// this time with the coach.
Future<void> runAnalyse(
  BuildContext context,
  GameDetailController controller,
) async {
  // The coach writes in the language the app is showing.
  final language = Localizations.localeOf(context).languageCode;
  var outcome = await controller.analyse(languageCode: language);
  if (_reasonOf(outcome) == AnalysisTargetReason.aiConsentRequired) {
    if (!context.mounted) {
      return;
    }
    final accepted = await context.push<bool>(AppRoutes.consentAi);
    if (!context.mounted) {
      return;
    }
    if (accepted != true) {
      _snack(context, context.l10n.gameDetailConsentNeeded);
      return;
    }
    outcome = await controller.analyse(languageCode: language);
  }
  if (context.mounted) {
    await _explain(context, controller, outcome);
  }
}

/// Writes the coach's text again over a finished analysis (an account without
/// a limit only). The one path left that asks for a single stage, so the whole
/// set of refusals is still possible.
Future<void> runRerunCoach(
  BuildContext context,
  GameDetailController controller,
) async {
  final language = Localizations.localeOf(context).languageCode;
  var outcome = await controller.rerunCoach(languageCode: language);
  if (outcome is AnalysisAiConsentRequired) {
    if (!context.mounted) {
      return;
    }
    final accepted = await context.push<bool>(AppRoutes.consentAi);
    if (!context.mounted) {
      return;
    }
    if (accepted != true) {
      _snack(context, context.l10n.gameDetailConsentNeeded);
      return;
    }
    outcome = await controller.rerunCoach(languageCode: language);
  }
  if (context.mounted) {
    await _explain(context, controller, outcome);
  }
}

/// The reason the chain stopped short of the coach, when the server took the
/// request and said so. Null for every other outcome.
AnalysisTargetReason? _reasonOf(RequestAnalysisOutcome outcome) =>
    outcome is AnalysisAccepted ? outcome.targetReason : null;

/// What one sentence of [reason] says, for the quiet line on the card.
String targetReasonText(AppLocalizations l10n, AnalysisTargetReason reason) =>
    switch (reason) {
      AnalysisTargetReason.limitReached => l10n.gameDetailReasonLimit,
      AnalysisTargetReason.queueFull => l10n.gameDetailReasonQueue,
      AnalysisTargetReason.rateLimited => l10n.gameDetailReasonRateLimited,
      AnalysisTargetReason.emailNotVerified => l10n.gameDetailReasonEmail,
      AnalysisTargetReason.aiConsentRequired => l10n.gameDetailReasonConsent,
      AnalysisTargetReason.unknown => l10n.gameDetailReasonOther,
    };

/// The engine analysis is on its way and only the coach is missing: a sheet
/// for the two reasons that are worth a page of text, a snack bar for the rest.
Future<void> _explainTargetReason(
  BuildContext context,
  GameDetailController controller,
  AnalysisTargetReason reason,
) async {
  final l10n = context.l10n;
  switch (reason) {
    case AnalysisTargetReason.limitReached:
      // The typed numbers come with a refusal, and this is not one, so the
      // sheet reads them from the usage the screen already has.
      await _showSheet<void>(
        context,
        identifier: GameDetailIds.limitSheet,
        builder: (_) => const _CoachLimitSheet(),
      );
    case AnalysisTargetReason.emailNotVerified:
      final next = await _showSheet<RequestAnalysisOutcome>(
        context,
        builder: (_) => _EmailSheet(controller),
      );
      if (next != null && context.mounted) {
        await _explain(context, controller, next);
      }
    case AnalysisTargetReason.aiConsentRequired:
      // Still required after the user agreed: the consent was not recorded.
      _snack(context, l10n.gameDetailRequestFailed);
    case AnalysisTargetReason.queueFull:
    case AnalysisTargetReason.rateLimited:
    case AnalysisTargetReason.unknown:
      _snack(
        context,
        '${l10n.gameDetailNoCoach(targetReasonText(l10n, reason))} '
        '${l10n.gameDetailAnalysisRunsAnyway}',
      );
  }
}

Future<void> _explain(
  BuildContext context,
  GameDetailController controller,
  RequestAnalysisOutcome outcome,
) async {
  final l10n = context.l10n;
  switch (outcome) {
    case AnalysisAccepted(:final targetReason):
      if (targetReason != null) {
        await _explainTargetReason(context, controller, targetReason);
      }
      return;
    case AnalysisPrerequisiteMissing():
      // Only reachable from `runCoaching`: what the coach reads is not
      // stored any more. Analysing the game again is what fixes it, and the card
      // offers exactly that.
      _snack(context, l10n.gameDetailFailureInputMissing);
    case AnalysisLimitReached():
      await _showSheet<void>(
        context,
        identifier: GameDetailIds.limitSheet,
        builder: (_) => _LimitSheet(outcome),
      );
    case AnalysisQueueFull(:final maxQueuedJobs):
      await _showSheet<void>(
        context,
        builder: (_) => _InfoSheet(
          icon: Icons.hourglass_top,
          title: l10n.gameDetailQueueFullTitle,
          paragraphs: [l10n.gameDetailQueueFullBody(maxQueuedJobs)],
        ),
      );
    case AnalysisRateLimited(:final retryAfter):
      final seconds = retryAfter.inSeconds < 1 ? 1 : retryAfter.inSeconds;
      _snack(context, l10n.gameDetailRateLimited(seconds));
    case AnalysisEmailNotVerified():
      final next = await _showSheet<RequestAnalysisOutcome>(
        context,
        builder: (_) => _EmailSheet(controller),
      );
      if (next != null && context.mounted) {
        await _explain(context, controller, next);
      }
    case AnalysisAiConsentRequired():
      // Still required after the user agreed: the consent was not recorded.
      _snack(context, l10n.gameDetailRequestFailed);
    case AnalysisRequestFailed(:final error):
      _snack(
        context,
        error is ApiNetworkError
            ? l10n.gameDetailRequestOffline
            : l10n.gameDetailRequestFailed,
      );
  }
}

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

Future<T?> _showSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? identifier,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Semantics(
          identifier: identifier,
          container: true,
          child: builder(context),
        ),
      ),
    ),
  );
}

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({
    required this.icon,
    required this.title,
    required this.paragraphs,
    this.footer,
    this.action,
  });

  final IconData icon;
  final String title;
  final List<String> paragraphs;

  /// Smaller, secondary text under the paragraphs.
  final String? footer;

  /// Replaces the plain "Close" button.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final paragraph in paragraphs) ...[
          Text(paragraph, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (footer != null)
          Text(
            footer!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        action ??
            Identified(
              GameDetailIds.sheetClose,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.gameDetailSheetClose),
              ),
            ),
      ],
    );
  }
}

/// LIM-2: what the limit is, when it resets (local time), and that
/// everything except new analyses stays available.
class _LimitSheet extends StatelessWidget {
  const _LimitSheet(this.outcome);

  final AnalysisLimitReached outcome;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final when = formatResetAt(l10n, outcome.resetAt, DateTime.now());
    final (title, body) = switch (outcome.window) {
      LimitWindow.day => (
        l10n.gameDetailLimitTitleDay,
        l10n.gameDetailLimitBodyDay(outcome.limit),
      ),
      LimitWindow.month => (
        l10n.gameDetailLimitTitleMonth,
        l10n.gameDetailLimitBodyMonth(outcome.limit),
      ),
      LimitWindow.unknown => (
        l10n.gameDetailLimitTitleOther,
        l10n.gameDetailLimitBodyOther(outcome.limit),
      ),
    };
    return _InfoSheet(
      icon: Icons.event_available,
      title: title,
      paragraphs: [
        body,
        l10n.gameDetailLimitReset(when),
        l10n.gameDetailLimitSaved,
      ],
      footer: l10n.gameDetailLimitFree,
    );
  }
}

/// LIM-2 on the one-button path: the coach's quota is used up, which is not a
/// refusal — the analysis itself is running. The numbers come from
/// `myAnalysisUsage` rather than from an error, because there is no error.
class _CoachLimitSheet extends ConsumerWidget {
  const _CoachLimitSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final usage = ref.watch(usageProvider).value;
    final monthly = usage != null && usage.monthlyRemaining == 0;
    final limit = (monthly ? usage.monthlyLimit : usage?.dailyLimit) ?? 0;
    final resetAt = monthly ? usage.monthlyResetAt : usage?.dailyResetAt;
    return _InfoSheet(
      icon: Icons.event_available,
      title: monthly
          ? l10n.gameDetailLimitTitleMonth
          : l10n.gameDetailLimitTitleDay,
      paragraphs: [
        if (limit > 0)
          monthly
              ? l10n.gameDetailLimitBodyMonth(limit)
              : l10n.gameDetailLimitBodyDay(limit),
        if (resetAt != null)
          l10n.gameDetailLimitReset(
            formatResetAt(l10n, resetAt, DateTime.now()),
          ),
        l10n.gameDetailAnalysisRunsAnyway,
      ],
      footer: l10n.gameDetailLimitFree,
    );
  }
}

/// LIM-4: analyses need a confirmed e-mail address. The button fetches fresh
/// tokens and asks again; the sheet pops with the outcome of that request,
/// unless the address is still unconfirmed, which it says itself.
class _EmailSheet extends StatefulWidget {
  const _EmailSheet(this.controller);

  final GameDetailController controller;

  @override
  State<_EmailSheet> createState() => _EmailSheetState();
}

class _EmailSheetState extends State<_EmailSheet> {
  bool _busy = false;
  bool _stillUnverified = false;

  String get _language => Localizations.localeOf(context).languageCode;

  Future<void> _recheck() async {
    setState(() {
      _busy = true;
      _stillUnverified = false;
    });
    final outcome = await widget.controller.recheckEmailAndAnalyse(
      languageCode: _language,
    );
    if (!mounted) {
      return;
    }
    // Either shape says the same thing: `analyseGame` reports it as the reason
    // the chain stopped short of the coach, `runCoaching` as a refusal.
    final still =
        outcome is AnalysisEmailNotVerified ||
        _reasonOf(outcome) == AnalysisTargetReason.emailNotVerified;
    if (still) {
      setState(() {
        _busy = false;
        _stillUnverified = true;
      });
    } else {
      Navigator.of(context).pop(outcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return _InfoSheet(
      icon: Icons.mark_email_unread_outlined,
      title: l10n.gameDetailEmailTitle,
      paragraphs: [l10n.gameDetailEmailBody],
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_stillUnverified) ...[
            Text(
              l10n.gameDetailEmailStill,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Identified(
            GameDetailIds.emailRecheck,
            child: FilledButton(
              onPressed: _busy ? null : _recheck,
              child: Text(l10n.gameDetailEmailAction),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.gameDetailSheetClose),
          ),
        ],
      ),
    );
  }
}
