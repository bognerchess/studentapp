// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// Semantics identifiers of the library (`accessibilityIdentifier` on iOS).
abstract final class LibraryIds {
  static const String search = 'library-search';
  static const String dateFilter = 'library-date-filter';
  static const String banner = 'library-banner';
  static const String list = 'library-list';

  static String game(String gameId) => 'library-game-$gameId';
  static String draft(String draftId) => 'library-draft-$draftId';
}
