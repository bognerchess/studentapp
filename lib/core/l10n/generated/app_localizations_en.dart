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
  String get entryFlipBoard => 'Flip board';

  @override
  String get entryMoreOptions => 'More options';

  @override
  String get entryAutoQueen => 'Always promote to queen';

  @override
  String get entryUndo => 'Undo';

  @override
  String get entryRedo => 'Forward';

  @override
  String get entryDone => 'Done';

  @override
  String get entryMoveListEmpty => 'Play the first move on the board.';

  @override
  String get entryMoveListStart => 'Start';

  @override
  String entryMoveSemantics(int number, String side, String san) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'white': 'White',
      'other': 'Black',
    });
    return '$number. $_temp0, $san';
  }

  @override
  String entryStatusToMove(int number, String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'white': 'White to move',
      'other': 'Black to move',
    });
    return 'Move $number · $_temp0';
  }

  @override
  String entryStatusCheckmate(String winner) {
    String _temp0 = intl.Intl.selectLogic(winner, {
      'white': 'White wins',
      'other': 'Black wins',
    });
    return 'Checkmate · $_temp0';
  }

  @override
  String get entryStatusStalemate => 'Stalemate · draw';

  @override
  String get entryStatusInsufficientMaterial => 'Draw · insufficient material';

  @override
  String entryOverwriteTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Replace the following $count moves?',
      one: 'Replace the following move?',
    );
    return '$_temp0';
  }

  @override
  String entryOverwriteMessage(String newSan, String oldSan) {
    return '$newSan is not the move you entered here before ($oldSan). Everything from $oldSan on will be removed.';
  }

  @override
  String get entryOverwriteConfirm => 'Replace';

  @override
  String get entryOverwriteCancel => 'Keep moves';

  @override
  String get entrySavedAsDraft => 'Saved as draft';

  @override
  String boardSquareEmpty(String square) {
    return '$square, empty';
  }

  @override
  String boardSquarePiece(String square, String piece) {
    String _temp0 = intl.Intl.selectLogic(piece, {
      'whiteKing': 'white king',
      'whiteQueen': 'white queen',
      'whiteRook': 'white rook',
      'whiteBishop': 'white bishop',
      'whiteKnight': 'white knight',
      'whitePawn': 'white pawn',
      'blackKing': 'black king',
      'blackQueen': 'black queen',
      'blackRook': 'black rook',
      'blackBishop': 'black bishop',
      'blackKnight': 'black knight',
      'other': 'black pawn',
    });
    return '$square, $_temp0';
  }

  @override
  String boardPromoteTo(String role) {
    String _temp0 = intl.Intl.selectLogic(role, {
      'queen': 'queen',
      'rook': 'rook',
      'bishop': 'bishop',
      'other': 'knight',
    });
    return 'Promote to $_temp0';
  }

  @override
  String get boardCancelPromotion => 'Cancel promotion';
}
