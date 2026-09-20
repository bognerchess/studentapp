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

  /// Name of the privacy policy, as a list row, a link and the title of its screen.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get legalPrivacyPolicy;

  /// Name of the terms of use, as a list row and the title of its screen.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get legalTerms;

  /// Badge on a legal text that has had no legal review yet. Shown on test builds. Capitals.
  ///
  /// In en, this message translates to:
  /// **'DRAFT'**
  String get legalDraftLabel;

  /// Explanation next to the draft badge on a legal text.
  ///
  /// In en, this message translates to:
  /// **'This text is a placeholder and has not been legally reviewed.'**
  String get legalDraftHint;

  /// Title when the backend has no published version of a legal text.
  ///
  /// In en, this message translates to:
  /// **'Not available yet'**
  String get legalNotPublishedTitle;

  /// Message when the backend has no published version of a legal text. Keep the domain as it is.
  ///
  /// In en, this message translates to:
  /// **'This text has not been published yet. You can find it on bognerchess.com.'**
  String get legalNotPublishedMessage;

  /// Title when a legal text cannot be loaded without a connection.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get legalOfflineTitle;

  /// Message when a legal text cannot be loaded without a connection.
  ///
  /// In en, this message translates to:
  /// **'The text is loaded from the server, so that it is always the current version. Connect to the internet and try again.'**
  String get legalOfflineMessage;

  /// Screen-reader label of the loading indicator of a legal text.
  ///
  /// In en, this message translates to:
  /// **'Loading text'**
  String get legalLoading;

  /// Line under the title of a legal text: its version number and the date it was published.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · {date}'**
  String legalVersionLine(int version, String date);

  /// Note when a legal text was asked for in German and the server only has English.
  ///
  /// In en, this message translates to:
  /// **'This text is only available in English at the moment.'**
  String get legalEnglishOnly;

  /// Tooltip of the close button of the AI consent screen. Closing means not agreeing.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get consentAiClose;

  /// Screen-reader label of the loading indicator of the AI consent screen.
  ///
  /// In en, this message translates to:
  /// **'Loading text'**
  String get consentAiLoading;

  /// Prominent sentence on the AI consent screen that names the third-party AI provider. The placeholder is a company or product name from the server.
  ///
  /// In en, this message translates to:
  /// **'Analysis comments are generated by {provider}.'**
  String consentAiProvider(String provider);

  /// The same sentence when the server did not name the provider.
  ///
  /// In en, this message translates to:
  /// **'Analysis comments are generated by an AI language model of an external provider.'**
  String get consentAiProviderUnnamed;

  /// Headline of the list of data that is sent to the AI provider.
  ///
  /// In en, this message translates to:
  /// **'What is sent to the AI provider'**
  String get consentAiSentTitle;

  /// Item of the list of data sent to the AI provider.
  ///
  /// In en, this message translates to:
  /// **'The moves of the game'**
  String get consentAiSentMoves;

  /// Item of the list of data sent to the AI provider.
  ///
  /// In en, this message translates to:
  /// **'The positions on the board'**
  String get consentAiSentPositions;

  /// Item of the list of data sent to the AI provider.
  ///
  /// In en, this message translates to:
  /// **'The chess engine\'s evaluations and best lines'**
  String get consentAiSentEvaluations;

  /// Item of the list of data sent to the AI provider.
  ///
  /// In en, this message translates to:
  /// **'Which colour you played'**
  String get consentAiSentColour;

  /// Item of the list of data sent to the AI provider. A rating band is a range like 1200 to 1400, not the exact rating.
  ///
  /// In en, this message translates to:
  /// **'A rough rating range, so that the explanations fit your level'**
  String get consentAiSentRatingBand;

  /// Headline of the list of data that is not sent to the AI provider.
  ///
  /// In en, this message translates to:
  /// **'What is never sent'**
  String get consentAiNotSentTitle;

  /// Item of the list of data that is never sent to the AI provider.
  ///
  /// In en, this message translates to:
  /// **'Your name and the name of your opponent'**
  String get consentAiNotSentName;

  /// Item of the list of data that is never sent to the AI provider.
  ///
  /// In en, this message translates to:
  /// **'Your e-mail address'**
  String get consentAiNotSentEmail;

  /// Item of the list of data that is never sent to the AI provider.
  ///
  /// In en, this message translates to:
  /// **'Your account or anything that identifies it'**
  String get consentAiNotSentAccount;

  /// Item of the list of data that is never sent to the AI provider.
  ///
  /// In en, this message translates to:
  /// **'Event, place and date of the game'**
  String get consentAiNotSentEvent;

  /// Primary button of the AI consent screen: records the consent.
  ///
  /// In en, this message translates to:
  /// **'Agree and continue'**
  String get consentAiAgree;

  /// Secondary button of the AI consent screen: closes it without consent. No analysis is requested.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get consentAiNotNow;

  /// Error under the AI consent text when recording (or withdrawing) the consent failed.
  ///
  /// In en, this message translates to:
  /// **'Your consent could not be saved. Check your connection and try again.'**
  String get consentAiSaveFailed;

  /// Shown instead of the agree button when the AI consent screen is opened from the settings and the consent is already given.
  ///
  /// In en, this message translates to:
  /// **'You have agreed to this version.'**
  String get consentAiAlreadyAgreed;

  /// Button on the AI consent screen, when the consent is given: withdraws it. New analyses are then refused until the user agrees again.
  ///
  /// In en, this message translates to:
  /// **'Withdraw consent'**
  String get consentAiWithdraw;

  /// Title of the AI consent screen when the text cannot be loaded without a connection.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get consentAiOfflineTitle;

  /// Message of the AI consent screen when there is no connection.
  ///
  /// In en, this message translates to:
  /// **'Consent can only be given online, because the server has to know about it before a game is analysed. Your game is kept on this device.'**
  String get consentAiOfflineMessage;

  /// Message of the AI consent screen when loading failed for another reason than the connection.
  ///
  /// In en, this message translates to:
  /// **'The consent text could not be loaded. Please try again.'**
  String get consentAiErrorMessage;

  /// Title of the AI consent screen when the server has no reviewed consent text.
  ///
  /// In en, this message translates to:
  /// **'Not available yet'**
  String get consentAiUnavailableTitle;

  /// Message of the AI consent screen when the server has no reviewed consent text.
  ///
  /// In en, this message translates to:
  /// **'The consent text for the AI analysis is not available yet. Your games are saved; please try again later.'**
  String get consentAiUnavailableMessage;

  /// Title of the one-time question about usage statistics and crash reports, when the server's own text is not available.
  ///
  /// In en, this message translates to:
  /// **'Help improve the app?'**
  String get consentAnalyticsTitle;

  /// Body of the one-time question about usage statistics and crash reports, when the server's own text is not available.
  ///
  /// In en, this message translates to:
  /// **'May the app send usage statistics and crash reports? They tell us which screens are used and where the app fails. They never contain your games, your moves or your name.'**
  String get consentAnalyticsBody;

  /// Small print under the question about usage statistics: opt-in, changeable, and the same switch covers crash reports.
  ///
  /// In en, this message translates to:
  /// **'This is switched off unless you allow it, and you can change it in the settings at any time. It also covers crash reports.'**
  String get consentAnalyticsFootnote;

  /// Button that grants the consent for usage statistics and crash reports.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get consentAnalyticsAllow;

  /// Button that refuses the consent for usage statistics and crash reports.
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get consentAnalyticsDecline;

  /// Title of the account row and card when the sign-in token carries neither a name nor an e-mail address.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get settingsAccountSignedIn;

  /// Settings section with the analysis quota.
  ///
  /// In en, this message translates to:
  /// **'Analyses'**
  String get settingsSectionAnalyses;

  /// Settings section with piece set and board colours.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get settingsSectionBoard;

  /// Settings section with options of the move-entry screen.
  ///
  /// In en, this message translates to:
  /// **'Entering moves'**
  String get settingsSectionEntry;

  /// Settings section with the analytics switch and the AI consent.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get settingsSectionPrivacy;

  /// Explanation under the "always promote to queen" switch in the settings.
  ///
  /// In en, this message translates to:
  /// **'Skips the choice of piece when a pawn reaches the last rank.'**
  String get settingsAutoQueenHint;

  /// Switch in the settings: consent for product analytics and crash reports. Off by default.
  ///
  /// In en, this message translates to:
  /// **'Usage statistics and crash reports'**
  String get settingsAnalytics;

  /// Explanation under the analytics switch.
  ///
  /// In en, this message translates to:
  /// **'Helps us improve the app. Never contains your games or your name.'**
  String get settingsAnalyticsHint;

  /// Row in the settings that shows whether the AI consent is given.
  ///
  /// In en, this message translates to:
  /// **'AI analysis consent'**
  String get settingsAiConsent;

  /// State of the AI consent row: given, with the version of the text.
  ///
  /// In en, this message translates to:
  /// **'Agreed (version {version})'**
  String settingsAiConsentAgreed(int version);

  /// State of the AI consent row: an older version was accepted and a new one is published.
  ///
  /// In en, this message translates to:
  /// **'The text has changed. Please read it again.'**
  String get settingsAiConsentNewVersion;

  /// State of the AI consent row: not given.
  ///
  /// In en, this message translates to:
  /// **'Not agreed yet. You are asked before your first analysis.'**
  String get settingsAiConsentNotYet;

  /// State of the AI consent row: the server could not be asked.
  ///
  /// In en, this message translates to:
  /// **'The status could not be loaded.'**
  String get settingsAiConsentUnknown;

  /// State of the AI consent row while the server is asked.
  ///
  /// In en, this message translates to:
  /// **'Loading …'**
  String get settingsAiConsentLoading;

  /// Button of the AI consent row: opens the consent text.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get settingsAiConsentReview;

  /// Label of the number of analyses used today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get settingsUsageToday;

  /// Label of the number of analyses used this month.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get settingsUsageMonth;

  /// Analyses used and allowed in a period, e.g. "1 of 3".
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit}'**
  String settingsUsageOf(int used, int limit);

  /// Analyses used in a period that has no limit.
  ///
  /// In en, this message translates to:
  /// **'{used, plural, =1{1 analysis} other{{used} analyses}}'**
  String settingsUsageCount(int used);

  /// When the daily analysis count starts again; the placeholder is a time of day like 02:00.
  ///
  /// In en, this message translates to:
  /// **'Resets at {time}.'**
  String settingsUsageResetsAt(String time);

  /// When an analysis count starts again; the placeholder is a date like "October 1", possibly with a time.
  ///
  /// In en, this message translates to:
  /// **'Resets on {date}.'**
  String settingsUsageResetsOn(String date);

  /// In front of the reset time when all analyses of a period are used.
  ///
  /// In en, this message translates to:
  /// **'Limit reached.'**
  String get settingsUsageLimitReached;

  /// Badge for accounts without an analysis limit.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get settingsUsageUnlimited;

  /// How many analyses are queued or running, and how many may be at once.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 analysis in progress} other{{count} analyses in progress}} (at most {max} at a time)'**
  String settingsUsageQueued(int count, int max);

  /// Shown instead of the analysis quota when loading failed; a retry button is next to it.
  ///
  /// In en, this message translates to:
  /// **'The numbers could not be loaded.'**
  String get settingsUsageError;

  /// Screen-reader label of the loading indicator of the analysis quota.
  ///
  /// In en, this message translates to:
  /// **'Loading analysis quota'**
  String get settingsUsageLoading;

  /// Label above the choice of piece set.
  ///
  /// In en, this message translates to:
  /// **'Pieces'**
  String get settingsBoardPieces;

  /// Label above the choice of board colours.
  ///
  /// In en, this message translates to:
  /// **'Board colours'**
  String get settingsBoardColors;

  /// Name of a board colour scheme.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get settingsBoardColorsBrown;

  /// Name of a board colour scheme.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get settingsBoardColorsBlue;

  /// Name of a board colour scheme.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get settingsBoardColorsGreen;

  /// Name of a board colour scheme (light grey and olive squares).
  ///
  /// In en, this message translates to:
  /// **'Olive'**
  String get settingsBoardColorsOlive;

  /// Screen-reader label of the preview board in the settings. Placeholders: the name of the piece set and of the colour scheme.
  ///
  /// In en, this message translates to:
  /// **'Board preview: {pieces} pieces, {colours}'**
  String settingsBoardPreviewLabel(String pieces, String colours);

  /// Title of the blocking screen when the server no longer supports this version of the app.
  ///
  /// In en, this message translates to:
  /// **'Please update the app'**
  String get updateRequiredTitle;

  /// Message of the blocking update screen.
  ///
  /// In en, this message translates to:
  /// **'This version of Bogner Chess is no longer supported. Install the current version to continue. Your games and drafts are kept.'**
  String get updateRequiredMessage;

  /// Button of the blocking update screen.
  ///
  /// In en, this message translates to:
  /// **'Open the App Store'**
  String get updateRequiredAction;

  /// Note on the account screen. Keep the domain as it is.
  ///
  /// In en, this message translates to:
  /// **'This is your bognerchess.com account. The app and the website share it: the same sign-in, the same games.'**
  String get accountSameAccount;

  /// Hint on the account screen when the e-mail address is not verified.
  ///
  /// In en, this message translates to:
  /// **'Your e-mail address is not confirmed yet. Open the link in the e-mail we sent you.'**
  String get accountEmailNotVerified;

  /// Button on the account screen, and the confirm button of its dialog.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// Small print under the sign-out button.
  ///
  /// In en, this message translates to:
  /// **'Games you have not sent yet stay on this device.'**
  String get accountSignOutHint;

  /// Title of the dialog that confirms the sign-out.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get accountSignOutConfirmTitle;

  /// Message of the dialog that confirms the sign-out.
  ///
  /// In en, this message translates to:
  /// **'Your games stay in your account. Drafts you have not sent yet stay on this device and are there when you sign in again.'**
  String get accountSignOutConfirmMessage;

  /// Cancel button of dialogs on the account screen.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get accountCancel;

  /// Button that leaves the "cannot be deleted" screen.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get accountBack;

  /// Headline of the account-deletion part of the account screen.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDeleteSection;

  /// One sentence above the link to the account deletion. Keep the domain as it is.
  ///
  /// In en, this message translates to:
  /// **'Deletes your bognerchess.com account with all games and analyses, in the app and on the website.'**
  String get accountDeleteTeaser;

  /// Link on the account screen that opens the account deletion. The ellipsis says that more steps follow.
  ///
  /// In en, this message translates to:
  /// **'Delete account …'**
  String get accountDelete;

  /// Title of the account-deletion screen.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDeleteTitle;

  /// Headline of the warning box on the account-deletion screen. Keep the domain as it is.
  ///
  /// In en, this message translates to:
  /// **'This deletes your bognerchess.com account'**
  String get accountDeleteSameAccountTitle;

  /// Body of the warning box on the account-deletion screen. Keep the domain as it is.
  ///
  /// In en, this message translates to:
  /// **'The app has no account of its own. You sign in with your bognerchess.com account, and that account is deleted: you lose access to the website as well, not only to this app.'**
  String get accountDeleteSameAccountBody;

  /// Headline on the account-deletion screen.
  ///
  /// In en, this message translates to:
  /// **'What is deleted'**
  String get accountDeleteWhatGoesTitle;

  /// Item of "what is deleted".
  ///
  /// In en, this message translates to:
  /// **'All your games, analyses and coach comments'**
  String get accountDeleteGoesGames;

  /// Item of "what is deleted".
  ///
  /// In en, this message translates to:
  /// **'Your profile and your sign-in; your personal data is anonymised'**
  String get accountDeleteGoesProfile;

  /// Item of "what is deleted".
  ///
  /// In en, this message translates to:
  /// **'Everything the app has stored on this device, including drafts'**
  String get accountDeleteGoesDevice;

  /// Headline on the account-deletion screen.
  ///
  /// In en, this message translates to:
  /// **'What we have to keep'**
  String get accountDeleteWhatStaysTitle;

  /// Item of "what we have to keep".
  ///
  /// In en, this message translates to:
  /// **'Paid invoices, for as long as the law requires us to keep them'**
  String get accountDeleteStaysInvoices;

  /// Headline on the account-deletion screen.
  ///
  /// In en, this message translates to:
  /// **'Before you go on'**
  String get accountDeleteGoodToKnowTitle;

  /// Item of "before you go on".
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone. Nobody can restore a deleted account, not even our support.'**
  String get accountDeleteIrreversible;

  /// Item of "before you go on".
  ///
  /// In en, this message translates to:
  /// **'Accounts with an active membership, open invoices or linked child accounts cannot be deleted here. If that applies to you, we tell you what to do.'**
  String get accountDeleteMayBeBlocked;

  /// Instruction above the confirmation field. The word is always the English word DELETE, in capitals; do not translate it.
  ///
  /// In en, this message translates to:
  /// **'To confirm, type {word} into the field.'**
  String accountDeleteTypeInstruction(String word);

  /// Label of the confirmation field. The word is always DELETE.
  ///
  /// In en, this message translates to:
  /// **'Type {word}'**
  String accountDeleteFieldLabel(String word);

  /// The button that deletes the account. Enabled once the word was typed.
  ///
  /// In en, this message translates to:
  /// **'Delete my account for good'**
  String get accountDeleteConfirm;

  /// The delete button after a failed attempt.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get accountDeleteRetry;

  /// Screen-reader label of the progress indicator while the deletion request runs.
  ///
  /// In en, this message translates to:
  /// **'Deleting account'**
  String get accountDeleteInProgress;

  /// Error on the account-deletion screen.
  ///
  /// In en, this message translates to:
  /// **'The account could not be deleted. Nothing was changed. Please try again.'**
  String get accountDeleteFailed;

  /// Error on the account-deletion screen without a connection.
  ///
  /// In en, this message translates to:
  /// **'You are offline. The account can only be deleted with a connection. Nothing was changed.'**
  String get accountDeleteFailedOffline;

  /// Title when the server refuses the account deletion.
  ///
  /// In en, this message translates to:
  /// **'This account cannot be deleted here'**
  String get accountDeleteBlockedTitle;

  /// Why the deletion was refused: a child account.
  ///
  /// In en, this message translates to:
  /// **'This is a child account. It belongs to a parent\'s account, and only they can have it deleted. Ask them, or write to us.'**
  String get accountDeleteBlockedKid;

  /// Why the deletion was refused: the account has dependent child accounts.
  ///
  /// In en, this message translates to:
  /// **'Child accounts are linked to your account and would lose their access. Write to us and we sort that out with you first.'**
  String get accountDeleteBlockedDependents;

  /// Why the deletion was refused: an active membership. Keep the domain as it is.
  ///
  /// In en, this message translates to:
  /// **'You have an active membership. End it first on bognerchess.com or write to us; after that the account can be deleted.'**
  String get accountDeleteBlockedMembership;

  /// Why the deletion was refused: unpaid invoices.
  ///
  /// In en, this message translates to:
  /// **'There are open invoices on your account. Once they are settled, the account can be deleted. Write to us if you have questions.'**
  String get accountDeleteBlockedInvoices;

  /// Why the deletion was refused: a reason this version of the app does not know.
  ///
  /// In en, this message translates to:
  /// **'Something on your account has to be sorted out before it can be deleted. Write to us and we take care of it.'**
  String get accountDeleteBlockedOther;

  /// Reassurance under the reason for a refused deletion.
  ///
  /// In en, this message translates to:
  /// **'Nothing was deleted.'**
  String get accountDeleteBlockedNothingDeleted;

  /// Button that opens an e-mail to the support address.
  ///
  /// In en, this message translates to:
  /// **'Write to support'**
  String get accountDeleteContactSupport;

  /// Subject of the e-mail to support about a refused account deletion.
  ///
  /// In en, this message translates to:
  /// **'Delete my Bogner Chess account'**
  String get accountDeleteSupportSubject;

  /// Title of the final confirmation after an account deletion.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted'**
  String get accountDeletedTitle;

  /// Message of the final confirmation after an account deletion.
  ///
  /// In en, this message translates to:
  /// **'Your games, analyses and personal data are being removed, and everything the app stored on this device is gone. Thank you for playing with us.'**
  String get accountDeletedMessage;

  /// Button of the final confirmation after an account deletion; leads to the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get accountDeletedDone;

  /// Headline of the sheet that explains notifications, shown after the first analysis request and before the iOS permission prompt.
  ///
  /// In en, this message translates to:
  /// **'Know when your analysis is ready'**
  String get pushExplainerTitle;

  /// Body of the notification explainer sheet. Says what notifications are used for and what they are not used for.
  ///
  /// In en, this message translates to:
  /// **'An analysis takes a few minutes. We\'ll let you know when your analysis is ready, so you don\'t have to wait here. No advertising, no reminders.'**
  String get pushExplainerBody;

  /// Primary button of the notification explainer sheet. Leads to the iOS permission prompt.
  ///
  /// In en, this message translates to:
  /// **'Notify me'**
  String get pushExplainerAllow;

  /// Secondary button of the notification explainer sheet. Closes it without showing the iOS permission prompt.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get pushExplainerNotNow;

  /// Hint in the settings when the user has denied notifications in iOS.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for Bogner Chess. You can turn them on in the Settings app.'**
  String get pushSettingsDeniedHint;

  /// Button that opens the page of this app in the iOS Settings app.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get pushSettingsOpenSettings;
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
