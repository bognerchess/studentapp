// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/consent/consent_state.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/core/ui/widgets/app_markdown.dart';
import 'package:bogner_chess/core/ui/widgets/draft_badge.dart';
import 'package:bogner_chess/features/legal/domain/legal_documents.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// The one-time question "may the app send usage statistics and crash
/// reports?". A sheet, not a wall: it can be swiped away, which leaves the
/// switch off (opt-in), and the same switch is in the settings.
///
/// [document] is the backend's `ANALYTICS_CONSENT` text when it could be
/// fetched; its version is recorded with the answer. Without it (offline)
/// the app's own wording is shown and the record follows later.
Future<void> showAnalyticsConsentSheet(
  BuildContext context, {
  LegalDocument? document,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => AnalyticsConsentSheet(document: document),
  );
}

class AnalyticsConsentSheet extends ConsumerWidget {
  const AnalyticsConsentSheet({super.key, this.document});

  final LegalDocument? document;

  static const Key allowKey = Key('analytics-consent-allow');
  static const Key declineKey = Key('analytics-consent-decline');
  static const Key privacyKey = Key('analytics-consent-privacy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final document = this.document;

    void answer({required bool granted}) {
      unawaited(
        ref
            .read(analyticsConsentProvider.notifier)
            .set(granted: granted, shownVersion: document?.version),
      );
      Navigator.of(context).pop();
    }

    return SingleChildScrollView(
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
          if (document != null && document.isDraft) ...[
            const DraftBadge(),
            const SizedBox(height: AppSpacing.md),
          ],
          Semantics(
            header: true,
            child: Text(
              document?.title ?? l10n.consentAnalyticsTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (document != null)
            AppMarkdown(document.bodyMarkdown)
          else
            Text(l10n.consentAnalyticsBody, style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.consentAnalyticsFootnote,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: privacyKey,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              // Above the sheet, so that "back" returns to the question.
              onPressed: () =>
                  context.push(AppRoutes.legalDocument(LegalPage.privacy.slug)),
              child: Text(l10n.legalPrivacyPolicy),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: allowKey,
            onPressed: () => answer(granted: true),
            child: Text(l10n.consentAnalyticsAllow),
          ),
          TextButton(
            key: declineKey,
            onPressed: () => answer(granted: false),
            child: Text(l10n.consentAnalyticsDecline),
          ),
        ],
      ),
    );
  }
}
