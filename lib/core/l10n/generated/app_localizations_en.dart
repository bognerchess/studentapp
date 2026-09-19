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
  String get importPasteButton => 'Paste from clipboard';

  @override
  String get importOpenFileButton => 'Open file…';

  @override
  String get importFieldLabel => 'PGN or moves';

  @override
  String get importFieldHint => '1. e4 e5 2. Nf3 Nc6 3. Bb5 …';

  @override
  String get importClear => 'Clear';

  @override
  String get importEmptyHint =>
      'Paste a game from another chess app, open a PGN file, or type the moves. Tags such as [White \"…\"] are optional.';

  @override
  String get importChecking => 'Checking the moves…';

  @override
  String get importClipboardEmpty => 'There is no text on the clipboard.';

  @override
  String get importFileUnreadable => 'This file could not be read.';

  @override
  String get importErrorTitleGame => 'This game can\'t be imported';

  @override
  String get importErrorTitleText => 'This text can\'t be imported';

  @override
  String get importErrorTooLarge =>
      'The text is too large. At most 2 MB can be imported at once.';

  @override
  String importErrorTooManyGames(int max) {
    return 'There are more than $max games in this text. Please import a smaller file.';
  }

  @override
  String get importErrorNoGames =>
      'No chess game was found in this text. A game looks like this: 1. e4 e5 2. Nf3 Nc6';

  @override
  String get importErrorNoMoves => 'This game has no moves.';

  @override
  String get importErrorCustomStart =>
      'This game starts from a set-up position (FEN). For now, only games that start from the normal starting position can be imported.';

  @override
  String importErrorVariant(String variant) {
    return 'This is a game of $variant. Only standard chess can be imported.';
  }

  @override
  String importErrorIllegalMove(String move) {
    return '$move is not a legal move in this position.';
  }

  @override
  String importErrorAmbiguousMove(String move) {
    return '$move is ambiguous: more than one piece can make this move. Add the file or rank it starts from, as in Nbd7.';
  }

  @override
  String importErrorUnreadable(String token) {
    return '“$token” is not a chess move.';
  }

  @override
  String get importErrorUnreadableHint =>
      'Moves need the English piece letters K, Q, R, B and N.';

  @override
  String get importErrorUnterminatedComment =>
      'A comment that opens with a curly bracket is never closed.';

  @override
  String get importErrorUnterminatedVariation =>
      'A variation that opens with a round bracket is never closed.';

  @override
  String importErrorWhereLine(int line) {
    return 'Line $line';
  }

  @override
  String importErrorWhereLineMove(int line, int number) {
    return 'Line $line, at move $number';
  }

  @override
  String get importErrorFixHint =>
      'Correct the text above. It is checked again as you type.';

  @override
  String importGamesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count games found',
      one: '1 game found',
    );
    return '$_temp0';
  }

  @override
  String get importChooseGame => 'Choose the game you want to import.';

  @override
  String get importGameNotImportable => 'Can\'t be imported';

  @override
  String get importChooseAnother => 'Choose another game';

  @override
  String get importPreviewTitle => 'Ready to import';

  @override
  String importPlayers(String white, String black) {
    return '$white – $black';
  }

  @override
  String get importPlayerWhite => 'White';

  @override
  String get importPlayerBlack => 'Black';

  @override
  String importMoves(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count moves',
      one: '1 move',
    );
    return '$_temp0';
  }

  @override
  String get importResultOpen => 'No result';

  @override
  String get importFinalPosition => 'Final position';

  @override
  String get importWarningVariations =>
      'Variations were removed. Only the main line is imported.';

  @override
  String get importWarningComments =>
      'Comments and annotation symbols were removed.';

  @override
  String get importContinue => 'Continue';
}
