// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/chess/board_theme_preference.dart';
import 'package:bogner_chess/core/chess/chess_models.dart';
import 'package:bogner_chess/core/storage/preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<ProviderContainer> start() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(boardThemeProvider, (_, _) {});
    // The stored value arrives a moment after the first read.
    await pumpEventQueue();
    return container;
  }

  test('starts with the default theme', () async {
    final container = await start();
    expect(container.read(boardThemeProvider), const BoardTheme());
  });

  test('a choice applies at once and survives a restart', () async {
    final container = await start();
    final notifier = container.read(boardThemeProvider.notifier);

    await notifier.select(pieceSet: BoardPieceSet.merida);
    expect(
      container.read(boardThemeProvider),
      const BoardTheme(pieceSet: BoardPieceSet.merida),
    );
    await notifier.select(colors: BoardColors.blue);

    final preferences = SharedPreferencesAsync();
    expect(await preferences.getString(kBoardPieceSetKey), 'merida');
    expect(await preferences.getString(kBoardColorsKey), 'blue');

    final next = await start();
    expect(
      next.read(boardThemeProvider),
      const BoardTheme(
        pieceSet: BoardPieceSet.merida,
        colors: BoardColors.blue,
      ),
    );
  });

  test('a stored name this build does not know is the default', () async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString(kBoardPieceSetKey, 'staunty');
    await preferences.setString(kBoardColorsKey, 'green');

    final container = await start();
    expect(
      container.read(boardThemeProvider),
      const BoardTheme(colors: BoardColors.green),
    );
  });

  test('works without preferences, only without persistence', () async {
    final container = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWith(
          (ref) => throw StateError('no preferences on this platform'),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(boardThemeProvider, (_, _) {});
    await pumpEventQueue();

    await container
        .read(boardThemeProvider.notifier)
        .select(colors: BoardColors.ic);
    expect(
      container.read(boardThemeProvider),
      const BoardTheme(colors: BoardColors.ic),
    );
  });

  test('every colour scheme has a swatch', () {
    for (final colors in BoardColors.values) {
      final swatch = boardSquareColorsOf(colors);
      expect(swatch.light, isNot(swatch.dark), reason: colors.name);
    }
  });
}
