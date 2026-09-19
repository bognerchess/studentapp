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
  String get metadataTitle => 'Angaben zur Partie';

  @override
  String get metadataSave => 'Speichern';

  @override
  String get metadataSaveNeedsColor => 'Wähle die Farbe, die du hattest.';

  @override
  String get metadataSaveNeedsFix => 'Prüfe die markierten Felder.';

  @override
  String get metadataColorLabel => 'Ich hatte';

  @override
  String get metadataColorWhite => 'Weiß';

  @override
  String get metadataColorBlack => 'Schwarz';

  @override
  String get metadataResultLabel => 'Ergebnis';

  @override
  String get metadataResultUnknown => 'Unbekannt';

  @override
  String get metadataResultWhiteWinsA11y => 'Weiß gewann, 1-0';

  @override
  String get metadataResultBlackWinsA11y => 'Schwarz gewann, 0-1';

  @override
  String get metadataResultDrawA11y => 'Remis, je ein halber Punkt';

  @override
  String get metadataOutcomeWin => 'Du hast gewonnen.';

  @override
  String get metadataOutcomeLoss => 'Du hast verloren.';

  @override
  String get metadataOutcomeDraw => 'Remis.';

  @override
  String get metadataPlayersLabel => 'Spieler';

  @override
  String get metadataOpponentName => 'Gegner';

  @override
  String get metadataPlayerName => 'Dein Name';

  @override
  String get metadataRatingLabel => 'Elo';

  @override
  String get metadataPlayerRatingA11y => 'Deine Wertungszahl';

  @override
  String get metadataOpponentRatingA11y => 'Wertungszahl des Gegners';

  @override
  String get metadataWhiteRatingA11y => 'Wertungszahl von Weiß';

  @override
  String get metadataBlackRatingA11y => 'Wertungszahl von Schwarz';

  @override
  String get metadataRatingHint =>
      'Mit deiner Wertungszahl erklärt der Coach auf deinem Niveau. Eine Online-Wertung oder eine grobe Schätzung genügt.';

  @override
  String get metadataDateLabel => 'Datum';

  @override
  String get metadataDateUnknown => 'Unbekannt';

  @override
  String get metadataDateClear => 'Datum löschen';

  @override
  String get metadataDateFuture => 'Dieses Datum liegt in der Zukunft.';

  @override
  String get metadataEventLabel => 'Turnier oder Anlass';

  @override
  String get metadataEventHint => 'z. B. Vereinsmeisterschaft';

  @override
  String get metadataTimeControlLabel => 'Bedenkzeit';

  @override
  String get metadataTimeControlClassical => 'Klassisch';

  @override
  String get metadataTimeControlRapid => 'Schnellschach';

  @override
  String get metadataTimeControlBlitz => 'Blitz';

  @override
  String get metadataTimeControlBullet => 'Bullet';

  @override
  String get metadataTimeControlOther => 'Andere';

  @override
  String get metadataTimeControlDetail => 'Minuten + Inkrement';

  @override
  String get metadataTimeControlDetailHint => 'z. B. 90+30';

  @override
  String metadataRatingError(int min, int max) {
    return '$min–$max';
  }

  @override
  String get signInTagline =>
      'Gib deine Partien ein oder importiere sie, lass sie analysieren und geh sie mit Trainerkommentaren durch.';

  @override
  String get signInPrimary => 'Anmelden';

  @override
  String get signInRegister => 'Konto erstellen';

  @override
  String get signInApple => 'Mit Apple fortfahren';

  @override
  String get signInGoogle => 'Mit Google fortfahren';

  @override
  String get signInOr => 'oder';

  @override
  String get signInSameAccount =>
      'Dasselbe Konto gilt auch auf bognerchess.com.';

  @override
  String get signInBusy => 'Warte auf die Anmeldeseite …';

  @override
  String get signInErrorOfflineTitle => 'Keine Verbindung';

  @override
  String get signInErrorOfflineMessage =>
      'Die Anmeldeseite ist nicht erreichbar. Prüfe deine Internetverbindung und versuch es noch einmal.';

  @override
  String get signInErrorTitle => 'Anmeldung hat nicht geklappt';

  @override
  String get signInErrorMessage =>
      'Da ist bei uns etwas schiefgegangen. Bitte versuch es gleich noch einmal.';

  @override
  String get signInVerifyToggle => 'E-Mail noch nicht bestätigt?';

  @override
  String get signInVerifyTitle => 'Bestätige deine E-Mail-Adresse';

  @override
  String get signInVerifyBody =>
      'Wir haben dir eine E-Mail mit einem Bestätigungslink geschickt. Öffne den Link (er darf sich in Safari öffnen), komm dann hierher zurück und melde dich an.';

  @override
  String get signInVerifyAction => 'Ich habe bestätigt – anmelden';
}
