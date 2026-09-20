// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/api/legal_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:bogner_chess/core/api/legal_api.dart'
    show ApiError, ApiNetworkError, LegalDocument, LegalDocumentKey;

/// The legal texts a user can open by themselves, with the slug of their
/// location (`AppRoutes.legalDocument(page.slug)`).
enum LegalPage {
  privacy('privacy', LegalDocumentKey.privacyPolicy),
  terms('terms', LegalDocumentKey.terms);

  const LegalPage(this.slug, this.key);

  final String slug;
  final LegalDocumentKey key;

  static LegalPage? ofSlug(String? slug) {
    for (final page in values) {
      if (page.slug == slug) return page;
    }
    return null;
  }
}

/// Which text, in which language ("de"). The server answers in English when
/// it has no such translation.
typedef LegalDocumentRequest = ({LegalDocumentKey key, String language});

/// The current version of a legal text; null when nothing is published.
/// Fetched whenever a screen opens (the text is the server's to change), and
/// not retried by itself: the screens have a retry button.
final legalDocumentProvider = FutureProvider.autoDispose
    .family<LegalDocument?, LegalDocumentRequest>(
      (ref, request) => ref
          .watch(legalApiProvider)
          .document(request.key, language: request.language),
      retry: (_, _) => null,
    );
