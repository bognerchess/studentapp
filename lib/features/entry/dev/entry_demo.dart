// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// A development entry point that opens the move-entry screen and drives it
/// with synthetic touches, for looking at it in a simulator without a tool
/// that can tap. Nothing in the app imports this file.
///
///     flutter build ios --simulator --debug \
///       --dart-define-from-file=config/fake.json \
///       -t lib/features/entry/dev/entry_demo.dart
///     SIMCTL_CHILD_ENTRY_DEMO=sheet xcrun simctl launch <udid> \
///       com.bognerchess.mobile -AppleLanguages "(de)"
///
/// (or write the scenario name to `tmp/entry_demo.txt` in the app's data
/// container, see [_scenario]).
///
/// Scenarios (`ENTRY_DEMO`): `empty`, `moves` (default), `sheet`, `promotion`,
/// `long`, `done`.
library;

import 'dart:async';
import 'dart:io' as io;

import 'package:bogner_chess/app.dart';
import 'package:bogner_chess/features/entry/domain/entry_draft_store.dart';
import 'package:bogner_chess/router.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _ruyLopez = [
  'e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', //
  'a7a6', 'b5a4', 'g8f6', 'e1g1', 'f8e7',
];

const _toSeventh = '1. a4 b5 2. axb5 Nf6 3. b6 Ng8 4. bxa7 Nf6';

const _longGame =
    '1. e4 d5 2. e5 f5 3. exf6 Nxf6 4. Nf3 Nc6 5. Bb5 Bg4 6. O-O Qd7 '
    '7. d4 O-O-O 8. c3 g6 9. g3 g5 10. Be3 a5 11. h4 gxh4 12. Kg2 h3+ '
    '13. Kh2 e5 14. c4 dxc4 15. Nc3 Nh5 16. b3 e4 17. a4 cxb3 18. d5 b6 '
    '19. dxc6 h6 20. Qc1 b2 21. Kh1 bxc1=Q 22. Ba6+ Kb8 23. cxd7 h2 '
    '24. Bxb6 c6 25. Ng1 hxg1=B 26. f4 Qxa1 27. f5 c5 28. f6 c4 29. f7 e3 '
    '30. Bb7 Qxf1 31. Bxa5 e2 32. Ba6 e1=B 33. Bxc4 Re8 34. dxe8=N Nf6 '
    '35. Bd3 Nh7 36. Nf6 Be2 37. g4 h5 38. Nb5 hxg4 39. Nd5 g3 40. Bb6 g2#';

EntryDraftSnapshot _draft(String id, String pgn) => EntryDraftSnapshot(
  id: id,
  pgnMoves: pgn,
  cursorPly: 999,
  orientation: Side.white,
  updatedAt: DateTime.now(),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final scenario = _scenario();

  final store = InMemoryEntryDraftStore();
  await store.save(_draft('promotion', _toSeventh));
  await store.save(_draft('long', _longGame));

  final container = ProviderContainer(
    overrides: [entryDraftStoreProvider.overrideWithValue(store)],
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BognerChessApp(),
    ),
  );

  await _wait(1500);
  final router = container.read(routerProvider);
  router.go(switch (scenario) {
    'promotion' => AppRoutes.newGameEntryResume('promotion'),
    'long' => AppRoutes.newGameEntryResume('long'),
    _ => AppRoutes.newGameEntry,
  });
  await _wait(1500);

  switch (scenario) {
    case 'moves':
      await _play(_ruyLopez);
    case 'sheet':
      await _play(_ruyLopez);
      await _tap('entry-move-4');
      await _play(['f1c4']);
    case 'promotion':
      await _play(['a7b8']);
    case 'done':
      await _play(_ruyLopez.take(4));
      await _tap('entry-done');
  }
}

/// From the environment (`SIMCTL_CHILD_ENTRY_DEMO=...`), or from the file
/// `tmp/entry_demo.txt` in the app's data container
/// (`xcrun simctl get_app_container <udid> com.bognerchess.mobile data`).
String _scenario() {
  final fromEnvironment = io.Platform.environment['ENTRY_DEMO'];
  if (fromEnvironment != null) return fromEnvironment;
  final file = io.File('${io.Directory.systemTemp.path}/entry_demo.txt');
  return file.existsSync() ? file.readAsStringSync().trim() : 'moves';
}

Future<void> _wait(int milliseconds) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

Future<void> _play(Iterable<String> moves) async {
  for (final move in moves) {
    await _tap('board-square-${move.substring(0, 2)}');
    await _tap('board-square-${move.substring(2, 4)}');
  }
}

int _pointer = 1 << 20;

/// A finger tap on the middle of the widget with that semantics identifier.
Future<void> _tap(String identifier) async {
  Element? found;
  void visit(Element element) {
    final widget = element.widget;
    if (found == null &&
        widget is Semantics &&
        widget.properties.identifier == identifier &&
        element.renderObject is RenderBox) {
      found = element;
    }
    if (found == null) element.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement!.visitChildren(visit);
  final element = found;
  if (element == null) {
    debugPrint('entry_demo: nothing with identifier $identifier');
    return;
  }
  // A move of the list may have scrolled out of view (large type, long
  // game); a finger would scroll first, and a tap off screen hits nothing.
  if (Scrollable.maybeOf(element) != null) {
    await Scrollable.ensureVisible(element, alignment: 0.5);
    await _wait(100);
  }
  final box = element.renderObject! as RenderBox;
  final position = box.localToGlobal(box.size.center(Offset.zero));
  final pointer = _pointer++;
  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(pointer: pointer, position: position),
  );
  await _wait(40);
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(pointer: pointer, position: position),
  );
  await _wait(260);
}
