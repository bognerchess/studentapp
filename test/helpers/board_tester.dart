// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/chess/board_geometry.dart';
import 'package:bogner_chess/core/chess/board_view.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Driving a `BoardView` in widget and integration tests.
///
/// Squares are found through the semantics overlay, so a test names a square
/// ("e4") and never computes a coordinate. There must be exactly one
/// `BoardView` on screen.
extension BoardTester on WidgetTester {
  /// The semantics node widget of a square, for `getRect`, `getCenter` and
  /// `expect(..., findsOneWidget)`.
  Finder boardSquare(String name) =>
      find.bySemanticsIdentifier(boardSquareIdentifier(Square.fromName(name)));

  /// What a screen reader says on the square, for example "e4, white pawn".
  String boardSquareLabel(String name) => _node(name).evaluate().single.label;

  /// Touches the middle of a square like a finger, then lets the board settle.
  Future<void> tapSquare(String name) async {
    await tapAt(getCenter(boardSquare(name)));
    await pumpAndSettle();
  }

  /// Performs the accessibility tap action of a square (VoiceOver's double
  /// tap), then lets the board settle.
  Future<void> activateSquare(String name) async {
    semantics.tap(_node(name));
    await pumpAndSettle();
  }

  /// Taps the two squares of a move given as UCI, such as "e2e4". A promotion
  /// suffix ("e7e8n") also taps that piece in the promotion picker, which
  /// works for a board seen from either side.
  Future<void> playMove(String uci) async {
    await tapSquare(uci.substring(0, 2));
    await tapSquare(uci.substring(2, 4));
    if (uci.length > 4) {
      final role = Role.fromChar(uci[4])!;
      final move = NormalMove.fromUci(uci.substring(0, 4));
      final orientation = widget<BoardView>(find.byType(BoardView)).orientation;
      final choices = promotionChoices(move, orientation);
      final square = choices.keys.firstWhere((s) => choices[s] == role);
      await tapSquare(square.name);
    }
  }

  /// Drags from the middle of one square to the middle of another.
  Future<void> dragPiece(String from, String to) async {
    final start = getCenter(boardSquare(from));
    final gesture = await startGesture(start);
    final end = getCenter(boardSquare(to));
    // Several steps: the board only starts a drag once the pointer has moved.
    for (var step = 1; step <= 4; step++) {
      await gesture.moveTo(Offset.lerp(start, end, step / 4)!);
      await pump();
    }
    await gesture.up();
    await pumpAndSettle();
  }

  FinderBase<SemanticsNode> _node(String name) {
    final identifier = boardSquareIdentifier(Square.fromName(name));
    return find.semantics.byPredicate(
      (node) => node.identifier == identifier,
      describeMatch: (_) => 'semantics node $identifier',
    );
  }
}
