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

  @override
  String get aboutDescription =>
      'Bogner Chess helps you learn from your own games. Enter a game on the board or import a PGN, have it analysed on bognerchess.com, and review it with the comments of the AI coach.';

  @override
  String get aboutNotAffiliated =>
      'Bogner Chess is not affiliated with or endorsed by Lichess. It uses free software that the Lichess project publishes.';

  @override
  String get aboutFreeSoftwareNotice =>
      'Copyright © 2026 Bogner Chess. This app is free software: you may redistribute and modify it under the GNU General Public License, version 3 or any later version. It comes with no warranty.';

  @override
  String get aboutSourceForBuild => 'Source code for this build';

  @override
  String get aboutGplLicence => 'GNU General Public License v3';

  @override
  String get aboutGplLicenceHint => 'Full licence text, in English';

  @override
  String get aboutAppStorePermission => 'Additional permission for app stores';

  @override
  String get aboutAppStorePermissionDraft => 'Draft, not in force yet';

  @override
  String get aboutAppStorePermissionDraftBanner =>
      'This text is a draft. It grants nothing until the copyright holder publishes the final wording. Until then only the GNU General Public License applies.';

  @override
  String get aboutThirdPartyNotices => 'Third-party notices';

  @override
  String get aboutThirdPartyNoticesHint =>
      'Chess pieces and source code from other projects';

  @override
  String get aboutOpenSourceLicences => 'Open-source licences';

  @override
  String get aboutOpenSourceLicencesHint =>
      'The packages this app is built with';

  @override
  String get aboutLinkFailed => 'The link could not be opened.';

  @override
  String get aboutDocumentLoadFailed =>
      'This text could not be loaded. It is also part of the source code of this app.';

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

  @override
  String get signInTagline =>
      'Enter or import your games, have them analysed and review them with coach comments.';

  @override
  String get signInPrimary => 'Sign in';

  @override
  String get signInRegister => 'Create account';

  @override
  String get signInApple => 'Continue with Apple';

  @override
  String get signInGoogle => 'Continue with Google';

  @override
  String get signInOr => 'or';

  @override
  String get signInSameAccount => 'The same account works on bognerchess.com.';

  @override
  String get signInBusy => 'Waiting for the sign-in page …';

  @override
  String get signInErrorOfflineTitle => 'No connection';

  @override
  String get signInErrorOfflineMessage =>
      'The sign-in page could not be reached. Check your internet connection and try again.';

  @override
  String get signInErrorTitle => 'Sign-in did not work';

  @override
  String get signInErrorMessage =>
      'Something went wrong on our side. Please try again in a moment.';

  @override
  String get signInVerifyToggle => 'E-mail not confirmed yet?';

  @override
  String get signInVerifyTitle => 'Confirm your e-mail address';

  @override
  String get signInVerifyBody =>
      'We sent you an e-mail with a confirmation link. Open the link (it may open in Safari, that is fine), then come back here and sign in.';

  @override
  String get signInVerifyAction => 'I have confirmed it – sign in';

  @override
  String reviewSideName(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'white': 'White',
      'other': 'Black',
    });
    return '$_temp0';
  }

  @override
  String reviewAccuracySemantics(String side, String value) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'white': 'White',
      'other': 'Black',
    });
    return 'Accuracy of $_temp0: $value percent';
  }

  @override
  String get reviewMenu => 'Board options';

  @override
  String get reviewShowBestArrow => 'Show best move';

  @override
  String get reviewShowPlayedArrow => 'Show played move';

  @override
  String get reviewFlipBoard => 'Flip board';

  @override
  String get reviewGoToStart => 'Go to start';

  @override
  String get reviewPreviousMove => 'Previous move';

  @override
  String get reviewNextMove => 'Next move';

  @override
  String get reviewGoToEnd => 'Go to end';

  @override
  String get reviewPreviousMoment => 'Previous key moment';

  @override
  String get reviewNextMoment => 'Next key moment';

  @override
  String get reviewTabCoach => 'Coach';

  @override
  String get reviewTabMoves => 'Moves';

  @override
  String get reviewTabSummary => 'Summary';

  @override
  String reviewClassification(String classification) {
    String _temp0 = intl.Intl.selectLogic(classification, {
      'book': 'Book move',
      'best': 'Best move',
      'good': 'Good move',
      'inaccuracy': 'Inaccuracy',
      'mistake': 'Mistake',
      'blunder': 'Blunder',
      'strong': 'Strong move',
      'other': 'Move',
    });
    return '$_temp0';
  }

  @override
  String reviewTheme(String theme) {
    String _temp0 = intl.Intl.selectLogic(theme, {
      'opening': 'Opening',
      'development': 'Development',
      'centralBreak': 'Central break',
      'kingSafety': 'King safety',
      'tactics': 'Tactics',
      'hangingPiece': 'Hanging piece',
      'calculation': 'Calculation',
      'pieceActivity': 'Piece activity',
      'pawnStructure': 'Pawn structure',
      'endgame': 'Endgame',
      'materialConversion': 'Converting an advantage',
      'other': 'Chess',
    });
    return '$_temp0';
  }

  @override
  String get reviewEvalEqual => 'Equal position';

  @override
  String reviewEvalSlight(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'white': 'White is slightly better',
      'other': 'Black is slightly better',
    });
    return '$_temp0';
  }

  @override
  String reviewEvalClear(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'white': 'White is clearly better',
      'other': 'Black is clearly better',
    });
    return '$_temp0';
  }

  @override
  String reviewEvalWinning(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'white': 'White is winning',
      'other': 'Black is winning',
    });
    return '$_temp0';
  }

  @override
  String reviewEvalMate(int count, String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'white': 'White',
      'other': 'Black',
    });
    return 'Mate in $count for $_temp0';
  }

  @override
  String reviewEvalCheckmate(String side) {
    String _temp0 = intl.Intl.selectLogic(side, {
      'white': 'Checkmate. White wins',
      'black': 'Checkmate. Black wins',
      'other': 'Checkmate',
    });
    return '$_temp0';
  }

  @override
  String reviewMomentCounter(int index, int total) {
    return 'Key moment $index of $total';
  }

  @override
  String get reviewCoachAiNote => 'AI-generated. May contain mistakes.';

  @override
  String get reviewThumbUp => 'Helpful';

  @override
  String get reviewThumbDown => 'Not helpful';

  @override
  String get reviewFeedbackFailed => 'Your rating could not be saved.';

  @override
  String reviewShowLine(String label) {
    return 'Show line: $label';
  }

  @override
  String reviewFactBetterWas(String san) {
    return 'Better was $san.';
  }

  @override
  String get reviewStartPositionTitle => 'The moments that mattered';

  @override
  String get reviewStartPositionHint =>
      'The coach picked the moments that decided this game. Swipe through them, or step through every move.';

  @override
  String get reviewFirstMoment => 'First key moment';

  @override
  String get reviewOpenSummary => 'See your lessons';

  @override
  String reviewLineKind(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'bestLine': 'Best continuation',
      'refutation': 'Why the move fails',
      'alternative': 'Another good option',
      'other': 'Line',
    });
    return '$_temp0';
  }

  @override
  String get reviewLineBack => 'Back to game';

  @override
  String get reviewLinePrevious => 'Previous move of the line';

  @override
  String get reviewLineNext => 'Next move of the line';

  @override
  String get reviewMoveHasComment => 'with coach comment';

  @override
  String get reviewLessonsTitle => 'What to take away';

  @override
  String reviewLessonEvidence(String label) {
    return 'Move $label';
  }

  @override
  String get reviewLessonsEmpty => 'There are no lessons for this game.';

  @override
  String get reviewQualityTitle => 'Move quality';

  @override
  String get reviewAccuracy => 'Accuracy';

  @override
  String get reviewGraphLabel => 'Evaluation graph';

  @override
  String get reviewUpdateBanner => 'Update the app to see this analysis.';

  @override
  String get reviewInvalidMessage => 'This analysis could not be read.';

  @override
  String get reviewStartPosition => 'Start position';

  @override
  String get reviewLoading => 'Loading analysis';

  @override
  String get librarySearchHint => 'Search player or event';

  @override
  String get librarySearchClear => 'Clear search';

  @override
  String get libraryFilterDates => 'Date';

  @override
  String libraryFilterDatesRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get libraryFilterDatesClear => 'Clear date filter';

  @override
  String get libraryDatePickerHelp => 'Games played between';

  @override
  String get libraryNoMatchesTitle => 'No games found';

  @override
  String get libraryNoMatchesMessage =>
      'Try another name or a wider date range.';

  @override
  String get libraryClearFilters => 'Clear filters';

  @override
  String get libraryOfflineBanner =>
      'You\'re offline. These are the games saved on this device.';

  @override
  String get libraryOfflineEmpty =>
      'You\'re offline, and no games are saved on this device yet.';

  @override
  String get libraryRefreshFailedBanner => 'The list could not be updated.';

  @override
  String libraryPlayersVs(String white, String black) {
    return '$white – $black';
  }

  @override
  String get libraryWhite => 'White';

  @override
  String get libraryBlack => 'Black';

  @override
  String get libraryDateUnknown => 'No date';

  @override
  String get libraryStatusDraft => 'Draft';

  @override
  String get libraryStatusWaiting => 'Waiting to upload';

  @override
  String get libraryStatusUploadFailed => 'Upload failed';

  @override
  String get libraryStatusAnalysing => 'Analysing…';

  @override
  String get libraryStatusReady => 'Analysis ready';

  @override
  String get libraryStatusFailed => 'Analysis failed';

  @override
  String get libraryStatusNotAnalysed => 'Not analysed';

  @override
  String get libraryDeleteTitle => 'Delete this game?';

  @override
  String get libraryDeleteMessage =>
      'The game and its analysis are removed from your account, on the website too. This cannot be undone.';

  @override
  String get libraryDeleteDraftTitle => 'Delete this draft?';

  @override
  String get libraryDeleteDraftMessage => 'The moves you entered will be lost.';

  @override
  String get libraryDeleteConfirm => 'Delete';

  @override
  String get libraryDeleteCancel => 'Cancel';

  @override
  String get libraryDeleted => 'Game deleted';

  @override
  String get libraryDraftDeleted => 'Draft deleted';

  @override
  String get libraryDeleteFailed => 'That could not be deleted. Try again.';

  @override
  String get libraryDraftWaitingInfo =>
      'This game is sent as soon as you\'re online.';

  @override
  String get libraryDraftFailedInfo => 'This game could not be uploaded.';

  @override
  String get libraryLoadingMore => 'Loading more games';

  @override
  String get gameDetailNotFoundTitle => 'Game not found';

  @override
  String get gameDetailNotFoundMessage =>
      'It may have been deleted on another device.';

  @override
  String get gameDetailOutcomeWin => 'You won';

  @override
  String get gameDetailOutcomeLoss => 'You lost';

  @override
  String get gameDetailOutcomeDraw => 'Draw';

  @override
  String gameDetailMoves(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count moves',
      one: '1 move',
    );
    return '$_temp0';
  }

  @override
  String get gameDetailFinalPosition => 'Final position';

  @override
  String get gameDetailDelete => 'Delete game';

  @override
  String get gameDetailAnalyse => 'Analyse this game';

  @override
  String get gameDetailAnalyseHint =>
      'The coach goes through your game and explains the key moments. It takes a few minutes.';

  @override
  String get gameDetailOpenAnalysis => 'Open analysis';

  @override
  String get gameDetailReadyMessage => 'Your analysis is ready.';

  @override
  String get gameDetailQueuedTitle => 'Waiting in the queue';

  @override
  String get gameDetailQueuedNext => 'Your game is next.';

  @override
  String gameDetailQueuedPosition(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count games are ahead of yours.',
      one: '1 game is ahead of yours.',
    );
    return '$_temp0';
  }

  @override
  String get gameDetailRunningTitle => 'Analysing your game';

  @override
  String get gameDetailStageEngine => 'The engine is checking every move.';

  @override
  String get gameDetailStageCoach => 'The coach is writing the comments.';

  @override
  String get gameDetailStageOther => 'This takes a few minutes.';

  @override
  String get gameDetailLeaveHint =>
      'You can leave the app. We\'ll notify you when the analysis is ready.';

  @override
  String get gameDetailFailedTitle => 'The analysis failed';

  @override
  String get gameDetailFailedMessage =>
      'Something went wrong on our side. This attempt does not count towards your limit.';

  @override
  String get gameDetailSheetClose => 'Close';

  @override
  String get gameDetailLimitTitleDay => 'Daily limit reached';

  @override
  String get gameDetailLimitTitleMonth => 'Monthly limit reached';

  @override
  String get gameDetailLimitTitleOther => 'Analysis limit reached';

  @override
  String gameDetailLimitBodyDay(int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other:
          'You can have $limit games analysed per day, and you\'ve used them all today.',
      one: 'You can have 1 game analysed per day, and you\'ve used it today.',
    );
    return '$_temp0';
  }

  @override
  String gameDetailLimitBodyMonth(int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other:
          'You can have $limit games analysed per month, and you\'ve used them all this month.',
      one: 'You can have 1 game analysed per month, and you\'ve used it this month.',
    );
    return '$_temp0';
  }

  @override
  String gameDetailLimitBodyOther(int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other: 'You have used all $limit analyses.',
      one: 'You have used your 1 analysis.',
    );
    return '$_temp0';
  }

  @override
  String gameDetailLimitReset(String when) {
    return 'You can request analyses again from $when.';
  }

  @override
  String get gameDetailLimitSaved =>
      'Your game is saved. You can have it analysed later.';

  @override
  String get gameDetailLimitFree =>
      'Entering, importing and reviewing games is never limited.';

  @override
  String get gameDetailQueueFullTitle => 'Too many analyses at once';

  @override
  String gameDetailQueueFullBody(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other:
          'Only $max of your games can be analysed at a time. Wait until one is finished, then try again.',
      one: 'Only 1 of your games can be analysed at a time. Wait until it is finished, then try again.',
    );
    return '$_temp0';
  }

  @override
  String gameDetailRateLimited(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Too many requests. Try again in $seconds seconds.',
      one: 'Too many requests. Try again in 1 second.',
    );
    return '$_temp0';
  }

  @override
  String get gameDetailEmailTitle => 'Confirm your e-mail address';

  @override
  String get gameDetailEmailBody =>
      'To have games analysed, open the link in the e-mail we sent you when you registered. Then come back and tap the button below.';

  @override
  String get gameDetailEmailAction => 'I\'ve confirmed it';

  @override
  String get gameDetailEmailStill => 'Your address is not confirmed yet.';

  @override
  String get gameDetailConsentNeeded =>
      'The analysis needs your consent to AI processing.';

  @override
  String get gameDetailRequestFailed =>
      'The analysis could not be requested. Try again.';

  @override
  String get gameDetailRequestOffline =>
      'You\'re offline. Connect to the internet and try again.';

  @override
  String get usageTitle => 'Analyses';

  @override
  String usageDailyLeft(int remaining, int limit, String time) {
    return '$remaining of $limit analyses left today · resets at $time';
  }

  @override
  String usageDailyNone(String time) {
    return 'No analyses left today · resets at $time';
  }

  @override
  String usageMonthlyLeft(int remaining, int limit, String date) {
    return '$remaining of $limit analyses left this month · resets on $date';
  }

  @override
  String usageMonthlyNone(String date) {
    return 'No analyses left this month · resets on $date';
  }

  @override
  String get usageUnlimited => 'Unlimited analyses';

  @override
  String get usageUnavailable => 'The numbers are not available right now.';

  @override
  String get analysisNoticeReady => 'Your analysis is ready.';

  @override
  String analysisNoticeReadyOpponent(String name) {
    return 'Your game against $name has been analysed.';
  }

  @override
  String get analysisNoticeOpen => 'Open';

  @override
  String get analysisNoticeFailed =>
      'An analysis failed. It doesn\'t count towards your limit.';

  @override
  String get analysisNoticeView => 'View';
}
