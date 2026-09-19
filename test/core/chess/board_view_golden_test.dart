// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

@Tags(['golden'])
library;

import 'package:bogner_chess/core/chess/board_view.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The one board golden. It runs on macOS only (`flutter test --tags golden`);
/// rasterisation differs between platforms.
///
/// Kept robust on purpose: a fixed size, no coordinates, and the only text is
/// the glyph, which the test font draws as two boxes.
void main() {
  testWidgets('board with two arrows and a ?? glyph', (tester) async {
    const theme = BoardTheme();
    // Piece images are decoded by the engine, which needs real async.
    await tester.runAsync(() => precacheBoardTheme(theme, devicePixelRatio: 1));

    // After 1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. Ng5 Bc5.
    final position = Chess.fromSetup(
      Setup.parseFen(
        'r1bqk2r/pppp1ppp/2n2n2/2b1p1N1/2B1P3/8/PPPP1PPP/RNBQK2R w KQkq - 6 5',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            child: BoardView(
              position: position,
              size: 320,
              theme: theme,
              showCoordinates: false,
              lastMove: const NormalMove(from: Square.f8, to: Square.c5),
              arrows: const [
                BoardArrow(from: Square.g5, to: Square.f7),
                BoardArrow(
                  from: Square.c4,
                  to: Square.f7,
                  style: BoardArrowStyle.alternative,
                ),
              ],
              glyphs: const {Square.c5: BoardGlyph.blunder},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(BoardView),
      matchesGoldenFile('goldens/board_arrows_glyph.png'),
    );
  });
}
