// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/storage/preferences.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chess_models.dart';
import 'chessground_mapping.dart' show colorSchemeOf, precacheBoardTheme;

/// Preferences keys of [boardThemeProvider]; the values are enum names.
const String kBoardPieceSetKey = 'board.pieceSet';
const String kBoardColorsKey = 'board.colors';

const _log = Log('board.theme');

/// The piece set and board colours the user picked in the settings, for every
/// board of the app: `BoardView(theme: ref.watch(boardThemeProvider), ...)`.
///
/// A device setting (not an account setting), kept in the preferences. The
/// value is the default theme until the stored one has been read, which takes
/// a moment after the first use; a preferences failure only costs
/// persistence. The images of a chosen piece set are warmed up here, so the
/// screens need no `precacheBoardTheme` call of their own.
final boardThemeProvider = NotifierProvider<BoardThemeNotifier, BoardTheme>(
  BoardThemeNotifier.new,
);

class BoardThemeNotifier extends Notifier<BoardTheme> {
  bool _changedByUser = false;

  @override
  BoardTheme build() {
    unawaited(_load());
    return const BoardTheme();
  }

  Future<void> _load() async {
    try {
      final preferences = ref.read(preferencesProvider);
      final pieceSet = await preferences.getString(kBoardPieceSetKey);
      final colors = await preferences.getString(kBoardColorsKey);
      final stored = BoardTheme(
        // A name this build does not know (a set that was removed) falls
        // back to the default.
        pieceSet:
            BoardPieceSet.values.asNameMap()[pieceSet] ??
            const BoardTheme().pieceSet,
        colors:
            BoardColors.values.asNameMap()[colors] ?? const BoardTheme().colors,
      );
      if (_changedByUser || !ref.mounted || stored == state) return;
      _precache(stored);
      state = stored;
    } on Object catch (error) {
      _log.warning('could not read the board theme: $error');
    }
  }

  Future<void> select({BoardPieceSet? pieceSet, BoardColors? colors}) async {
    final next = state.copyWith(pieceSet: pieceSet, colors: colors);
    if (next == state) return;
    _changedByUser = true;
    if (next.pieceSet != state.pieceSet) _precache(next);
    state = next;
    try {
      final preferences = ref.read(preferencesProvider);
      await preferences.setString(kBoardPieceSetKey, next.pieceSet.name);
      await preferences.setString(kBoardColorsKey, next.colors.name);
    } on Object catch (error) {
      _log.warning('could not store the board theme: $error');
    }
  }

  /// Not awaited: decoding needs the engine and never completes in a widget
  /// test, and a board that is ahead of the cache loads its images itself.
  void _precache(BoardTheme theme) {
    try {
      unawaited(precacheBoardTheme(theme).catchError((Object _) {}));
    } on Object catch (_) {
      // No binding yet (a provider test): nothing to warm up.
    }
  }
}

/// The two square colours of [colors], for a swatch in the theme picker.
({Color light, Color dark}) boardSquareColorsOf(BoardColors colors) {
  final scheme = colorSchemeOf(colors);
  return (light: scheme.lightSquare, dark: scheme.darkSquare);
}
