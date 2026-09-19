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
