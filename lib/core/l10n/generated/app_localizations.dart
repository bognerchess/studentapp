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
