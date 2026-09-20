// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/widgets/app_scaffold.dart';
import 'package:bogner_chess/router.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/legal_documents.dart';
import 'legal_l10n.dart';

/// The list of legal texts (`/settings/legal`). The settings screen links to
/// the documents directly; this screen is what a link to "the legal section"
/// opens.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      title: l10n.legalTitle,
      body: ListView(
        children: [
          for (final page in LegalPage.values)
            ListTile(
              leading: Icon(legalPageIcon(page)),
              title: Text(legalPageTitle(l10n, page)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.legalDocument(page.slug)),
            ),
        ],
      ),
    );
  }
}
