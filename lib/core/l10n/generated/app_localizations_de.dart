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
}
