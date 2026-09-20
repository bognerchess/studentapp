// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// A development entry point that starts the real app (`main.dart`, nothing
/// overridden) and then plays the new-game flow with synthetic touches, for
/// an end-to-end check against the mock server in a simulator without a tool
/// that can tap. Nothing in the app imports this file.
///
///     dart run tool/mock_server/main.dart --port 5299 --ai-consent
///     flutter build ios --simulator --debug \
///       --dart-define-from-file=config/fake.json \
///       -t lib/features/new_game/dev/flow_demo.dart
///     echo board > "$(xcrun simctl get_app_container <udid> \
///       com.bognerchess.mobile data)/tmp/flow_demo.txt"
///     xcrun simctl launch <udid> com.bognerchess.mobile -AppleLanguages "(de)"
///     curl localhost:5299/__state
///
/// The scenario is read from `tmp/flow_demo.txt` in the app's data container,
/// or from `FLOW_DEMO` in the environment. (`SIMCTL_CHILD_FLOW_DEMO` does not
/// reach `Platform.environment` on this simulator runtime, which is why the
/// file exists; `entry_demo.dart` has the same fallback.) A second line of the
/// file, or `FLOW_DEMO_PAUSE`, is the pause in seconds.
///
/// Scenarios (`FLOW_DEMO`):
///
/// * `board` (default): New game → Enter moves → a scholar's mate → Done →
///   "I played White", an opponent → Save & analyse.
/// * `board-save-only`: the same with "Save only".
/// * `import`: the import screen with a PGN → Continue → Save & analyse.
/// * `idle`: only start the app (to watch the queue pick up what waits).
///
/// The pause is the number of seconds the script rests on the entry screen
/// and on the details screen, for screenshots (default 4).
library;

import 'dart:async';
import 'dart:io' as io;

import 'package:bogner_chess/main.dart' as app;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

const _scholarsMate = [
  'e2e4', 'e7e5', 'f1c4', 'b8c6', 'd1h5', 'g8f6', 'h5f7', //
];

const _pgn = '''
[Event "Winterthur Open"]
[Date "2026.09.12"]
[White "Fake User"]
[Black "Jonas Keller"]
[Result "1-0"]
[WhiteElo "1650"]
[BlackElo "1712"]
[TimeControl "5400+30"]

1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 1-0
''';

Future<void> main() async {
  app.main();
  final settings = _settings();
  final scenario = settings.scenario;
  final pause = settings.pause;
  _say('scenario $scenario');
  await _wait(3000);

  switch (scenario) {
    case 'board' || 'board-save-only':
      await _tapText(const ['New game', 'Neue Partie']);
      await _wait(800);
      await _tap('new-game-entry');
      await _wait(1500);
      for (final move in _scholarsMate) {
        await _tap('board-square-${move.substring(0, 2)}');
        await _tap('board-square-${move.substring(2, 4)}');
      }
      _say('moves entered');
      await _wait(pause * 1000);
      await _tap('entry-done');
      await _wait(1500);
      await _tapText(const [
        'White',
        'Weiß',
        'Weiss',
      ], within: 'metadata-color');
      await _wait(300);
      await _type('metadata-opponent-name', 'Jonas Keller');
      await _wait(300);
      await _type('metadata-opponent-rating', '1712');
      _say('details filled');
      await _wait(pause * 1000);
      await _tap(
        scenario == 'board' ? 'metadata-save' : 'metadata-save-secondary',
      );
      _say('saved');
    case 'import':
      await _tapText(const ['New game', 'Neue Partie']);
      await _wait(800);
      await _tap('new-game-import');
      await _wait(1500);
      await _type('import-field', _pgn);
      await _wait(1500);
      _say('pgn entered');
      await _wait(pause * 1000);
      await _tap('import-continue');
      await _wait(1500);
      _say('details shown');
      await _wait(pause * 1000);
      await _tap('metadata-save');
      _say('saved');
  }
}

/// The scenario and the pause, from `tmp/flow_demo.txt` in the app's data
/// container (see the header of this file) or from the environment.
({String scenario, int pause}) _settings() {
  var scenario = io.Platform.environment['FLOW_DEMO'];
  var pause = int.tryParse(io.Platform.environment['FLOW_DEMO_PAUSE'] ?? '');
  final file = io.File('${io.Directory.systemTemp.path}/flow_demo.txt');
  if (file.existsSync()) {
    final lines = file.readAsLinesSync();
    if (lines.isNotEmpty && lines.first.trim().isNotEmpty) {
      scenario = lines.first.trim();
    }
    if (lines.length > 1) pause = int.tryParse(lines[1].trim()) ?? pause;
  }
  return (scenario: scenario ?? 'board', pause: pause ?? 4);
}

void _say(String message) => debugPrint('flow_demo: $message');

Future<void> _wait(int milliseconds) =>
    Future<void>.delayed(Duration(milliseconds: milliseconds));

/// The first element that carries [id] as its key (`ValueKey<String>`) or as
/// its semantics identifier.
Element? _find(String id, {Element? root}) {
  Element? found;
  void visit(Element element) {
    if (found != null) return;
    final widget = element.widget;
    final matches =
        widget.key == ValueKey<String>(id) ||
        (widget is Semantics && widget.properties.identifier == id);
    if (matches && element.renderObject is RenderBox) {
      found = element;
      return;
    }
    element.visitChildren(visit);
  }

  (root ?? WidgetsBinding.instance.rootElement!).visitChildren(visit);
  return found;
}

/// The last (topmost route's) `Text` showing one of [texts].
Element? _findText(List<String> texts, {Element? root}) {
  Element? found;
  void visit(Element element) {
    final widget = element.widget;
    if (widget is Text && texts.contains(widget.data)) found = element;
    element.visitChildren(visit);
  }

  (root ?? WidgetsBinding.instance.rootElement!).visitChildren(visit);
  return found;
}

Future<void> _tap(String id) async {
  final element = _find(id);
  if (element == null) return _say('nothing called $id');
  await _tapElement(element);
}

Future<void> _tapText(List<String> texts, {String? within}) async {
  final root = within == null ? null : _find(within);
  final element = _findText(texts, root: root);
  if (element == null) return _say('no text ${texts.first}');
  await _tapElement(element);
}

int _pointer = 1 << 20;

/// A finger tap on the middle of [element].
Future<void> _tapElement(Element element) async {
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

/// Types [text] into the text field called [id], the way the keyboard does
/// (so that `onChanged` fires).
Future<void> _type(String id, String text) async {
  final field = _find(id);
  if (field == null) return _say('no field called $id');
  EditableTextState? editable;
  void visit(Element element) {
    if (editable != null) return;
    if (element is StatefulElement && element.state is EditableTextState) {
      editable = element.state as EditableTextState;
      return;
    }
    element.visitChildren(visit);
  }

  field.visitChildren(visit);
  final state = editable;
  if (state == null) return _say('$id is not a text field');
  state.userUpdateTextEditingValue(
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
    SelectionChangedCause.keyboard,
  );
  await _wait(200);
}
