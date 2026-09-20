// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/features/submit_queue/domain/submit_models.dart';
import 'package:bogner_chess/features/submit_queue/domain/submit_queue_providers.dart';
import 'package:bogner_chess/features/submit_queue/ui/submit_queue_sheet.dart';
import 'package:bogner_chess/features/submit_queue/ui/submit_queue_texts.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The queue surface: one line such as "1 game waiting to upload · offline"
/// with Retry, and nothing at all while every game is on the server. A tap
/// opens the list of waiting games ([showSubmitQueueSheet]).
///
/// It also announces finished uploads with a snack bar on whatever screen is
/// showing, which is why it wants to live where it is always mounted: the
/// tab shell puts it above the navigation bar.
class SubmitQueueBanner extends ConsumerWidget {
  const SubmitQueueBanner({super.key});

  static const Key bannerKey = ValueKey('submit-queue-banner');
  static const Key retryKey = ValueKey('submit-queue-retry');

  static String textOf(AppLocalizations l10n, SubmitQueueStatus status) {
    if (status.uploading && status.waiting > 0) {
      return l10n.submitQueueUploading(status.waiting);
    }
    if (status.waiting == 0) return l10n.submitQueueFailed(status.failed);
    if (status.offline) return l10n.submitQueueWaitingOffline(status.waiting);
    if (status.nextAttemptAt != null) {
      return l10n.submitQueueWaitingRetry(status.waiting);
    }
    return l10n.submitQueueWaiting(status.waiting);
  }

  void _announce(BuildContext context, SubmitEvent event) {
    final l10n = context.l10n;
    final router = GoRouter.of(context);
    final (String text, SnackBarAction action) = switch (event) {
      GameUploaded(:final gameId, :final analysis, :final hold) => (
        switch (analysis) {
          SubmittedAnalysis.notRequested => l10n.submitQueueUploaded,
          SubmittedAnalysis.started => l10n.submitQueueUploadedAnalysing,
          SubmittedAnalysis.held => l10n.submitQueueUploadedHeld(
            analysisHoldText(l10n, hold!),
          ),
        },
        SnackBarAction(
          label: l10n.submitQueueOpenGame,
          onPressed: () => router.go(AppRoutes.game(gameId)),
        ),
      ),
      UploadFailed(:final error) => (
        l10n.submitQueueStateFailed(submitErrorText(l10n, error)),
        SnackBarAction(
          label: l10n.submitQueueDetails,
          onPressed: () {
            final navigator = rootNavigatorKey.currentContext;
            if (navigator != null) unawaited(showSubmitQueueSheet(navigator));
          },
        ),
      ),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), action: action));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(submitQueueEventsProvider, (previous, next) {
      final event = next.value;
      if (event != null && next.hasValue) _announce(context, event);
    });

    final status = ref.watch(submitQueueStatusProvider);
    if (status.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final failedOnly = status.waiting == 0;
    final background = failedOnly
        ? colors.errorContainer
        : colors.secondaryContainer;
    final foreground = failedOnly
        ? colors.onErrorContainer
        : colors.onSecondaryContainer;

    final leading = status.uploading
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : Icon(
            failedOnly
                ? Icons.error_outline
                : status.offline
                ? Icons.cloud_off_outlined
                : Icons.cloud_upload_outlined,
            size: 20,
            color: foreground,
          );
    final text = Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Semantics(
          liveRegion: true,
          child: Text(
            textOf(l10n, status),
            style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
          ),
        ),
      ),
    );
    final retry = status.uploading
        ? null
        : TextButton(
            key: retryKey,
            style: TextButton.styleFrom(foregroundColor: foreground),
            onPressed: () =>
                unawaited(ref.read(submitQueueProvider).retryAll()),
            child: Text(l10n.submitQueueRetry),
          );
    // With large type the button would squeeze the sentence into a column
    // of single letters ("Erneut versuchen" is long): it goes underneath.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 12;

    return Material(
      key: bannerKey,
      color: background,
      child: InkWell(
        onTap: () => unawaited(showSubmitQueueSheet(context)),
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.xs,
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        leading,
                        const SizedBox(width: AppSpacing.sm),
                        text,
                        const SizedBox(width: AppSpacing.sm),
                      ],
                    ),
                    ?retry,
                  ],
                )
              : Row(
                  children: [
                    leading,
                    const SizedBox(width: AppSpacing.sm),
                    text,
                    ?retry,
                  ],
                ),
        ),
      ),
    );
  }
}
