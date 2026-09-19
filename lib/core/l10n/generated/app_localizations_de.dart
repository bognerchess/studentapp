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
  String get aboutDescription =>
      'Bogner Chess hilft dir, aus deinen eigenen Partien zu lernen. Gib eine Partie auf dem Brett ein oder importiere eine PGN-Datei, lass sie auf bognerchess.com analysieren und geh sie mit den Kommentaren des KI-Coachs durch.';

  @override
  String get aboutNotAffiliated =>
      'Bogner Chess steht in keiner Verbindung zu Lichess und wird von Lichess nicht unterstützt. Die App verwendet freie Software, die das Lichess-Projekt veröffentlicht.';

  @override
  String get aboutFreeSoftwareNotice =>
      'Copyright © 2026 Bogner Chess. Diese App ist freie Software: Du darfst sie unter der GNU General Public License, Version 3 oder jeder späteren Version, weitergeben und verändern. Es besteht keinerlei Gewährleistung.';

  @override
  String get aboutSourceForBuild => 'Quellcode dieses Builds';

  @override
  String get aboutGplLicence => 'GNU General Public License v3';

  @override
  String get aboutGplLicenceHint => 'Vollständiger Lizenztext, auf Englisch';

  @override
  String get aboutAppStorePermission => 'Zusätzliche Erlaubnis für App-Stores';

  @override
  String get aboutAppStorePermissionDraft => 'Entwurf, noch nicht in Kraft';

  @override
  String get aboutAppStorePermissionDraftBanner =>
      'Dieser Text ist ein Entwurf. Er räumt keine Rechte ein, bis der Rechteinhaber die endgültige Fassung veröffentlicht. Bis dahin gilt allein die GNU General Public License.';

  @override
  String get aboutThirdPartyNotices => 'Hinweise zu Drittkomponenten';

  @override
  String get aboutThirdPartyNoticesHint =>
      'Schachfiguren und Quellcode aus anderen Projekten';

  @override
  String get aboutOpenSourceLicences => 'Open-Source-Lizenzen';

  @override
  String get aboutOpenSourceLicencesHint =>
      'Die Pakete, mit denen diese App gebaut ist';

  @override
  String get aboutLinkFailed => 'Der Link konnte nicht geöffnet werden.';

  @override
  String get aboutDocumentLoadFailed =>
      'Dieser Text konnte nicht geladen werden. Er ist auch Teil des Quellcodes dieser App.';

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
