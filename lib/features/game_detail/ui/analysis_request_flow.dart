// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/analysis_api.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/game_detail_controller.dart';
import 'game_detail_ids.dart';
import 'game_texts.dart';

/// Requests the analysis of [gameId] and explains whatever comes back.
///
/// Accepted: nothing to say, the screen turns into the progress card. AI
/// consent missing: the consent screen opens; when it pops with `true` the
/// request is sent once more. Everything else is a sheet or a snack bar.
Future<void> runAnalysisRequest(
  BuildContext context,
  WidgetRef ref,
  String gameId,
) async {
  final controller = ref.read(gameDetailControllerProvider(gameId).notifier);
  var outcome = await controller.requestAnalysis();
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
    outcome = await controller.requestAnalysis();
  }
  if (context.mounted) {
    await _explain(context, controller, outcome);
  }
}

Future<void> _explain(
  BuildContext context,
  GameDetailController controller,
  RequestAnalysisOutcome outcome,
) async {
  final l10n = context.l10n;
  switch (outcome) {
    case AnalysisAccepted():
      return;
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

  Future<void> _recheck() async {
    setState(() {
      _busy = true;
      _stillUnverified = false;
    });
    final outcome = await widget.controller.recheckEmailAndRequest();
    if (!mounted) {
      return;
    }
    if (outcome is AnalysisEmailNotVerified) {
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
