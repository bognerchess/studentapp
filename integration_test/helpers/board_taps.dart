// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/chess/board_geometry.dart';
import 'package:bogner_chess/core/chess/board_view.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Touching squares of a [BoardView] on a device, by name.
///
/// The coordinates come from the board's rectangle and `squareRect`, not from
/// the semantics tree: `find.bySemanticsIdentifier` needs the semantics tree
/// to be switched on, and switching it on gives every frame work that the
/// app only does when VoiceOver is running. A test that measures frames must
/// not pay for its own instrument. (The widget tests in
/// `test/helpers/board_tester.dart` go through the semantics tree on
/// purpose, so the two drivers check each other.)
///
/// There must be exactly one [BoardView] on screen.
extension BoardTaps on WidgetTester {
  /// The square the board covers, in screen coordinates.
  Rect get boardRect {
    final rect = getRect(find.byType(BoardView));
    expect(
      rect.width,
      moreOrLessEquals(rect.height, epsilon: 0.5),
      reason: 'the board is not square; squareRect would be wrong',
    );
    return rect;
  }

  /// The side at the bottom of the screen.
  Side get boardOrientation =>
      widget<BoardView>(find.byType(BoardView)).orientation;

  /// Where a finger has to land to hit the middle of square [name] ("e4").
  Offset squareCentre(String name, Rect board, Side orientation) =>
      board.topLeft +
      squareRect(Square.fromName(name), orientation, board.width).center;

  /// The points a move given as UCI is entered with: the two squares, plus
  /// the piece in the promotion picker when the UCI carries one ("e7e8n").
  ///
  /// Computed before the move is played, so that a test can take the time of
  /// the taps alone and not of finding them.
  List<Offset> moveTaps(String uci, Rect board, Side orientation) {
    final taps = [
      squareCentre(uci.substring(0, 2), board, orientation),
      squareCentre(uci.substring(2, 4), board, orientation),
    ];
    if (uci.length > 4) {
      final role = Role.fromChar(uci[4])!;
      final choices = promotionChoices(
        NormalMove.fromUci(uci.substring(0, 4)),
        orientation,
      );
      final square = choices.keys.firstWhere((s) => choices[s] == role);
      taps.add(squareCentre(square.name, board, orientation));
    }
    return taps;
  }

  /// Touches each point in turn, one frame per touch, and then renders
  /// [extraFrames] more.
  ///
  /// It does not `pumpAndSettle`: a player's next finger does not wait for
  /// the piece to finish sliding, and a test that waited would measure the
  /// length of the animation instead of its cost. The fixed handful of extra
  /// frames is there so that the first frames of the board animation and of
  /// the move list scrolling into place are rendered, and their cost is
  /// counted, while their duration still is not.
  Future<void> tapPoints(List<Offset> points, {int extraFrames = 0}) async {
    for (final point in points) {
      await tapAt(point);
      await pump();
    }
    for (var frame = 0; frame < extraFrames; frame++) {
      await pump();
    }
  }
}
