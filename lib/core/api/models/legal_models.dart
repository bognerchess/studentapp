// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/foundation.dart';

/// The legal texts of the app. [unknown] is only ever read, never sent.
enum LegalDocumentKey {
  aiConsent,
  privacyPolicy,
  terms,
  analyticsConsent,
  unknown,
}

/// The current version of a legal text.
@immutable
class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.key,
    required this.version,
    required this.language,
    required this.title,
    required this.bodyMarkdown,
    required this.publishedAt,
    required this.isDraft,
    this.providerName,
  });

  final String id;
  final LegalDocumentKey key;

  /// The version to record a consent for.
  final int version;

  /// The language of this text; "en" when the requested one does not exist.
  final String language;
  final String title;
  final String bodyMarkdown;

  /// For the AI consent: who processes the game.
  final String? providerName;
  final DateTime publishedAt;

  /// True for a placeholder that has not been legally reviewed.
  final bool isDraft;
}

/// Whether the user has accepted the current version of a legal text.
@immutable
class ConsentStatus {
  const ConsentStatus({
    required this.key,
    required this.currentVersion,
    required this.required,
    this.acceptedVersion,
    this.withdrawnAt,
  });

  final LegalDocumentKey key;

  /// The version to present; 0 when none is published.
  final int currentVersion;

  /// The highest version the user has accepted and not withdrawn.
  final int? acceptedVersion;

  /// True until the user has accepted [currentVersion].
  final bool required;

  /// When the user last withdrew or refused; null while an acceptance is
  /// live. Always null for the AI consent, which the server does not report.
  final DateTime? withdrawnAt;

  @override
  String toString() =>
      'ConsentStatus(${key.name}, current $currentVersion, '
      'accepted $acceptedVersion, required $required)';
}
