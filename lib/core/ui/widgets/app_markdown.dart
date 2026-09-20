// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/links/link_launcher.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Markdown from the backend (legal texts, the AI consent text) in the app's
/// typography. The only importer of `flutter_markdown_plus`.
///
/// Not scrollable: put it into a scroll view. Links open outside the app
/// through [linkLauncherProvider]; only `https` and `mailto` are followed.
/// Images are not loaded: these texts need none, and fetching one would be a
/// network request to wherever the text points.
class AppMarkdown extends ConsumerWidget {
  const AppMarkdown(this.data, {super.key});

  final String data;

  /// Whether [data] opens with a first-level heading of its own. A screen
  /// that would print the document's title above the text leaves it out
  /// then, instead of saying the same thing twice.
  static bool startsWithTitle(String data) =>
      data.trimLeft().startsWith(RegExp(r'#\s'));

  /// The schemes a link in a served text may use.
  static const Set<String> allowedSchemes = {'https', 'mailto'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final colors = theme.colorScheme;
    final body = text.bodyLarge?.copyWith(
      color: colors.onSurface,
      height: 1.45,
    );
    TextStyle? heading(TextStyle? style) =>
        style?.copyWith(color: colors.onSurface, fontWeight: FontWeight.w600);

    return MarkdownBody(
      data: data,
      // The package reads the framework's legacy Material theme, which this
      // app (built on package:material_ui) does not install. Every style it
      // would take from there is given here instead.
      styleSheet: MarkdownStyleSheet(
        a: body?.copyWith(
          color: colors.primary,
          decoration: TextDecoration.underline,
          decorationColor: colors.primary,
        ),
        p: body,
        pPadding: EdgeInsets.zero,
        code: text.bodyMedium?.copyWith(
          fontFamily: 'Menlo',
          color: colors.onSurface,
          backgroundColor: colors.surfaceContainerHighest,
        ),
        h1: heading(text.headlineSmall),
        h1Padding: const EdgeInsets.only(top: AppSpacing.sm),
        h2: heading(text.titleLarge),
        h2Padding: const EdgeInsets.only(top: AppSpacing.sm),
        h3: heading(text.titleMedium),
        h3Padding: const EdgeInsets.only(top: AppSpacing.xs),
        h4: heading(text.titleSmall),
        h4Padding: EdgeInsets.zero,
        h5: heading(text.titleSmall),
        h5Padding: EdgeInsets.zero,
        h6: heading(text.titleSmall),
        h6Padding: EdgeInsets.zero,
        em: const TextStyle(fontStyle: FontStyle.italic),
        strong: const TextStyle(fontWeight: FontWeight.w700),
        del: const TextStyle(decoration: TextDecoration.lineThrough),
        blockquote: body,
        img: body,
        checkbox: body?.copyWith(color: colors.primary),
        blockSpacing: AppSpacing.md,
        listIndent: AppSpacing.lg,
        listBullet: body,
        listBulletPadding: const EdgeInsets.only(right: AppSpacing.xs),
        tableHead: body?.copyWith(fontWeight: FontWeight.w600),
        tableBody: body,
        tableHeadAlign: TextAlign.start,
        tablePadding: const EdgeInsets.only(bottom: AppSpacing.xs),
        tableBorder: TableBorder.all(color: colors.outlineVariant),
        tableColumnWidth: const IntrinsicColumnWidth(),
        tableCellsPadding: const EdgeInsets.all(AppSpacing.sm),
        blockquotePadding: const EdgeInsets.only(left: AppSpacing.md),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: colors.outlineVariant, width: 3),
          ),
        ),
        codeblockPadding: const EdgeInsets.all(AppSpacing.sm),
        codeblockDecoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        textScaler: MediaQuery.textScalerOf(context),
      ),
      imageBuilder: (uri, title, alt) =>
          alt == null || alt.isEmpty ? const SizedBox.shrink() : Text(alt),
      onTapLink: (text, href, title) {
        final uri = href == null ? null : Uri.tryParse(href);
        if (uri == null || !allowedSchemes.contains(uri.scheme)) {
          return;
        }
        // A link that cannot be opened is not worth an error message in the
        // middle of a legal text.
        unawaited(
          ref.read(linkLauncherProvider)(uri).catchError((Object _) => false),
        );
      },
    );
  }
}
