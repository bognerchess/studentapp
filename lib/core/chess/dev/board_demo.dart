// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// A stand-alone harness for looking at `BoardView` on a device. It is not
/// part of the app: nothing imports it, and it has its own `main`.
///
///     flutter build ios --simulator --debug -t lib/core/chess/dev/board_demo.dart
library;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../board_thumbnail.dart';
import '../board_view.dart';

void main() => runApp(const BoardDemoApp());

class BoardDemoApp extends StatelessWidget {
  const BoardDemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BoardView demo',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFF2F5D50)),
    home: const BoardDemoScreen(),
  );
}

class BoardDemoScreen extends StatefulWidget {
  const BoardDemoScreen({super.key});

  @override
  State<BoardDemoScreen> createState() => _BoardDemoScreenState();
}

class _BoardDemoScreenState extends State<BoardDemoScreen> {
  // After 1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. Ng5 Bc5, a position with
  // something to point at.
  static const _startFen =
      'r1bqk2r/pppp1ppp/2n2n2/2b1p1N1/2B1P3/8/PPPP1PPP/RNBQK2R w KQkq - 6 5';

  Position _position = Chess.fromSetup(Setup.parseFen(_startFen));
  NormalMove? _lastMove = const NormalMove(from: Square.f8, to: Square.c5);
  Side _orientation = Side.white;
  int _theme = 0;
  bool _decorated = true;

  void _onMove(NormalMove move) {
    setState(() {
      _position = _position.play(move);
      _lastMove = move;
      _decorated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = BoardTheme.all[_theme % BoardTheme.all.length];
    return Scaffold(
      appBar: AppBar(
        title: Text('BoardView: ${theme.pieceSet.name}, ${theme.colors.name}'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: BoardView(
                position: _position,
                orientation: _orientation,
                interaction: BoardInteraction.entry,
                lastMove: _lastMove,
                theme: theme,
                arrows: _decorated
                    ? const [
                        BoardArrow(from: Square.g5, to: Square.f7),
                        BoardArrow(
                          from: Square.c4,
                          to: Square.f7,
                          style: BoardArrowStyle.alternative,
                        ),
                      ]
                    : const [],
                glyphs: _decorated
                    ? const {Square.c5: BoardGlyph.blunder}
                    : const {},
                onMove: _onMove,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: () =>
                        setState(() => _orientation = _orientation.opposite),
                    child: const Text('Flip'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => setState(() => _theme++),
                    child: const Text('Next theme'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => setState(() {
                      _position = Chess.fromSetup(Setup.parseFen(_startFen));
                      _lastMove = const NormalMove(
                        from: Square.f8,
                        to: Square.c5,
                      );
                      _decorated = true;
                    }),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final pieceSet in BoardPieceSet.values)
                  BoardThumbnail(
                    fen: _position.fen,
                    size: 96,
                    orientation: _orientation,
                    lastMove: _lastMove,
                    theme: theme.copyWith(pieceSet: pieceSet),
                    semanticLabel: 'Thumbnail, ${pieceSet.name}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
