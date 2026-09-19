// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Bogner Chess';

  @override
  String get tabGames => 'Partien';

  @override
  String get tabNewGame => 'Neue Partie';

  @override
  String get tabSettings => 'Einstellungen';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonErrorTitle => 'Etwas ist schiefgelaufen';

  @override
  String get commonErrorMessage =>
      'Bitte prüfe deine Verbindung und versuche es erneut.';

  @override
  String get commonPlaceholderMessage =>
      'Dieser Bildschirm ist noch nicht gebaut.';

  @override
  String get notFoundTitle => 'Seite nicht gefunden';

  @override
  String get notFoundMessage => 'Dieser Link führt in der App nirgendwohin.';

  @override
  String get notFoundAction => 'Zu meinen Partien';

  @override
  String get libraryTitle => 'Partien';

  @override
  String get libraryEmptyTitle => 'Noch keine Partien';

  @override
  String get libraryEmptyMessage =>
      'Gib eine Partie ein oder importiere eine PGN-Datei, um sie analysieren zu lassen.';

  @override
  String get libraryEmptyAction => 'Neue Partie';

  @override
  String get libraryGameTitle => 'Partie';

  @override
  String get newGameTitle => 'Neue Partie';

  @override
  String get newGameEnterMoves => 'Züge eingeben';

  @override
  String get newGameEnterMovesHint =>
      'Spiele die Partie Zug für Zug auf dem Brett nach.';

  @override
  String get newGameImportPgn => 'PGN importieren';

  @override
  String get newGameImportPgnHint =>
      'Füge den Text ein oder öffne eine PGN-Datei.';

  @override
  String get entryTitle => 'Züge eingeben';

  @override
  String get importTitle => 'PGN importieren';

  @override
  String get reviewTitle => 'Analyse';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsAccount => 'Konto';

  @override
  String get settingsLegal => 'Datenschutz und Bedingungen';

  @override
  String get settingsAbout => 'Über die App und Lizenzen';

  @override
  String settingsVersion(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get accountTitle => 'Konto';

  @override
  String get legalTitle => 'Datenschutz und Bedingungen';

  @override
  String get aboutTitle => 'Über die App und Lizenzen';

  @override
  String get consentAiTitle => 'KI-Coach';

  @override
  String get signInTitle => 'Anmelden';

  @override
  String get entryFlipBoard => 'Brett drehen';

  @override
  String get entryMoreOptions => 'Weitere Optionen';

  @override
  String get entryAutoQueen => 'Immer in Dame umwandeln';

  @override
  String get entryUndo => 'Rückgängig';

  @override
  String get entryRedo => 'Vorwärts';

  @override
  String get entryDone => 'Fertig';

  @override
  String get entryMoveListEmpty => 'Spiele den ersten Zug auf dem Brett.';

  @override
  String get entryMoveListStart => 'Anfang';

  @override
  String entryMoveSemantics(int number, String side, String san) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'white': 'Weiss',
      'other': 'Schwarz',
    });
    return '$number. $_temp0, $san';
  }

  @override
  String entryStatusToMove(int number, String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'white': 'Weiss am Zug',
      'other': 'Schwarz am Zug',
    });
    return 'Zug $number · $_temp0';
  }

  @override
  String entryStatusCheckmate(String winner) {
    String _temp0 = intl.Intl.selectLogic(winner, {
      'white': 'Weiss gewinnt',
      'other': 'Schwarz gewinnt',
    });
    return 'Schachmatt · $_temp0';
  }

  @override
  String get entryStatusStalemate => 'Patt · Remis';

  @override
  String get entryStatusInsufficientMaterial => 'Remis · zu wenig Material';

  @override
  String entryOverwriteTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Die folgenden $count Züge ersetzen?',
      one: 'Den folgenden Zug ersetzen?',
    );
    return '$_temp0';
  }

  @override
  String entryOverwriteMessage(String newSan, String oldSan) {
    return '$newSan ist nicht der Zug, den du hier zuvor eingegeben hast ($oldSan). Alles ab $oldSan wird entfernt.';
  }

  @override
  String get entryOverwriteConfirm => 'Ersetzen';

  @override
  String get entryOverwriteCancel => 'Züge behalten';

  @override
  String get entrySavedAsDraft => 'Als Entwurf gespeichert';

  @override
  String boardSquareEmpty(String square) {
    return '$square, leer';
  }

  @override
  String boardSquarePiece(String square, String piece) {
    String _temp0 = intl.Intl.selectLogic(piece, {
      'whiteKing': 'weisser König',
      'whiteQueen': 'weisse Dame',
      'whiteRook': 'weisser Turm',
      'whiteBishop': 'weisser Läufer',
      'whiteKnight': 'weisser Springer',
      'whitePawn': 'weisser Bauer',
      'blackKing': 'schwarzer König',
      'blackQueen': 'schwarze Dame',
      'blackRook': 'schwarzer Turm',
      'blackBishop': 'schwarzer Läufer',
      'blackKnight': 'schwarzer Springer',
      'other': 'schwarzer Bauer',
    });
    return '$square, $_temp0';
  }

  @override
  String boardPromoteTo(String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'queen': 'Dame',
      'rook': 'Turm',
      'bishop': 'Läufer',
      'other': 'Springer',
    });
    return 'Umwandeln in $_temp0';
  }

  @override
  String get boardCancelPromotion => 'Umwandlung abbrechen';
}
