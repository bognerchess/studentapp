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
  String get importPasteButton => 'Aus Zwischenablage einfügen';

  @override
  String get importOpenFileButton => 'Datei öffnen …';

  @override
  String get importFieldLabel => 'PGN oder Züge';

  @override
  String get importFieldHint => '1. e4 e5 2. Sf3 Sc6 3. Lb5 …';

  @override
  String get importClear => 'Leeren';

  @override
  String get importEmptyHint =>
      'Füge eine Partie aus einer anderen Schach-App ein, öffne eine PGN-Datei oder tippe die Züge. Angaben wie [White \"…\"] sind freiwillig.';

  @override
  String get importChecking => 'Züge werden geprüft …';

  @override
  String get importClipboardEmpty => 'In der Zwischenablage ist kein Text.';

  @override
  String get importFileUnreadable => 'Diese Datei konnte nicht gelesen werden.';

  @override
  String get importErrorTitleGame =>
      'Diese Partie kann nicht importiert werden';

  @override
  String get importErrorTitleText => 'Dieser Text kann nicht importiert werden';

  @override
  String get importErrorTooLarge =>
      'Der Text ist zu gross. Es können höchstens 2 MB auf einmal importiert werden.';

  @override
  String importErrorTooManyGames(int max) {
    return 'In diesem Text sind mehr als $max Partien. Bitte importiere eine kleinere Datei.';
  }

  @override
  String get importErrorNoGames =>
      'In diesem Text wurde keine Schachpartie gefunden. Eine Partie sieht so aus: 1. e4 e5 2. Nf3 Nc6';

  @override
  String get importErrorNoMoves => 'Diese Partie enthält keine Züge.';

  @override
  String get importErrorCustomStart =>
      'Diese Partie beginnt in einer aufgebauten Stellung (FEN). Im Moment können nur Partien importiert werden, die in der Grundstellung beginnen.';

  @override
  String importErrorVariant(String variant) {
    return 'Das ist eine Partie in der Variante $variant. Es kann nur normales Schach importiert werden.';
  }

  @override
  String importErrorIllegalMove(String move) {
    return '$move ist in dieser Stellung kein erlaubter Zug.';
  }

  @override
  String importErrorAmbiguousMove(String move) {
    return '$move ist mehrdeutig: Mehr als eine Figur kann diesen Zug machen. Ergänze die Linie oder Reihe, von der sie kommt, wie in Nbd7.';
  }

  @override
  String importErrorUnreadable(String token) {
    return '«$token» ist kein Schachzug.';
  }

  @override
  String get importErrorUnreadableHint =>
      'Züge brauchen die englischen Figurenbuchstaben K, Q, R, B und N.';

  @override
  String get importErrorUnterminatedComment =>
      'Ein Kommentar in geschweiften Klammern wird nie geschlossen.';

  @override
  String get importErrorUnterminatedVariation =>
      'Eine Variante in runden Klammern wird nie geschlossen.';

  @override
  String importErrorWhereLine(int line) {
    return 'Zeile $line';
  }

  @override
  String importErrorWhereLineMove(int line, int number) {
    return 'Zeile $line, bei Zug $number';
  }

  @override
  String get importErrorFixHint =>
      'Korrigiere den Text oben. Er wird beim Tippen neu geprüft.';

  @override
  String importGamesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Partien gefunden',
      one: '1 Partie gefunden',
    );
    return '$_temp0';
  }

  @override
  String get importChooseGame =>
      'Wähle die Partie, die du importieren möchtest.';

  @override
  String get importGameNotImportable => 'Kann nicht importiert werden';

  @override
  String get importChooseAnother => 'Andere Partie wählen';

  @override
  String get importPreviewTitle => 'Bereit zum Import';

  @override
  String importPlayers(String white, String black) {
    return '$white – $black';
  }

  @override
  String get importPlayerWhite => 'Weiss';

  @override
  String get importPlayerBlack => 'Schwarz';

  @override
  String importMoves(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Züge',
      one: '1 Zug',
    );
    return '$_temp0';
  }

  @override
  String get importResultOpen => 'Ohne Ergebnis';

  @override
  String get importFinalPosition => 'Schlussstellung';

  @override
  String get importWarningVariations =>
      'Varianten wurden entfernt. Nur die Hauptvariante wird importiert.';

  @override
  String get importWarningComments =>
      'Kommentare und Bewertungszeichen wurden entfernt.';

  @override
  String get importContinue => 'Weiter';
}
