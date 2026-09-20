// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('de'),
  ];

  /// Name of the app, shown by the system in the app switcher.
  ///
  /// In en, this message translates to:
  /// **'Bogner Chess'**
  String get appTitle;

  /// Label of the first tab: the library of the player's games.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get tabGames;

  /// Label of the second tab: start entering or importing a game.
  ///
  /// In en, this message translates to:
  /// **'New game'**
  String get tabNewGame;

  /// Label of the third tab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// Button that repeats a failed action.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// Generic headline of the error view.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonErrorTitle;

  /// Generic body text of the error view.
  ///
  /// In en, this message translates to:
  /// **'Please check your connection and try again.'**
  String get commonErrorMessage;

  /// Body of a placeholder screen during development. Never visible in a release.
  ///
  /// In en, this message translates to:
  /// **'This screen is not built yet.'**
  String get commonPlaceholderMessage;

  /// Headline when a link points to a screen that does not exist.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get notFoundTitle;

  /// Body text when a link points to a screen that does not exist.
  ///
  /// In en, this message translates to:
  /// **'This link does not lead anywhere in the app.'**
  String get notFoundMessage;

  /// Button on the not-found screen that opens the games tab.
  ///
  /// In en, this message translates to:
  /// **'Go to my games'**
  String get notFoundAction;

  /// Title of the games library screen.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get libraryTitle;

  /// Headline of the empty games library.
  ///
  /// In en, this message translates to:
  /// **'No games yet'**
  String get libraryEmptyTitle;

  /// Body text of the empty games library.
  ///
  /// In en, this message translates to:
  /// **'Enter a game or import a PGN to have it analysed.'**
  String get libraryEmptyMessage;

  /// Button in the empty games library that opens the new-game tab.
  ///
  /// In en, this message translates to:
  /// **'New game'**
  String get libraryEmptyAction;

  /// Title of the screen that shows one game.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get libraryGameTitle;

  /// Title of the screen where the player chooses how to add a game.
  ///
  /// In en, this message translates to:
  /// **'New game'**
  String get newGameTitle;

  /// Choice: enter the game move by move on the board.
  ///
  /// In en, this message translates to:
  /// **'Enter moves'**
  String get newGameEnterMoves;

  /// Explanation under the enter-moves choice.
  ///
  /// In en, this message translates to:
  /// **'Play through the game on the board, move by move.'**
  String get newGameEnterMovesHint;

  /// Choice: import a game from PGN text or a PGN file.
  ///
  /// In en, this message translates to:
  /// **'Import PGN'**
  String get newGameImportPgn;

  /// Explanation under the import-PGN choice.
  ///
  /// In en, this message translates to:
  /// **'Paste the text or open a PGN file.'**
  String get newGameImportPgnHint;

  /// Title of the move-entry screen.
  ///
  /// In en, this message translates to:
  /// **'Enter moves'**
  String get entryTitle;

  /// Title of the PGN import screen.
  ///
  /// In en, this message translates to:
  /// **'Import PGN'**
  String get importTitle;

  /// Title of the screen that shows the analysed game.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get reviewTitle;

  /// Title of the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings entry that opens the account screen.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// Settings entry that opens the legal documents.
  ///
  /// In en, this message translates to:
  /// **'Privacy and terms'**
  String get settingsLegal;

  /// Settings entry that opens the about screen.
  ///
  /// In en, this message translates to:
  /// **'About and licences'**
  String get settingsAbout;

  /// App version and build number at the bottom of the settings.
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({build})'**
  String settingsVersion(String version, String build);

  /// Title of the account screen.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// Title of the legal documents screen.
  ///
  /// In en, this message translates to:
  /// **'Privacy and terms'**
  String get legalTitle;

  /// Title of the about screen.
  ///
  /// In en, this message translates to:
  /// **'About and licences'**
  String get aboutTitle;

  /// Title of the one-time consent screen shown before the first analysis.
  ///
  /// In en, this message translates to:
  /// **'AI coach'**
  String get consentAiTitle;

  /// Title of the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// Title of the game metadata screen.
  ///
  /// In en, this message translates to:
  /// **'Game details'**
  String get metadataTitle;

  /// Primary button of the game metadata screen.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get metadataSave;

  /// Shown above the disabled Save button while the colour played is not chosen.
  ///
  /// In en, this message translates to:
  /// **'Choose the colour you played.'**
  String get metadataSaveNeedsColor;

  /// Shown above the disabled Save button while a field is invalid.
  ///
  /// In en, this message translates to:
  /// **'Check the marked fields.'**
  String get metadataSaveNeedsFix;

  /// Heading above the White/Black choice: which colour the user played. Read together with the choice: 'I played White'.
  ///
  /// In en, this message translates to:
  /// **'I played'**
  String get metadataColorLabel;

  /// The white side: a choice in the colour control and a label for White's name.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get metadataColorWhite;

  /// The black side: a choice in the colour control and a label for Black's name.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get metadataColorBlack;

  /// Heading above the result chips.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get metadataResultLabel;

  /// Result chip for a game whose result is not known or that was not finished.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get metadataResultUnknown;

  /// Screen-reader label of the 1-0 result chip.
  ///
  /// In en, this message translates to:
  /// **'White won, 1-0'**
  String get metadataResultWhiteWinsA11y;

  /// Screen-reader label of the 0-1 result chip.
  ///
  /// In en, this message translates to:
  /// **'Black won, 0-1'**
  String get metadataResultBlackWinsA11y;

  /// Screen-reader label of the draw result chip.
  ///
  /// In en, this message translates to:
  /// **'Draw, one half each'**
  String get metadataResultDrawA11y;

  /// Shown under the result chips when the chosen result is a win for the user's colour.
  ///
  /// In en, this message translates to:
  /// **'You won.'**
  String get metadataOutcomeWin;

  /// Shown under the result chips when the chosen result is a loss for the user's colour.
  ///
  /// In en, this message translates to:
  /// **'You lost.'**
  String get metadataOutcomeLoss;

  /// Shown under the result chips when the chosen result is a draw.
  ///
  /// In en, this message translates to:
  /// **'A draw.'**
  String get metadataOutcomeDraw;

  /// Heading above the name and rating fields.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get metadataPlayersLabel;

  /// Label of the opponent's name field.
  ///
  /// In en, this message translates to:
  /// **'Opponent'**
  String get metadataOpponentName;

  /// Label of the user's own name field.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get metadataPlayerName;

  /// Short label of a rating field next to a name. German players say Elo for any rating number.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get metadataRatingLabel;

  /// Screen-reader label of the user's own rating field.
  ///
  /// In en, this message translates to:
  /// **'Your rating'**
  String get metadataPlayerRatingA11y;

  /// Screen-reader label of the opponent's rating field.
  ///
  /// In en, this message translates to:
  /// **'Opponent\'s rating'**
  String get metadataOpponentRatingA11y;

  /// Screen-reader label of White's rating field, used while the colour played is not known.
  ///
  /// In en, this message translates to:
  /// **'White\'s rating'**
  String get metadataWhiteRatingA11y;

  /// Screen-reader label of Black's rating field, used while the colour played is not known.
  ///
  /// In en, this message translates to:
  /// **'Black\'s rating'**
  String get metadataBlackRatingA11y;

  /// Gentle encouragement shown while the user's own rating is empty.
  ///
  /// In en, this message translates to:
  /// **'With your rating the coach explains at your level. An online rating or a rough guess is fine.'**
  String get metadataRatingHint;

  /// Label of the date field: the day the game was played.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get metadataDateLabel;

  /// Text of the date field when no date is set.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get metadataDateUnknown;

  /// Tooltip of the button that removes the date.
  ///
  /// In en, this message translates to:
  /// **'Clear date'**
  String get metadataDateClear;

  /// Error under the date field.
  ///
  /// In en, this message translates to:
  /// **'This date is in the future.'**
  String get metadataDateFuture;

  /// Label of the event field: the tournament, league or occasion.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get metadataEventLabel;

  /// Placeholder inside the empty event field.
  ///
  /// In en, this message translates to:
  /// **'e.g. Club championship'**
  String get metadataEventHint;

  /// Heading above the time-control chips.
  ///
  /// In en, this message translates to:
  /// **'Time control'**
  String get metadataTimeControlLabel;

  /// Time-control chip: long games, an hour or more each.
  ///
  /// In en, this message translates to:
  /// **'Classical'**
  String get metadataTimeControlClassical;

  /// Time-control chip: more than 10 and less than 60 minutes each.
  ///
  /// In en, this message translates to:
  /// **'Rapid'**
  String get metadataTimeControlRapid;

  /// Time-control chip: 3 to 10 minutes each.
  ///
  /// In en, this message translates to:
  /// **'Blitz'**
  String get metadataTimeControlBlitz;

  /// Time-control chip: less than 3 minutes each.
  ///
  /// In en, this message translates to:
  /// **'Bullet'**
  String get metadataTimeControlBullet;

  /// Time-control chip: anything else, such as correspondence or no clock.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get metadataTimeControlOther;

  /// Label of the optional free-text field for the exact time control.
  ///
  /// In en, this message translates to:
  /// **'Minutes + increment'**
  String get metadataTimeControlDetail;

  /// Placeholder inside the empty time-control detail field: 90 minutes plus 30 seconds per move.
  ///
  /// In en, this message translates to:
  /// **'e.g. 90+30'**
  String get metadataTimeControlDetailHint;

  /// Error under a rating field: the accepted range, kept short because the field is narrow.
  ///
  /// In en, this message translates to:
  /// **'{min}–{max}'**
  String metadataRatingError(int min, int max);

  /// One-paragraph description of the app at the top of the about screen.
  ///
  /// In en, this message translates to:
  /// **'Bogner Chess helps you learn from your own games. Enter a game on the board or import a PGN, have it analysed on bognerchess.com, and review it with the comments of the AI coach.'**
  String get aboutDescription;

  /// Statement on the about screen. Must stay; do not soften it.
  ///
  /// In en, this message translates to:
  /// **'Bogner Chess is not affiliated with or endorsed by Lichess. It uses free software that the Lichess project publishes.'**
  String get aboutNotAffiliated;

  /// The legal notice the GPL asks an interactive program to show: copyright, no warranty, licence.
  ///
  /// In en, this message translates to:
  /// **'Copyright © 2026 Bogner Chess. This app is free software: you may redistribute and modify it under the GNU General Public License, version 3 or any later version. It comes with no warranty.'**
  String get aboutFreeSoftwareNotice;

  /// About screen row that opens the public source repository at the tag of the running build. The address is shown below it.
  ///
  /// In en, this message translates to:
  /// **'Source code for this build'**
  String get aboutSourceForBuild;

  /// About screen row that opens the full GPL text. The licence name stays in English.
  ///
  /// In en, this message translates to:
  /// **'GNU General Public License v3'**
  String get aboutGplLicence;

  /// Explanation under the GPL row.
  ///
  /// In en, this message translates to:
  /// **'Full licence text, in English'**
  String get aboutGplLicenceHint;

  /// About screen row and screen title: the additional permission under GPL section 7 for distribution through app stores.
  ///
  /// In en, this message translates to:
  /// **'Additional permission for app stores'**
  String get aboutAppStorePermission;

  /// Explanation under the additional-permission row while the text has no legal sign-off.
  ///
  /// In en, this message translates to:
  /// **'Draft, not in force yet'**
  String get aboutAppStorePermissionDraft;

  /// Warning above the additional-permission text while it is a draft.
  ///
  /// In en, this message translates to:
  /// **'This text is a draft. It grants nothing until the copyright holder publishes the final wording. Until then only the GNU General Public License applies.'**
  String get aboutAppStorePermissionDraftBanner;

  /// About screen row and screen title: the NOTICE file with artwork and source code from other projects.
  ///
  /// In en, this message translates to:
  /// **'Third-party notices'**
  String get aboutThirdPartyNotices;

  /// Explanation under the third-party notices row.
  ///
  /// In en, this message translates to:
  /// **'Chess pieces and source code from other projects'**
  String get aboutThirdPartyNoticesHint;

  /// About screen row that opens the list of packages with their licence texts.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get aboutOpenSourceLicences;

  /// Explanation under the open-source licences row.
  ///
  /// In en, this message translates to:
  /// **'The packages this app is built with'**
  String get aboutOpenSourceLicencesHint;

  /// Message when the browser could not be opened for a link on the about screen.
  ///
  /// In en, this message translates to:
  /// **'The link could not be opened.'**
  String get aboutLinkFailed;

  /// Body of the error view when a bundled licence text cannot be read.
  ///
  /// In en, this message translates to:
  /// **'This text could not be loaded. It is also part of the source code of this app.'**
  String get aboutDocumentLoadFailed;

  /// Button that puts the clipboard text into the PGN field.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get importPasteButton;

  /// Button that opens the system file picker for a PGN or text file.
  ///
  /// In en, this message translates to:
  /// **'Open file…'**
  String get importOpenFileButton;

  /// Label of the large text field on the import screen.
  ///
  /// In en, this message translates to:
  /// **'PGN or moves'**
  String get importFieldLabel;

  /// Example shown inside the empty PGN field. The German example is only an illustration; the field itself needs English piece letters.
  ///
  /// In en, this message translates to:
  /// **'1. e4 e5 2. Nf3 Nc6 3. Bb5 …'**
  String get importFieldHint;

  /// Tooltip of the button that empties the PGN field.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get importClear;

  /// Help text under the empty PGN field.
  ///
  /// In en, this message translates to:
  /// **'Paste a game from another chess app, open a PGN file, or type the moves. Tags such as [White \"…\"] are optional.'**
  String get importEmptyHint;

  /// Shown while a large PGN text is being validated.
  ///
  /// In en, this message translates to:
  /// **'Checking the moves…'**
  String get importChecking;

  /// Snackbar after tapping paste with an empty clipboard.
  ///
  /// In en, this message translates to:
  /// **'There is no text on the clipboard.'**
  String get importClipboardEmpty;

  /// Snackbar when the picked file cannot be read.
  ///
  /// In en, this message translates to:
  /// **'This file could not be read.'**
  String get importFileUnreadable;

  /// Headline of the error panel when one game is invalid.
  ///
  /// In en, this message translates to:
  /// **'This game can\'t be imported'**
  String get importErrorTitleGame;

  /// Headline of the error panel when the whole text is refused.
  ///
  /// In en, this message translates to:
  /// **'This text can\'t be imported'**
  String get importErrorTitleText;

  /// Error: the pasted text or the file exceeds the size limit.
  ///
  /// In en, this message translates to:
  /// **'The text is too large. At most 2 MB can be imported at once.'**
  String get importErrorTooLarge;

  /// Error: more games than the limit.
  ///
  /// In en, this message translates to:
  /// **'There are more than {max} games in this text. Please import a smaller file.'**
  String importErrorTooManyGames(int max);

  /// Error: the text contains neither tags nor moves.
  ///
  /// In en, this message translates to:
  /// **'No chess game was found in this text. A game looks like this: 1. e4 e5 2. Nf3 Nc6'**
  String get importErrorNoGames;

  /// Error: a game with tags but without moves.
  ///
  /// In en, this message translates to:
  /// **'This game has no moves.'**
  String get importErrorNoMoves;

  /// Error: the PGN has a FEN or SetUp tag.
  ///
  /// In en, this message translates to:
  /// **'This game starts from a set-up position (FEN). For now, only games that start from the normal starting position can be imported.'**
  String get importErrorCustomStart;

  /// Error: the PGN has a Variant tag other than standard chess.
  ///
  /// In en, this message translates to:
  /// **'This is a game of {variant}. Only standard chess can be imported.'**
  String importErrorVariant(String variant);

  /// Error: a move of the main line is illegal. The placeholder is the numbered move as written.
  ///
  /// In en, this message translates to:
  /// **'{move} is not a legal move in this position.'**
  String importErrorIllegalMove(String move);

  /// Error: a SAN move fits several legal moves.
  ///
  /// In en, this message translates to:
  /// **'{move} is ambiguous: more than one piece can make this move. Add the file or rank it starts from, as in Nbd7.'**
  String importErrorAmbiguousMove(String move);

  /// Error: a word in the movetext is not a move. Moves use English piece letters (K, Q, R, B, N).
  ///
  /// In en, this message translates to:
  /// **'“{token}” is not a chess move.'**
  String importErrorUnreadable(String token);

  /// Second sentence of the unreadable-move error.
  ///
  /// In en, this message translates to:
  /// **'Moves need the English piece letters K, Q, R, B and N.'**
  String get importErrorUnreadableHint;

  /// Error: unterminated brace comment.
  ///
  /// In en, this message translates to:
  /// **'A comment that opens with a curly bracket is never closed.'**
  String get importErrorUnterminatedComment;

  /// Error: unterminated variation.
  ///
  /// In en, this message translates to:
  /// **'A variation that opens with a round bracket is never closed.'**
  String get importErrorUnterminatedVariation;

  /// Where in the text the error is.
  ///
  /// In en, this message translates to:
  /// **'Line {line}'**
  String importErrorWhereLine(int line);

  /// Where in the text the error is, with the move number.
  ///
  /// In en, this message translates to:
  /// **'Line {line}, at move {number}'**
  String importErrorWhereLineMove(int line, int number);

  /// Closing line of the error panel.
  ///
  /// In en, this message translates to:
  /// **'Correct the text above. It is checked again as you type.'**
  String get importErrorFixHint;

  /// Headline above the list of games found in the text.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 game found} other{{count} games found}}'**
  String importGamesFound(int count);

  /// Instruction above the list of games.
  ///
  /// In en, this message translates to:
  /// **'Choose the game you want to import.'**
  String get importChooseGame;

  /// Marks a game in the list that failed validation.
  ///
  /// In en, this message translates to:
  /// **'Can\'t be imported'**
  String get importGameNotImportable;

  /// Button that returns from the preview to the list of games.
  ///
  /// In en, this message translates to:
  /// **'Choose another game'**
  String get importChooseAnother;

  /// Headline of the preview card of a valid game.
  ///
  /// In en, this message translates to:
  /// **'Ready to import'**
  String get importPreviewTitle;

  /// The two players of a game, White first.
  ///
  /// In en, this message translates to:
  /// **'{white} – {black}'**
  String importPlayers(String white, String black);

  /// Stands in for a missing name of the player with the white pieces.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get importPlayerWhite;

  /// Stands in for a missing name of the player with the black pieces.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get importPlayerBlack;

  /// Length of the game in full moves.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 move} other{{count} moves}}'**
  String importMoves(int count);

  /// Shown when the PGN has no result or the result *.
  ///
  /// In en, this message translates to:
  /// **'No result'**
  String get importResultOpen;

  /// Accessibility label of the small board on the preview.
  ///
  /// In en, this message translates to:
  /// **'Final position'**
  String get importFinalPosition;

  /// Warning on the preview: the PGN contained variations.
  ///
  /// In en, this message translates to:
  /// **'Variations were removed. Only the main line is imported.'**
  String get importWarningVariations;

  /// Warning on the preview: the PGN contained comments, NAGs or glyphs.
  ///
  /// In en, this message translates to:
  /// **'Comments and annotation symbols were removed.'**
  String get importWarningComments;

  /// Primary button: hand the chosen game to the next step.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get importContinue;

  /// Tooltip and screen-reader label of the button that turns the board around on the move-entry screen.
  ///
  /// In en, this message translates to:
  /// **'Flip board'**
  String get entryFlipBoard;

  /// Tooltip of the overflow menu on the move-entry screen.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get entryMoreOptions;

  /// Checkable menu item: when on, a pawn reaching the last rank becomes a queen without showing the promotion picker.
  ///
  /// In en, this message translates to:
  /// **'Always promote to queen'**
  String get entryAutoQueen;

  /// Large button that takes back the move shown on the board.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get entryUndo;

  /// Tooltip and screen-reader label of the button that steps one move forward or restores a move that was just undone.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get entryRedo;

  /// Button that finishes move entry.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get entryDone;

  /// Hint shown in place of the move list while no move has been entered.
  ///
  /// In en, this message translates to:
  /// **'Play the first move on the board.'**
  String get entryMoveListEmpty;

  /// Screen-reader label of the first item of the move list, which jumps back to the starting position.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get entryMoveListStart;

  /// Screen-reader label of one move in the move list; activating it jumps to that move.
  ///
  /// In en, this message translates to:
  /// **'{number}. {side, select, white{White} other{Black}}, {san}'**
  String entryMoveSemantics(int number, String side, String san);

  /// Status line under the board while the game goes on.
  ///
  /// In en, this message translates to:
  /// **'Move {number} · {side, select, white{White to move} other{Black to move}}'**
  String entryStatusToMove(int number, String side);

  /// Status line under the board when the position shown is checkmate.
  ///
  /// In en, this message translates to:
  /// **'Checkmate · {winner, select, white{White wins} other{Black wins}}'**
  String entryStatusCheckmate(String winner);

  /// Status line under the board when the position shown is stalemate.
  ///
  /// In en, this message translates to:
  /// **'Stalemate · draw'**
  String get entryStatusStalemate;

  /// Status line under the board when neither side can checkmate any more.
  ///
  /// In en, this message translates to:
  /// **'Draw · insufficient material'**
  String get entryStatusInsufficientMaterial;

  /// Title of the confirmation shown when a different move is played in the middle of the entered game.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Replace the following move?} other{Replace the following {count} moves?}}'**
  String entryOverwriteTitle(int count);

  /// Body of the overwrite confirmation.
  ///
  /// In en, this message translates to:
  /// **'{newSan} is not the move you entered here before ({oldSan}). Everything from {oldSan} on will be removed.'**
  String entryOverwriteMessage(String newSan, String oldSan);

  /// Confirms the overwrite: the new move replaces the rest of the game.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get entryOverwriteConfirm;

  /// Dismisses the overwrite confirmation; nothing changes.
  ///
  /// In en, this message translates to:
  /// **'Keep moves'**
  String get entryOverwriteCancel;

  /// Confirmation after tapping Done while the next step of the flow is not available.
  ///
  /// In en, this message translates to:
  /// **'Saved as draft'**
  String get entrySavedAsDraft;

  /// Screen-reader label of an empty board square.
  ///
  /// In en, this message translates to:
  /// **'{square}, empty'**
  String boardSquareEmpty(String square);

  /// Screen-reader label of an occupied board square.
  ///
  /// In en, this message translates to:
  /// **'{square}, {piece, select, whiteKing{white king} whiteQueen{white queen} whiteRook{white rook} whiteBishop{white bishop} whiteKnight{white knight} whitePawn{white pawn} blackKing{black king} blackQueen{black queen} blackRook{black rook} blackBishop{black bishop} blackKnight{black knight} other{black pawn}}'**
  String boardSquarePiece(String square, String piece);

  /// Screen-reader label of a choice in the promotion picker.
  ///
  /// In en, this message translates to:
  /// **'Promote to {role, select, queen{queen} rook{rook} bishop{bishop} other{knight}}'**
  String boardPromoteTo(String role);

  /// Screen-reader label of every square outside the promotion picker while it is open.
  ///
  /// In en, this message translates to:
  /// **'Cancel promotion'**
  String get boardCancelPromotion;

  /// Sign-in screen: one sentence under the app name that says what the app is for.
  ///
  /// In en, this message translates to:
  /// **'Enter or import your games, have them analysed and review them with coach comments.'**
  String get signInTagline;

  /// Sign-in screen: button that opens the login page with e-mail and password.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInPrimary;

  /// Sign-in screen: button that opens the registration page.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signInRegister;

  /// Sign-in screen: Sign in with Apple button. Use Apple's official wording for the language.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get signInApple;

  /// Sign-in screen: Sign in with Google button.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get signInGoogle;

  /// Sign-in screen: divider between the Apple/Google buttons and the e-mail buttons.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get signInOr;

  /// Sign-in screen: note that app and website share one account. Keep the domain as it is.
  ///
  /// In en, this message translates to:
  /// **'The same account works on bognerchess.com.'**
  String get signInSameAccount;

  /// Sign-in screen: shown (and announced by VoiceOver) while the system browser sheet is open.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the sign-in page …'**
  String get signInBusy;

  /// Sign-in screen: title of the message shown when the identity server could not be reached.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get signInErrorOfflineTitle;

  /// Sign-in screen: body of the offline message.
  ///
  /// In en, this message translates to:
  /// **'The sign-in page could not be reached. Check your internet connection and try again.'**
  String get signInErrorOfflineMessage;

  /// Sign-in screen: title of the message shown when sign-in failed for a reason other than the connection.
  ///
  /// In en, this message translates to:
  /// **'Sign-in did not work'**
  String get signInErrorTitle;

  /// Sign-in screen: body of the generic sign-in error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side. Please try again in a moment.'**
  String get signInErrorMessage;

  /// Sign-in screen: text button that opens the help for people who registered but have not clicked the confirmation link.
  ///
  /// In en, this message translates to:
  /// **'E-mail not confirmed yet?'**
  String get signInVerifyToggle;

  /// Sign-in screen: title of the e-mail confirmation help.
  ///
  /// In en, this message translates to:
  /// **'Confirm your e-mail address'**
  String get signInVerifyTitle;

  /// Sign-in screen: body of the e-mail confirmation help. The link usually opens outside the app.
  ///
  /// In en, this message translates to:
  /// **'We sent you an e-mail with a confirmation link. Open the link (it may open in Safari, that is fine), then come back here and sign in.'**
  String get signInVerifyBody;

  /// Sign-in screen: button in the e-mail confirmation help; starts a normal sign-in.
  ///
  /// In en, this message translates to:
  /// **'I have confirmed it – sign in'**
  String get signInVerifyAction;

  /// Name of a colour on the review screen: fallback player name, column head of the move-quality table.
  ///
  /// In en, this message translates to:
  /// **'{side, select, white{White} other{Black}}'**
  String reviewSideName(String side);

  /// Screen-reader label of an accuracy chip in the review header.
  ///
  /// In en, this message translates to:
  /// **'Accuracy of {side, select, white{White} other{Black}}: {value} percent'**
  String reviewAccuracySemantics(String side, String value);

  /// Tooltip of the menu button in the review app bar.
  ///
  /// In en, this message translates to:
  /// **'Board options'**
  String get reviewMenu;

  /// Checkable menu item: green arrow for the best move of the engine.
  ///
  /// In en, this message translates to:
  /// **'Show best move'**
  String get reviewShowBestArrow;

  /// Checkable menu item: amber arrow on the move that was played.
  ///
  /// In en, this message translates to:
  /// **'Show played move'**
  String get reviewShowPlayedArrow;

  /// Menu item that turns the review board around.
  ///
  /// In en, this message translates to:
  /// **'Flip board'**
  String get reviewFlipBoard;

  /// Tooltip and screen-reader label of the button that jumps to the start position.
  ///
  /// In en, this message translates to:
  /// **'Go to start'**
  String get reviewGoToStart;

  /// Tooltip and screen-reader label of the step-back button.
  ///
  /// In en, this message translates to:
  /// **'Previous move'**
  String get reviewPreviousMove;

  /// Tooltip and screen-reader label of the step-forward button.
  ///
  /// In en, this message translates to:
  /// **'Next move'**
  String get reviewNextMove;

  /// Tooltip and screen-reader label of the button that jumps to the last move.
  ///
  /// In en, this message translates to:
  /// **'Go to end'**
  String get reviewGoToEnd;

  /// Tooltip and screen-reader label of the button that jumps to the previous moment the coach commented on.
  ///
  /// In en, this message translates to:
  /// **'Previous key moment'**
  String get reviewPreviousMoment;

  /// Button (and tooltip) that jumps to the next moment the coach commented on.
  ///
  /// In en, this message translates to:
  /// **'Next key moment'**
  String get reviewNextMoment;

  /// Tab below the review board: the comments of the AI coach. Keep it very short.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get reviewTabCoach;

  /// Tab below the review board: the move list. Keep it very short.
  ///
  /// In en, this message translates to:
  /// **'Moves'**
  String get reviewTabMoves;

  /// Tab below the review board: the lessons of the game and the move-quality table. Keep it very short.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get reviewTabSummary;

  /// The quality of a move in words. "strong" is a move the coach praised.
  ///
  /// In en, this message translates to:
  /// **'{classification, select, book{Book move} best{Best move} good{Good move} inaccuracy{Inaccuracy} mistake{Mistake} blunder{Blunder} strong{Strong move} other{Move}}'**
  String reviewClassification(String classification);

  /// The theme of a coach comment or lesson, shown as a small chip.
  ///
  /// In en, this message translates to:
  /// **'{theme, select, opening{Opening} development{Development} centralBreak{Central break} kingSafety{King safety} tactics{Tactics} hangingPiece{Hanging piece} calculation{Calculation} pieceActivity{Piece activity} pawnStructure{Pawn structure} endgame{Endgame} materialConversion{Converting an advantage} other{Chess}}'**
  String reviewTheme(String theme);

  /// Evaluation in words: nobody is better.
  ///
  /// In en, this message translates to:
  /// **'Equal position'**
  String get reviewEvalEqual;

  /// Evaluation in words: a small advantage.
  ///
  /// In en, this message translates to:
  /// **'{side, select, white{White is slightly better} other{Black is slightly better}}'**
  String reviewEvalSlight(String side);

  /// Evaluation in words: a clear advantage.
  ///
  /// In en, this message translates to:
  /// **'{side, select, white{White is clearly better} other{Black is clearly better}}'**
  String reviewEvalClear(String side);

  /// Evaluation in words: a decisive advantage.
  ///
  /// In en, this message translates to:
  /// **'{side, select, white{White is winning} other{Black is winning}}'**
  String reviewEvalWinning(String side);

  /// Evaluation in words: a forced mate.
  ///
  /// In en, this message translates to:
  /// **'Mate in {count} for {side, select, white{White} other{Black}}'**
  String reviewEvalMate(int count, String side);

  /// Evaluation in words: checkmate is on the board.
  ///
  /// In en, this message translates to:
  /// **'{side, select, white{Checkmate. White wins} black{Checkmate. Black wins} other{Checkmate}}'**
  String reviewEvalCheckmate(String side);

  /// Small line above a coach comment: which of the moments the coach picked this is.
  ///
  /// In en, this message translates to:
  /// **'Key moment {index} of {total}'**
  String reviewMomentCounter(int index, int total);

  /// Small footnote under every coach comment.
  ///
  /// In en, this message translates to:
  /// **'AI-generated. May contain mistakes.'**
  String get reviewCoachAiNote;

  /// Screen-reader label and tooltip of the thumbs-up button of a coach comment.
  ///
  /// In en, this message translates to:
  /// **'Helpful'**
  String get reviewThumbUp;

  /// Screen-reader label and tooltip of the thumbs-down button of a coach comment.
  ///
  /// In en, this message translates to:
  /// **'Not helpful'**
  String get reviewThumbDown;

  /// Snackbar after a thumbs up or down could not be stored.
  ///
  /// In en, this message translates to:
  /// **'Your rating could not be saved.'**
  String get reviewFeedbackFailed;

  /// Screen-reader label of a button under a coach comment that plays a line on the board. The label comes from the server, for example Better.
  ///
  /// In en, this message translates to:
  /// **'Show line: {label}'**
  String reviewShowLine(String label);

  /// Engine fact on a move without a coach comment: the move the engine prefers.
  ///
  /// In en, this message translates to:
  /// **'Better was {san}.'**
  String reviewFactBetterWas(String san);

  /// Headline of the coach tab on the start position.
  ///
  /// In en, this message translates to:
  /// **'The moments that mattered'**
  String get reviewStartPositionTitle;

  /// Explanation on the coach tab on the start position.
  ///
  /// In en, this message translates to:
  /// **'The coach picked the moments that decided this game. Swipe through them, or step through every move.'**
  String get reviewStartPositionHint;

  /// Button on the start position that jumps to the first moment the coach commented on.
  ///
  /// In en, this message translates to:
  /// **'First key moment'**
  String get reviewFirstMoment;

  /// Button on the coach tab after the last key moment: opens the summary tab.
  ///
  /// In en, this message translates to:
  /// **'See your lessons'**
  String get reviewOpenSummary;

  /// What kind of line the line viewer is showing.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, bestLine{Best continuation} refutation{Why the move fails} alternative{Another good option} other{Line}}'**
  String reviewLineKind(String kind);

  /// Button that leaves the line viewer.
  ///
  /// In en, this message translates to:
  /// **'Back to game'**
  String get reviewLineBack;

  /// Tooltip and screen-reader label of the step-back button of the line viewer.
  ///
  /// In en, this message translates to:
  /// **'Previous move of the line'**
  String get reviewLinePrevious;

  /// Tooltip and screen-reader label of the step-forward button of the line viewer.
  ///
  /// In en, this message translates to:
  /// **'Next move of the line'**
  String get reviewLineNext;

  /// Screen-reader suffix of a move in the move list that has a coach comment.
  ///
  /// In en, this message translates to:
  /// **'with coach comment'**
  String get reviewMoveHasComment;

  /// Headline of the lessons on the summary tab.
  ///
  /// In en, this message translates to:
  /// **'What to take away'**
  String get reviewLessonsTitle;

  /// Chip under a lesson that jumps to the move the lesson is about.
  ///
  /// In en, this message translates to:
  /// **'Move {label}'**
  String reviewLessonEvidence(String label);

  /// Shown on the summary tab when the analysis has no lessons.
  ///
  /// In en, this message translates to:
  /// **'There are no lessons for this game.'**
  String get reviewLessonsEmpty;

  /// Headline of the table that counts moves by quality for both sides.
  ///
  /// In en, this message translates to:
  /// **'Move quality'**
  String get reviewQualityTitle;

  /// Row label of the accuracy of both sides in the move-quality table.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get reviewAccuracy;

  /// Screen-reader label of the evaluation graph.
  ///
  /// In en, this message translates to:
  /// **'Evaluation graph'**
  String get reviewGraphLabel;

  /// Banner when the analysis was made in a newer format than this app version understands. Board and moves still work.
  ///
  /// In en, this message translates to:
  /// **'Update the app to see this analysis.'**
  String get reviewUpdateBanner;

  /// Error message when the analysis document is damaged.
  ///
  /// In en, this message translates to:
  /// **'This analysis could not be read.'**
  String get reviewInvalidMessage;

  /// Status line under the review board before the first move.
  ///
  /// In en, this message translates to:
  /// **'Start position'**
  String get reviewStartPosition;

  /// Screen-reader label of the loading state of the review screen.
  ///
  /// In en, this message translates to:
  /// **'Loading analysis'**
  String get reviewLoading;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
