// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// Text that goes into a crash report (exception messages, breadcrumbs) is
/// written for developers, but it can quote what the user typed: a
/// `FormatException` shows its source, which here is often a PGN with the
/// players' names. [scrubCrashText] removes what could be user content and
/// keeps what a developer needs, the kind of error and where it came from.
///
/// Removed, in this order:
///
/// 1. PGN tag pairs (`[White "Muster, Hans"]`) and anything else in double
///    or single quotes: names, PGN, server messages.
/// 2. E-mail addresses.
/// 3. FEN strings.
/// 4. Things that look like tokens: JWTs and long base64 or hex runs.
/// 5. Chess moves: two or more SAN tokens in a row, or one with its move
///    number.
/// 6. Ids in paths (`/games/<id>/review` keeps its shape).
///
/// The result is cut to [kMaxCrashTextLength] characters.
const int kMaxCrashTextLength = 300;

final RegExp _pgnTag = RegExp(r'\[\s*[A-Za-z0-9_]+\s+"[^"\n]*"\s*\]');
final RegExp _doubleQuoted = RegExp(r'"[^"\n]*"');
final RegExp _singleQuoted = RegExp(r"'[^'\n]*'");
final RegExp _email = RegExp(
  r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}',
);
final RegExp _jwt = RegExp(
  r'\b[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\b',
);
final RegExp _longToken = RegExp(r'\b[A-Za-z0-9_\-+/=]{32,}\b');
final RegExp _fen = RegExp(
  r'\b(?:[pnbrqkPNBRQK1-8]{1,8}/){7}[pnbrqkPNBRQK1-8]{1,8}(?:\s+[wb]\s+\S+\s+\S+(?:\s+\d+\s+\d+)?)?',
);

const String _san =
    r'(?:O-O(?:-O)?|[KQRBN]?[a-h]?[1-8]?x?[a-h][1-8](?:=[QRBN])?)[+#]?[!?]{0,2}';
final RegExp _moves = RegExp(
  '(?:(?:\\d+\\.(?:\\.\\.)?\\s*)?$_san(?:\\s+|\$)){2,}',
);
final RegExp _numberedMove = RegExp('\\b\\d+\\.(?:\\.\\.)?\\s*$_san');
final RegExp _pathId = RegExp(r'(/(?:games|jobs|drafts)/)[^/\s?#]+');

String scrubCrashText(String text) {
  var result = text
      .replaceAll(_pgnTag, '[<pgn tag>]')
      .replaceAll(_doubleQuoted, '"<redacted>"')
      .replaceAll(_singleQuoted, "'<redacted>'")
      .replaceAll(_email, '<email>')
      // Before the tokens: a FEN's board part is a long run of their alphabet.
      .replaceAll(_fen, '<fen>')
      .replaceAll(_jwt, '<token>')
      .replaceAll(_longToken, '<token>')
      .replaceAll(_moves, '<moves> ')
      .replaceAll(_numberedMove, '<moves>')
      .replaceAllMapped(_pathId, (match) => '${match[1]}:id');
  if (result.length > kMaxCrashTextLength) {
    result = '${result.substring(0, kMaxCrashTextLength)}…';
  }
  return result.trimRight();
}

/// Breadcrumb data that may pass, by key. Everything else is removed: a
/// breadcrumb's data is an open map, and an allow-list cannot be surprised by
/// a new key of a new SDK version.
const Set<String> kAllowedBreadcrumbDataKeys = {
  'state', // app life cycle
  'status_code',
  'method',
  'reason',
  'action',
  'level',
};

/// Categories that are dropped whole: what the user tapped or typed, what
/// the app printed, and requests (one GraphQL endpoint, so the URL says
/// nothing, while query strings could say too much).
const Set<String> kDroppedBreadcrumbCategories = {
  'console',
  'http',
  'ui.click',
  'ui.input',
  'touch',
  'xhr',
};
