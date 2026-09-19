// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/app.dart';
import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/core/storage/preferences.dart';
import 'package:bogner_chess/features/entry/data/screen_wakelock.dart';
import 'package:bogner_chess/features/entry/domain/entry_controller.dart';
import 'package:bogner_chess/features/entry/domain/entry_draft_store.dart';
import 'package:bogner_chess/features/entry/ui/entry_screen.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/board_tester.dart';
import '../../helpers/pump_app.dart';
import 'fakes.dart';

/// Just enough of `SharedPreferencesAsync` for the entry settings.
class FakePreferences implements SharedPreferencesAsync {
  FakePreferences([Map<String, Object>? values]) : values = values ?? {};

  final Map<String, Object> values;

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// What a test can look at after [pumpEntry].
class EntryHarness {
  EntryHarness(this.store, this.wakelock, this.preferences, this.haptics);

  final RecordingDraftStore store;
  final FakeWakelock wakelock;
  final FakePreferences preferences;

  /// The `HapticFeedback.vibrate` arguments the platform received.
  final List<String?> haptics;
}

/// The timestamp every autosave carries in these tests.
final DateTime kEntryTestNow = DateTime.utc(2026, 9, 19, 12);

/// Pumps the whole app and opens the entry screen through the router, the way
/// a user gets there. [draftId] resumes a draft from [store].
Future<EntryHarness> pumpEntry(
  WidgetTester tester, {
  RecordingDraftStore? store,
  FakePreferences? preferences,
  String? draftId,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Size screen = kIphone17Pro,
}) async {
  final harness = EntryHarness(
    store ?? RecordingDraftStore(),
    FakeWakelock(),
    preferences ?? FakePreferences(),
    [],
  );

  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = screen * 3;
  tester.platformDispatcher.localesTestValue = [locale];
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        harness.haptics.add(call.arguments as String?);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        envProvider.overrideWithValue(testEnv()),
        appInfoProvider.overrideWith(
          (ref) async => const AppInfo(version: '1.2.3', buildNumber: '45'),
        ),
        entryDraftStoreProvider.overrideWithValue(harness.store),
        screenWakelockProvider.overrideWithValue(harness.wakelock),
        preferencesProvider.overrideWithValue(harness.preferences),
        entryClockProvider.overrideWithValue(() => kEntryTestNow),
      ],
      child: const BognerChessApp(),
    ),
  );
  await tester.pumpAndSettle();

  routerOf(tester).go(
    draftId == null
        ? AppRoutes.newGameEntry
        : AppRoutes.newGameEntryResume(draftId),
  );
  await tester.pumpAndSettle();
  expect(find.byType(EntryScreen), findsOneWidget);
  return harness;
}

/// Lets the autosave debounce run out.
Future<void> settleAutosave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 300));

extension EntryTester on WidgetTester {
  Finder entryControl(String identifier) =>
      find.bySemanticsIdentifier(identifier);

  /// Taps a control; a move of the list is scrolled into view first, as a
  /// user would.
  Future<void> tapEntryControl(String identifier) async {
    if (identifier.startsWith('entry-move-')) {
      await ensureVisible(entryControl(identifier));
      await pumpAndSettle();
    }
    await tap(entryControl(identifier));
    await pumpAndSettle();
  }

  /// Two taps with one frame each. `playMove` settles, and settling also lets
  /// the autosave debounce run out; this does not.
  Future<void> playMoveWithoutSettling(String uci) async {
    for (final square in [uci.substring(0, 2), uci.substring(2, 4)]) {
      await tapAt(getCenter(boardSquare(square)));
      await pump();
    }
  }

  /// The movetext of the game on screen, read from the controller.
  String get entryPgn => entryState.game.toPgnMoves();

  EntryState get entryState {
    final screen = widget<EntryScreen>(find.byType(EntryScreen));
    return containerOf(this).read(entryControllerProvider(screen.draftId));
  }
}
