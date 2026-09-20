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
  String get legalPrivacyPolicy => 'Privacy policy';

  @override
  String get legalTerms => 'Terms of use';

  @override
  String get legalDraftLabel => 'DRAFT';

  @override
  String get legalDraftHint =>
      'This text is a placeholder and has not been legally reviewed.';

  @override
  String get legalNotPublishedTitle => 'Not available yet';

  @override
  String get legalNotPublishedMessage =>
      'This text has not been published yet. You can find it on bognerchess.com.';

  @override
  String get legalOfflineTitle => 'You are offline';

  @override
  String get legalOfflineMessage =>
      'The text is loaded from the server, so that it is always the current version. Connect to the internet and try again.';

  @override
  String get legalLoading => 'Loading text';

  @override
  String legalVersionLine(int version, String date) {
    return 'Version $version · $date';
  }

  @override
  String get legalEnglishOnly =>
      'This text is only available in English at the moment.';

  @override
  String get consentAiClose => 'Close';

  @override
  String get consentAiLoading => 'Loading text';

  @override
  String consentAiProvider(String provider) {
    return 'Analysis comments are generated by $provider.';
  }

  @override
  String get consentAiProviderUnnamed =>
      'Analysis comments are generated by an AI language model of an external provider.';

  @override
  String get consentAiSentTitle => 'What is sent to the AI provider';

  @override
  String get consentAiSentMoves => 'The moves of the game';

  @override
  String get consentAiSentPositions => 'The positions on the board';

  @override
  String get consentAiSentEvaluations =>
      'The chess engine\'s evaluations and best lines';

  @override
  String get consentAiSentColour => 'Which colour you played';

  @override
  String get consentAiSentRatingBand =>
      'A rough rating range, so that the explanations fit your level';

  @override
  String get consentAiNotSentTitle => 'What is never sent';

  @override
  String get consentAiNotSentName => 'Your name and the name of your opponent';

  @override
  String get consentAiNotSentEmail => 'Your e-mail address';

  @override
  String get consentAiNotSentAccount =>
      'Your account or anything that identifies it';

  @override
  String get consentAiNotSentEvent => 'Event, place and date of the game';

  @override
  String get consentAiAgree => 'Agree and continue';

  @override
  String get consentAiNotNow => 'Not now';

  @override
  String get consentAiSaveFailed =>
      'Your consent could not be saved. Check your connection and try again.';

  @override
  String get consentAiAlreadyAgreed => 'You have agreed to this version.';

  @override
  String get consentAiWithdraw => 'Withdraw consent';

  @override
  String get consentAiOfflineTitle => 'You are offline';

  @override
  String get consentAiOfflineMessage =>
      'Consent can only be given online, because the server has to know about it before a game is analysed. Your game is kept on this device.';

  @override
  String get consentAiErrorMessage =>
      'The consent text could not be loaded. Please try again.';

  @override
  String get consentAiUnavailableTitle => 'Not available yet';

  @override
  String get consentAiUnavailableMessage =>
      'The consent text for the AI analysis is not available yet. Your games are saved; please try again later.';

  @override
  String get consentAnalyticsTitle => 'Help improve the app?';

  @override
  String get consentAnalyticsBody =>
      'May the app send usage statistics and crash reports? They tell us which screens are used and where the app fails. They never contain your games, your moves or your name.';

  @override
  String get consentAnalyticsFootnote =>
      'This is switched off unless you allow it, and you can change it in the settings at any time. It also covers crash reports.';

  @override
  String get consentAnalyticsAllow => 'Allow';

  @override
  String get consentAnalyticsDecline => 'No thanks';

  @override
  String get settingsAccountSignedIn => 'Signed in';

  @override
  String get settingsSectionAnalyses => 'Analyses';

  @override
  String get settingsSectionBoard => 'Board';

  @override
  String get settingsSectionEntry => 'Entering moves';

  @override
  String get settingsSectionPrivacy => 'Your data';

  @override
  String get settingsAutoQueenHint =>
      'Skips the choice of piece when a pawn reaches the last rank.';

  @override
  String get settingsAnalytics => 'Usage statistics and crash reports';

  @override
  String get settingsAnalyticsHint =>
      'Helps us improve the app. Never contains your games or your name.';

  @override
  String get settingsAiConsent => 'AI analysis consent';

  @override
  String settingsAiConsentAgreed(int version) {
    return 'Agreed (version $version)';
  }

  @override
  String get settingsAiConsentNewVersion =>
      'The text has changed. Please read it again.';

  @override
  String get settingsAiConsentNotYet =>
      'Not agreed yet. You are asked before your first analysis.';

  @override
  String get settingsAiConsentUnknown => 'The status could not be loaded.';

  @override
  String get settingsAiConsentLoading => 'Loading …';

  @override
  String get settingsAiConsentReview => 'Review';

  @override
  String get settingsUsageToday => 'Today';

  @override
  String get settingsUsageMonth => 'This month';

  @override
  String settingsUsageOf(int used, int limit) {
    return '$used of $limit';
  }

  @override
  String settingsUsageCount(int used) {
    String _temp0 = intl.Intl.pluralLogic(
      used,
      locale: localeName,
      other: '$used analyses',
      one: '1 analysis',
    );
    return '$_temp0';
  }

  @override
  String settingsUsageResetsAt(String time) {
    return 'Resets at $time.';
  }

  @override
  String settingsUsageResetsOn(String date) {
    return 'Resets on $date.';
  }

  @override
  String get settingsUsageLimitReached => 'Limit reached.';

  @override
  String get settingsUsageUnlimited => 'Unlimited';

  @override
  String settingsUsageQueued(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count analyses in progress',
      one: '1 analysis in progress',
    );
    return '$_temp0 (at most $max at a time)';
  }

  @override
  String get settingsUsageError => 'The numbers could not be loaded.';

  @override
  String get settingsUsageLoading => 'Loading analysis quota';

  @override
  String get settingsBoardPieces => 'Pieces';

  @override
  String get settingsBoardColors => 'Board colours';

  @override
  String get settingsBoardColorsBrown => 'Brown';

  @override
  String get settingsBoardColorsBlue => 'Blue';

  @override
  String get settingsBoardColorsGreen => 'Green';

  @override
  String get settingsBoardColorsOlive => 'Olive';

  @override
  String settingsBoardPreviewLabel(String pieces, String colours) {
    return 'Board preview: $pieces pieces, $colours';
  }

  @override
  String get updateRequiredTitle => 'Please update the app';

  @override
  String get updateRequiredMessage =>
      'This version of Bogner Chess is no longer supported. Install the current version to continue. Your games and drafts are kept.';

  @override
  String get updateRequiredAction => 'Open the App Store';

  @override
  String get accountSameAccount =>
      'This is your bognerchess.com account. The app and the website share it: the same sign-in, the same games.';

  @override
  String get accountEmailNotVerified =>
      'Your e-mail address is not confirmed yet. Open the link in the e-mail we sent you.';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountSignOutHint =>
      'Games you have not sent yet stay on this device.';

  @override
  String get accountSignOutConfirmTitle => 'Sign out?';

  @override
  String get accountSignOutConfirmMessage =>
      'Your games stay in your account. Drafts you have not sent yet stay on this device and are there when you sign in again.';

  @override
  String get accountCancel => 'Cancel';

  @override
  String get accountBack => 'Back';

  @override
  String get accountDeleteSection => 'Delete account';

  @override
  String get accountDeleteTeaser =>
      'Deletes your bognerchess.com account with all games and analyses, in the app and on the website.';

  @override
  String get accountDelete => 'Delete account …';

  @override
  String get accountDeleteTitle => 'Delete account';

  @override
  String get accountDeleteSameAccountTitle =>
      'This deletes your bognerchess.com account';

  @override
  String get accountDeleteSameAccountBody =>
      'The app has no account of its own. You sign in with your bognerchess.com account, and that account is deleted: you lose access to the website as well, not only to this app.';

  @override
  String get accountDeleteWhatGoesTitle => 'What is deleted';

  @override
  String get accountDeleteGoesGames =>
      'All your games, analyses and coach comments';

  @override
  String get accountDeleteGoesProfile =>
      'Your profile and your sign-in; your personal data is anonymised';

  @override
  String get accountDeleteGoesDevice =>
      'Everything the app has stored on this device, including drafts';

  @override
  String get accountDeleteWhatStaysTitle => 'What we have to keep';

  @override
  String get accountDeleteStaysInvoices =>
      'Paid invoices, for as long as the law requires us to keep them';

  @override
  String get accountDeleteGoodToKnowTitle => 'Before you go on';

  @override
  String get accountDeleteIrreversible =>
      'This cannot be undone. Nobody can restore a deleted account, not even our support.';

  @override
  String get accountDeleteMayBeBlocked =>
      'Accounts with an active membership, open invoices or linked child accounts cannot be deleted here. If that applies to you, we tell you what to do.';

  @override
  String accountDeleteTypeInstruction(String word) {
    return 'To confirm, type $word into the field.';
  }

  @override
  String accountDeleteFieldLabel(String word) {
    return 'Type $word';
  }

  @override
  String get accountDeleteConfirm => 'Delete my account for good';

  @override
  String get accountDeleteRetry => 'Try again';

  @override
  String get accountDeleteInProgress => 'Deleting account';

  @override
  String get accountDeleteFailed =>
      'The account could not be deleted. Nothing was changed. Please try again.';

  @override
  String get accountDeleteFailedOffline =>
      'You are offline. The account can only be deleted with a connection. Nothing was changed.';

  @override
  String get accountDeleteBlockedTitle => 'This account cannot be deleted here';

  @override
  String get accountDeleteBlockedKid =>
      'This is a child account. It belongs to a parent\'s account, and only they can have it deleted. Ask them, or write to us.';

  @override
  String get accountDeleteBlockedDependents =>
      'Child accounts are linked to your account and would lose their access. Write to us and we sort that out with you first.';

  @override
  String get accountDeleteBlockedMembership =>
      'You have an active membership. End it first on bognerchess.com or write to us; after that the account can be deleted.';

  @override
  String get accountDeleteBlockedInvoices =>
      'There are open invoices on your account. Once they are settled, the account can be deleted. Write to us if you have questions.';

  @override
  String get accountDeleteBlockedOther =>
      'Something on your account has to be sorted out before it can be deleted. Write to us and we take care of it.';

  @override
  String get accountDeleteBlockedNothingDeleted => 'Nothing was deleted.';

  @override
  String get accountDeleteContactSupport => 'Write to support';

  @override
  String get accountDeleteSupportSubject => 'Delete my Bogner Chess account';

  @override
  String get accountDeletedTitle => 'Your account has been deleted';

  @override
  String get accountDeletedMessage =>
      'Your games, analyses and personal data are being removed, and everything the app stored on this device is gone. Thank you for playing with us.';

  @override
  String get accountDeletedDone => 'Done';

  @override
  String get pushExplainerTitle => 'Know when your analysis is ready';

  @override
  String get pushExplainerBody =>
      'An analysis takes a few minutes. We\'ll let you know when your analysis is ready, so you don\'t have to wait here. No advertising, no reminders.';

  @override
  String get pushExplainerAllow => 'Notify me';

  @override
  String get pushExplainerNotNow => 'Not now';

  @override
  String get pushSettingsDeniedHint =>
      'Notifications are turned off for Bogner Chess. You can turn them on in the Settings app.';

  @override
  String get pushSettingsOpenSettings => 'Open Settings';

  @override
  String get newGameSaveAndAnalyse => 'Save & analyse';

  @override
  String get newGameSaveOnly => 'Save only';

  @override
  String get newGameSavedUploading => 'Game saved. It is being uploaded.';

  @override
  String get newGameSavedAnalysing =>
      'Game saved. It is being uploaded and analysed.';

  @override
  String get newGameSavedOffline =>
      'Game saved. It will be uploaded as soon as you are online.';

  @override
  String get newGameSavedWithoutConsent =>
      'Game saved without analysis. You can start the analysis from the game later.';

  @override
  String get newGameAlreadySaved => 'This game has already been saved.';

  @override
  String get newGameSaveFailed =>
      'The game could not be saved. Please try again.';

  @override
  String submitQueueUploading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Uploading $count games…',
      one: 'Uploading 1 game…',
    );
    return '$_temp0';
  }

  @override
  String submitQueueWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count games waiting to upload',
      one: '1 game waiting to upload',
    );
    return '$_temp0';
  }

  @override
  String submitQueueWaitingOffline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count games waiting to upload · offline',
      one: '1 game waiting to upload · offline',
    );
    return '$_temp0';
  }

  @override
  String submitQueueWaitingRetry(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count games waiting to upload · will retry automatically',
      one: '1 game waiting to upload · will retry automatically',
    );
    return '$_temp0';
  }

  @override
  String submitQueueFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count games could not be uploaded',
      one: '1 game could not be uploaded',
    );
    return '$_temp0';
  }

  @override
  String get submitQueueRetry => 'Retry';

  @override
  String get submitQueueDetails => 'Details';

  @override
  String get submitQueueSheetTitle => 'Uploads';

  @override
  String get submitQueueSheetEmpty => 'All games are uploaded.';

  @override
  String get submitQueueDraftUntitled => 'Game without names';

  @override
  String submitQueueDraftPlayers(String white, String black) {
    return '$white – $black';
  }

  @override
  String get submitQueueDraftUnknownPlayer => '?';

  @override
  String get submitQueueStateWaiting => 'Waiting to upload';

  @override
  String get submitQueueStateUploading => 'Uploading…';

  @override
  String submitQueueStateRetrying(String reason) {
    return 'Last attempt failed: $reason Will retry automatically.';
  }

  @override
  String submitQueueStateFailed(String reason) {
    return 'Not uploaded: $reason';
  }

  @override
  String get submitQueueDelete => 'Delete';

  @override
  String get submitQueueDeleteTitle => 'Delete this game?';

  @override
  String get submitQueueDeleteMessage =>
      'It only exists on this device. Deleting it cannot be undone.';

  @override
  String get submitQueueCancel => 'Cancel';

  @override
  String get submitQueueErrorNetwork => 'No connection to the server.';

  @override
  String get submitQueueErrorServer => 'The server had a problem.';

  @override
  String get submitQueueErrorRateLimited =>
      'Too many requests in a short time.';

  @override
  String get submitQueueErrorUnauthenticated =>
      'Your session has ended. Please sign in again.';

  @override
  String get submitQueueErrorPgnInvalid =>
      'The server could not read the moves.';

  @override
  String submitQueueErrorPgnInvalidAt(int moveNumber, String san) {
    return 'The server could not read the moves (move $moveNumber: $san).';
  }

  @override
  String get submitQueueErrorRejected => 'The server did not accept this game.';

  @override
  String get submitQueueErrorInternal => 'Something went wrong in the app.';

  @override
  String get submitQueueUploaded => 'Game uploaded.';

  @override
  String get submitQueueUploadedAnalysing =>
      'Game uploaded. The analysis has started.';

  @override
  String submitQueueUploadedHeld(String reason) {
    return 'Game saved. Analysis not started: $reason';
  }

  @override
  String get submitQueueOpenGame => 'Open';

  @override
  String get submitQueueHoldLimitReached => 'Your analysis limit is used up.';

  @override
  String get submitQueueHoldQueueFull =>
      'Too many of your analyses are still waiting.';

  @override
  String get submitQueueHoldRateLimited => 'Too many requests in a short time.';

  @override
  String get submitQueueHoldEmailNotVerified =>
      'Your e-mail address is not confirmed yet.';

  @override
  String get submitQueueHoldAiConsentRequired =>
      'Your consent to the AI analysis is missing.';

  @override
  String get submitQueueHoldRequestFailed => 'The request did not get through.';
}
