// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/consent/consent_state.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/core/ui/widgets/app_markdown.dart';
import 'package:bogner_chess/core/ui/widgets/draft_badge.dart';
import 'package:bogner_chess/core/ui/widgets/empty_state.dart';
import 'package:bogner_chess/core/ui/widgets/error_retry.dart';
import 'package:bogner_chess/features/legal/domain/legal_documents.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// The permission step before a game goes to a third-party AI (App Store
/// guideline 5.1.2(i), PRD PL-2). Full screen.
///
/// Open it with `final agreed = await context.push<bool>(AppRoutes.consentAi)`:
/// it pops with true once the server has recorded the acceptance, with false
/// for "Not now" and the close button. The text, its version and the name of
/// the provider come from the backend, so a change of model needs no release;
/// the box that lists what is and is not sent is the app's own and states
/// what the backend's data-minimisation rule guarantees.
///
/// Consent cannot be given offline: the acceptance has to reach the server
/// before the server may send anything on.
class AiConsentScreen extends ConsumerStatefulWidget {
  const AiConsentScreen({super.key});

  static const Key agreeKey = Key('ai-consent-agree');
  static const Key notNowKey = Key('ai-consent-not-now');
  static const Key withdrawKey = Key('ai-consent-withdraw');
  static const Key scrollKey = Key('ai-consent-scroll');

  @override
  ConsumerState<AiConsentScreen> createState() => _AiConsentScreenState();
}

class _AiConsentScreenState extends ConsumerState<AiConsentScreen> {
  bool _busy = false;
  bool _failed = false;

  void _close(bool agreed) {
    if (context.canPop()) {
      context.pop(agreed);
    } else {
      // Reached by a link, with nothing underneath.
      context.go(AppRoutes.initial);
    }
  }

  Future<void> _run(Future<void> Function() action, {bool? thenClose}) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() => _busy = false);
      if (thenClose != null) _close(thenClose);
    } on ApiError {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final request = (key: LegalDocumentKey.aiConsent, language: language);
    final document = ref.watch(legalDocumentProvider(request));
    final status = ref.watch(aiConsentStatusProvider).value;
    final isProd = ref.watch(envProvider).isProd;

    void retry() {
      ref.invalidate(legalDocumentProvider(request));
      if (ref.read(aiConsentStatusProvider).hasError) {
        ref.invalidate(aiConsentStatusProvider);
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.consentAiClose,
          onPressed: _busy ? null : () => _close(false),
        ),
        title: Text(l10n.consentAiTitle),
      ),
      body: SafeArea(
        child: switch (document) {
          // A placeholder text nobody has reviewed is good enough to test
          // with, and not good enough to ask a real user for consent.
          AsyncData(:final value?) when !(value.isDraft && isProd) =>
            _ConsentBody(
              document: value,
              accepted:
                  status != null &&
                  !status.required &&
                  status.acceptedVersion == value.version,
              busy: _busy,
              failed: _failed,
              onAgree: () => _run(
                () => ref
                    .read(aiConsentStatusProvider.notifier)
                    .accept(value.version),
                thenClose: true,
              ),
              onNotNow: () => _close(false),
              onWithdraw: () => _run(
                () => ref
                    .read(aiConsentStatusProvider.notifier)
                    .withdraw(value.version),
              ),
            ),
          AsyncData() => EmptyState(
            icon: Icons.hourglass_empty,
            title: l10n.consentAiUnavailableTitle,
            message: l10n.consentAiUnavailableMessage,
            actionLabel: l10n.commonRetry,
            onAction: retry,
          ),
          AsyncError(:final error) => ErrorRetry(
            title: error is ApiNetworkError ? l10n.consentAiOfflineTitle : null,
            message: error is ApiNetworkError
                ? l10n.consentAiOfflineMessage
                : l10n.consentAiErrorMessage,
            onRetry: retry,
          ),
          _ => Center(
            child: CircularProgressIndicator(
              semanticsLabel: l10n.consentAiLoading,
            ),
          ),
        },
      ),
    );
  }
}

class _ConsentBody extends StatelessWidget {
  const _ConsentBody({
    required this.document,
    required this.accepted,
    required this.busy,
    required this.failed,
    required this.onAgree,
    required this.onNotNow,
    required this.onWithdraw,
  });

  final LegalDocument document;

  /// The user has already agreed to exactly this version (the screen was
  /// opened from the settings to read the text again).
  final bool accepted;
  final bool busy;
  final bool failed;
  final VoidCallback onAgree;
  final VoidCallback onNotNow;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final provider = document.providerName?.trim();
    final published = DateFormat.yMMMMd(l10n.localeName)
        .format(document.publishedAt.toLocal());

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: AiConsentScreen.scrollKey,
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (document.isDraft) ...[
                  const DraftBadge(),
                  const SizedBox(height: AppSpacing.md),
                ],
                Semantics(
                  header: true,
                  child: Text(
                    document.title,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _ProviderCard(
                  text: provider == null || provider.isEmpty
                      ? l10n.consentAiProviderUnnamed
                      : l10n.consentAiProvider(provider),
                  emphasis: provider,
                ),
                const SizedBox(height: AppSpacing.md),
                _SummaryBox(
                  icon: Icons.upload_outlined,
                  iconColor: colors.primary,
                  title: l10n.consentAiSentTitle,
                  items: [
                    l10n.consentAiSentMoves,
                    l10n.consentAiSentPositions,
                    l10n.consentAiSentEvaluations,
                    l10n.consentAiSentColour,
                    l10n.consentAiSentRatingBand,
                  ],
                  itemIcon: Icons.check,
                ),
                const SizedBox(height: AppSpacing.sm),
                _SummaryBox(
                  icon: Icons.shield_outlined,
                  iconColor: colors.primary,
                  title: l10n.consentAiNotSentTitle,
                  items: [
                    l10n.consentAiNotSentName,
                    l10n.consentAiNotSentEmail,
                    l10n.consentAiNotSentAccount,
                    l10n.consentAiNotSentEvent,
                  ],
                  itemIcon: Icons.block,
                ),
                const SizedBox(height: AppSpacing.lg),
                // The plain-language facts first, the legal wording after.
                AppMarkdown(document.bodyMarkdown),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.legalVersionLine(document.version, published),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (failed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.consentAiSaveFailed,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (accepted) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: AppColors.of(context).success,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(child: Text(l10n.consentAiAlreadyAgreed)),
                    ],
                  ),
                ),
                OutlinedButton(
                  key: AiConsentScreen.withdrawKey,
                  onPressed: busy ? null : onWithdraw,
                  child: Text(l10n.consentAiWithdraw),
                ),
              ] else ...[
                FilledButton(
                  key: AiConsentScreen.agreeKey,
                  onPressed: busy ? null : onAgree,
                  child: busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.consentAiAgree),
                ),
                TextButton(
                  key: AiConsentScreen.notNowKey,
                  onPressed: busy ? null : onNotNow,
                  child: Text(l10n.consentAiNotNow),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "Analysis comments are generated by (provider)", the one sentence App
/// Review looks for, so it gets a box of its own above the text.
class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.text, this.emphasis});

  final String text;
  final String? emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = theme.textTheme.bodyLarge?.copyWith(
      color: colors.onSecondaryContainer,
    );
    final name = emphasis;
    final at = name == null || name.isEmpty ? -1 : text.indexOf(name);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_outlined, color: colors.onSecondaryContainer),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: at < 0
                ? Text(text, style: style)
                : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: text.substring(0, at)),
                        TextSpan(
                          text: name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: text.substring(at + name!.length)),
                      ],
                    ),
                    style: style,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.items,
    required this.itemIcon,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> items;
  final IconData itemIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.titleSmall),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      itemIcon,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(item, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
