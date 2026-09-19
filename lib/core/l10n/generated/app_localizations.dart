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
