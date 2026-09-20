// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/legal_documents.dart';

/// The app's own name for a legal text, used until (and in lists instead of)
/// the title the backend serves.
String legalPageTitle(AppLocalizations l10n, LegalPage page) => switch (page) {
  LegalPage.privacy => l10n.legalPrivacyPolicy,
  LegalPage.terms => l10n.legalTerms,
};

IconData legalPageIcon(LegalPage page) => switch (page) {
  LegalPage.privacy => Icons.privacy_tip_outlined,
  LegalPage.terms => Icons.description_outlined,
};
