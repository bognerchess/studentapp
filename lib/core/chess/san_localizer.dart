// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/widgets.dart';

/// Chess notation in the reader's language.
///
/// The wire stays English: the analysis document, the verification gate on
/// the server and the replay with `dartchess` all speak English SAN, and
/// nothing here writes back. This is a display filter and nothing else, so
/// the move that is sent, replayed and compared is always the English one.
///
/// German readers expect German piece letters. Everything else about a SAN
/// token — files, ranks, captures, check and mate signs, castling — is the
/// same in both languages and is left untouched.
const Map<String, String> _germanPieceLetters = {
  'K': 'K', // König
  'Q': 'D', // Dame
  'R': 'T', // Turm
  'B': 'L', // Läufer
  'N': 'S', // Springer
};

/// One SAN token, as a whole word.
///
/// The three alternatives are a piece move (with optional disambiguation),
/// a pawn move (with optional capture) and castling. A square always has to
/// be there, which is what keeps ordinary words out: "Bauer" has no rank
/// after the file, and "Dame" and "Springer" do not start with a letter the
/// notation uses at all. A square named as a square ("auf f7") matches the
/// pawn alternative, but a pawn move carries no piece letter, so rewriting
/// it is the identity.
final RegExp _sanToken = RegExp(
  // No letter or digit on either side: `Nf3` in a sentence yes, the `f3`
  // inside a word no. `+`, `#` and `=` are excluded on the right so that a
  // longer token is never matched by its prefix.
  r'(?<![\p{L}\p{N}])'
  r'(?:'
  r'O-O(?:-O)?[+#]?'
  r'|[KQRBN][a-h]?[1-8]?x?[a-h][1-8](?:=[QRBN])?[+#]?'
  r'|[a-h](?:x[a-h])?[1-8](?:=[QRBN])?[+#]?'
  r')'
  r'(?![\p{L}\p{N}+#=])',
  unicode: true,
);

/// The promotion suffix of a token that has one.
final RegExp _promotion = RegExp('=([QRBN])');

/// True for a locale whose readers use German piece letters.
bool _isGerman(Locale locale) => locale.languageCode == 'de';

/// [token], which is known to be a whole SAN token, with its piece letters
/// translated.
String _toGerman(String token) {
  final piece = _germanPieceLetters[token[0]];
  final moved = piece == null ? token : '$piece${token.substring(1)}';
  return moved.replaceFirstMapped(
    _promotion,
    (match) => '=${_germanPieceLetters[match.group(1)]}',
  );
}

/// [san] for a reader of [locale]: `Nf3` stays `Nf3` in English and becomes
/// `Sf3` in German.
///
/// [san] is normally a single token. When it is not — a move label such as
/// `5. Nf3`, or a coach's line label — every token inside it is rewritten,
/// exactly as [localizeSanInText] would.
String localizeSan(String san, Locale locale) =>
    !_isGerman(locale) ? san : localizeSanInText(san, locale);

/// [text] with every SAN token in it rewritten for [locale], and every other
/// word left exactly as it was. The identity for every locale but German.
String localizeSanInText(String text, Locale locale) => !_isGerman(locale)
    ? text
    : text.replaceAllMapped(_sanToken, (match) => _toGerman(match.group(0)!));

/// Chess notation for the locale the widget tree is being built in, which is
/// where the app takes every other user-facing string from as well.
extension SanLocalizationContext on BuildContext {
  /// One SAN token — `best.san`, a move of a line — as this reader writes it.
  String displaySan(String san) =>
      localizeSan(san, Localizations.localeOf(this));

  /// Coach or lesson text with the moves in it as this reader writes them.
  String displaySanInText(String text) =>
      localizeSanInText(text, Localizations.localeOf(this));
}
