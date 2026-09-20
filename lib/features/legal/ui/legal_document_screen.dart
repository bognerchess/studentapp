// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/core/ui/widgets/app_markdown.dart';
import 'package:bogner_chess/core/ui/widgets/draft_badge.dart';
import 'package:bogner_chess/core/ui/widgets/empty_state.dart';
import 'package:bogner_chess/core/ui/widgets/error_retry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/legal_documents.dart';
import 'legal_l10n.dart';

/// One legal text from the backend: title, version and date, the Markdown
/// body. The text is fetched every time, so a new version needs no release.
class LegalDocumentScreen extends ConsumerWidget {
  const LegalDocumentScreen({super.key, required this.page});

  final LegalPage page;

  /// The scroll view, for tests and the demo entry point.
  static const Key scrollKey = Key('legal-document-scroll');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final request = (key: page.key, language: language);
    final document = ref.watch(legalDocumentProvider(request));

    return Scaffold(
      appBar: AppBar(title: Text(legalPageTitle(l10n, page))),
      body: SafeArea(
        child: switch (document) {
          AsyncData(:final value?) => _DocumentBody(
            document: value,
            requestedLanguage: language,
          ),
          AsyncData() => EmptyState(
            icon: Icons.description_outlined,
            title: l10n.legalNotPublishedTitle,
            message: l10n.legalNotPublishedMessage,
          ),
          AsyncError(:final error) => ErrorRetry(
            title: error is ApiNetworkError ? l10n.legalOfflineTitle : null,
            message: error is ApiNetworkError ? l10n.legalOfflineMessage : null,
            onRetry: () => ref.invalidate(legalDocumentProvider(request)),
          ),
          _ => Center(
            child: CircularProgressIndicator(semanticsLabel: l10n.legalLoading),
          ),
        },
      ),
    );
  }
}

class _DocumentBody extends StatelessWidget {
  const _DocumentBody({
    required this.document,
    required this.requestedLanguage,
  });

  final LegalDocument document;
  final String requestedLanguage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final published = DateFormat.yMMMMd(l10n.localeName)
        .format(document.publishedAt.toLocal());
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return SingleChildScrollView(
      key: LegalDocumentScreen.scrollKey,
      padding: const EdgeInsets.all(AppSpacing.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (document.isDraft) ...[
            const DraftBadge(),
            const SizedBox(height: AppSpacing.md),
          ],
          if (!AppMarkdown.startsWithTitle(document.bodyMarkdown)) ...[
            Semantics(
              header: true,
              child: Text(document.title, style: theme.textTheme.headlineSmall),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            l10n.legalVersionLine(document.version, published),
            style: muted,
          ),
          if (document.language != requestedLanguage) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.legalEnglishOnly, style: muted),
          ],
          const SizedBox(height: AppSpacing.md),
          AppMarkdown(document.bodyMarkdown),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
