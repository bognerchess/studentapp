// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Bogner Chess';

  @override
  String get tabGames => 'Games';

  @override
  String get tabNewGame => 'New game';

  @override
  String get tabSettings => 'Settings';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonErrorTitle => 'Something went wrong';

  @override
  String get commonErrorMessage =>
      'Please check your connection and try again.';

  @override
  String get commonPlaceholderMessage => 'This screen is not built yet.';

  @override
  String get notFoundTitle => 'Page not found';

  @override
  String get notFoundMessage => 'This link does not lead anywhere in the app.';

  @override
  String get notFoundAction => 'Go to my games';

  @override
  String get libraryTitle => 'Games';

  @override
  String get libraryEmptyTitle => 'No games yet';

  @override
  String get libraryEmptyMessage =>
      'Enter a game or import a PGN to have it analysed.';

  @override
  String get libraryEmptyAction => 'New game';

  @override
  String get libraryGameTitle => 'Game';

  @override
  String get newGameTitle => 'New game';

  @override
  String get newGameEnterMoves => 'Enter moves';

  @override
  String get newGameEnterMovesHint =>
      'Play through the game on the board, move by move.';

  @override
  String get newGameImportPgn => 'Import PGN';

  @override
  String get newGameImportPgnHint => 'Paste the text or open a PGN file.';

  @override
  String get entryTitle => 'Enter moves';

  @override
  String get importTitle => 'Import PGN';

  @override
  String get reviewTitle => 'Review';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsLegal => 'Privacy and terms';

  @override
  String get settingsAbout => 'About and licences';

  @override
  String settingsVersion(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get accountTitle => 'Account';

  @override
  String get legalTitle => 'Privacy and terms';

  @override
  String get aboutTitle => 'About and licences';

  @override
  String get consentAiTitle => 'AI coach';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get metadataTitle => 'Game details';

  @override
  String get metadataSave => 'Save';

  @override
  String get metadataSaveNeedsColor => 'Choose the colour you played.';

  @override
  String get metadataSaveNeedsFix => 'Check the marked fields.';

  @override
  String get metadataColorLabel => 'I played';

  @override
  String get metadataColorWhite => 'White';

  @override
  String get metadataColorBlack => 'Black';

  @override
  String get metadataResultLabel => 'Result';

  @override
  String get metadataResultUnknown => 'Unknown';

  @override
  String get metadataResultWhiteWinsA11y => 'White won, 1-0';

  @override
  String get metadataResultBlackWinsA11y => 'Black won, 0-1';

  @override
  String get metadataResultDrawA11y => 'Draw, one half each';

  @override
  String get metadataOutcomeWin => 'You won.';

  @override
  String get metadataOutcomeLoss => 'You lost.';

  @override
  String get metadataOutcomeDraw => 'A draw.';

  @override
  String get metadataPlayersLabel => 'Players';

  @override
  String get metadataOpponentName => 'Opponent';

  @override
  String get metadataPlayerName => 'Your name';

  @override
  String get metadataRatingLabel => 'Rating';

  @override
  String get metadataPlayerRatingA11y => 'Your rating';

  @override
  String get metadataOpponentRatingA11y => 'Opponent\'s rating';

  @override
  String get metadataWhiteRatingA11y => 'White\'s rating';

  @override
  String get metadataBlackRatingA11y => 'Black\'s rating';

  @override
  String get metadataRatingHint =>
      'With your rating the coach explains at your level. An online rating or a rough guess is fine.';

  @override
  String get metadataDateLabel => 'Date';

  @override
  String get metadataDateUnknown => 'Unknown';

  @override
  String get metadataDateClear => 'Clear date';

  @override
  String get metadataDateFuture => 'This date is in the future.';

  @override
  String get metadataEventLabel => 'Event';

  @override
  String get metadataEventHint => 'e.g. Club championship';

  @override
  String get metadataTimeControlLabel => 'Time control';

  @override
  String get metadataTimeControlClassical => 'Classical';

  @override
  String get metadataTimeControlRapid => 'Rapid';

  @override
  String get metadataTimeControlBlitz => 'Blitz';

  @override
  String get metadataTimeControlBullet => 'Bullet';

  @override
  String get metadataTimeControlOther => 'Other';

  @override
  String get metadataTimeControlDetail => 'Minutes + increment';

  @override
  String get metadataTimeControlDetailHint => 'e.g. 90+30';

  @override
  String metadataRatingError(int min, int max) {
    return '$min–$max';
  }
}
