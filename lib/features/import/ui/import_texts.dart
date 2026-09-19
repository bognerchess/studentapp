// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/pgn/pgn_import.dart';
import 'package:intl/intl.dart';

/// What is wrong, in the user's language.
String importErrorMessage(AppLocalizations l10n, PgnImportError error) {
  final move = error.moveLabel ?? error.token ?? '';
  return switch (error.code) {
    PgnImportErrorCode.empty ||
    PgnImportErrorCode.noGames => l10n.importErrorNoGames,
    PgnImportErrorCode.tooLarge => l10n.importErrorTooLarge,
    PgnImportErrorCode.tooManyGames => l10n.importErrorTooManyGames(
      error.limit ?? kPgnMaxGames,
    ),
    PgnImportErrorCode.noMoves => l10n.importErrorNoMoves,
    PgnImportErrorCode.customStartPosition => l10n.importErrorCustomStart,
    PgnImportErrorCode.unsupportedVariant => l10n.importErrorVariant(
      error.token ?? '?',
    ),
    PgnImportErrorCode.illegalMove => l10n.importErrorIllegalMove(move),
    PgnImportErrorCode.ambiguousMove => l10n.importErrorAmbiguousMove(move),
    PgnImportErrorCode.unreadableToken =>
      '${l10n.importErrorUnreadable(error.token ?? '')} '
          '${l10n.importErrorUnreadableHint}',
    PgnImportErrorCode.unterminatedComment =>
      l10n.importErrorUnterminatedComment,
    PgnImportErrorCode.unterminatedVariation =>
      l10n.importErrorUnterminatedVariation,
  };
}

/// Where it is wrong, or null when the error is about the text as a whole or
/// about a game's tags.
String? importErrorWhere(AppLocalizations l10n, PgnImportError error) {
  final line = error.line;
  if (line == null) return null;
  switch (error.code) {
    case PgnImportErrorCode.unreadableToken:
      final number = error.moveNumber;
      return number == null
          ? l10n.importErrorWhereLine(line)
          : l10n.importErrorWhereLineMove(line, number);
    case PgnImportErrorCode.illegalMove ||
        PgnImportErrorCode.ambiguousMove ||
        PgnImportErrorCode.unterminatedComment ||
        PgnImportErrorCode.unterminatedVariation:
      return l10n.importErrorWhereLine(line);
    case PgnImportErrorCode.empty ||
        PgnImportErrorCode.noGames ||
        PgnImportErrorCode.tooLarge ||
        PgnImportErrorCode.tooManyGames ||
        PgnImportErrorCode.noMoves ||
        PgnImportErrorCode.customStartPosition ||
        PgnImportErrorCode.unsupportedVariant:
      return null;
  }
}

/// A tag value, or null when the tag is missing, empty or one of PGN's
/// "unknown" spellings.
String? pgnTag(Map<String, String> headers, String name) {
  final value = headers[name]?.trim();
  if (value == null || value.isEmpty || value == '?' || value == '-') {
    return null;
  }
  return value;
}

/// "Anna Example – Bruno Beispiel", with "White" and "Black" standing in for
/// missing names.
String importPlayersLine(
  AppLocalizations l10n,
  Map<String, String> headers, {
  bool withRatings = false,
}) {
  String player(String tag, String fallback) {
    final name = pgnTag(headers, tag) ?? fallback;
    final rating = withRatings ? pgnTag(headers, '${tag}Elo') : null;
    return rating == null || int.tryParse(rating) == null
        ? name
        : '$name ($rating)';
  }

  return l10n.importPlayers(
    player('White', l10n.importPlayerWhite),
    player('Black', l10n.importPlayerBlack),
  );
}

final RegExp _pgnDate = RegExp(
  r'^(\d{4})[.\-/](\d{2}|\?\?)[.\-/](\d{2}|\?\?)$',
);

/// A PGN date ("2026.09.12", "2026.09.??", "2026.??.??") in the user's
/// format, as precise as the tag is; null when not even the year is known.
String? formatPgnDate(String? tag, String locale) {
  final match = _pgnDate.firstMatch(tag?.trim() ?? '');
  if (match == null) return null;
  final year = int.parse(match[1]!);
  final month = int.tryParse(match[2]!);
  final day = int.tryParse(match[3]!);
  if (month == null || month < 1 || month > 12) return '$year';
  try {
    if (day == null || day < 1 || day > 31) {
      return DateFormat.yMMM(locale).format(DateTime(year, month));
    }
    return DateFormat.yMMMd(locale).format(DateTime(year, month, day));
  } on Exception {
    // No date symbols for this locale: the tag itself is still readable.
    return tag;
  }
}

/// "12 Sept 2026 · 1-0 · 17 moves": the second line of a game.
String importFactsLine(
  AppLocalizations l10n,
  PgnImportedGame game,
  String locale,
) {
  final headers = game.headers;
  final date = formatPgnDate(
    pgnTag(headers, 'Date') ?? pgnTag(headers, 'UTCDate'),
    locale,
  );
  final result = switch (game.result) {
    '1/2-1/2' => '½–½',
    '*' => l10n.importResultOpen,
    final decided => decided,
  };
  return [
    ?date,
    result,
    l10n.importMoves((game.plyCount + 1) ~/ 2),
  ].join(' · ');
}
