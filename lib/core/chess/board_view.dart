// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'board_geometry.dart';
import 'board_semantics.dart';
import 'chess_models.dart';
import 'chessground_mapping.dart';

export 'board_semantics.dart' show BoardSemanticsLabels, boardSquareIdentifier;
export 'chess_models.dart';
export 'chessground_mapping.dart'
    show kBoardAnimationDuration, precacheBoardTheme;

/// The chess board of this app: chessground behind this app's own vocabulary.
///
/// The widget is controlled. It shows [position] and reports a move the user
/// made through [onMove]; it does not play the move. The owner plays it
/// (`position.play(move)`) and rebuilds with the new position and
/// `lastMove: move`. If the owner does nothing, the piece goes back.
///
/// It needs an `Overlay` above it (a dragged piece is drawn there) and a
/// `Directionality` (glyphs are text); any `MaterialApp` provides both.
///
/// `lib/core/chess` is the only place that imports chessground, so that a
/// change of its API, or of the board package itself, stays in one directory.
class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.position,
    this.size,
    this.orientation = Side.white,
    this.interaction = BoardInteraction.readOnly,
    this.lastMove,
    this.arrows = const [],
    this.glyphs = const {},
    this.theme = const BoardTheme(),
    this.autoQueen = false,
    this.showCoordinates = true,
    this.animate = true,
    this.animationDuration = kBoardAnimationDuration,
    this.semanticsLabels = BoardSemanticsLabels.english,
    this.onMove,
  });

  /// The position to show. The side to move, the legal moves and the check
  /// highlight all come from it.
  final Position position;

  /// Edge length in logical pixels. When null the board takes the shorter
  /// side of the space it is given, so it needs a bounded parent.
  final double? size;

  /// The side at the bottom of the screen.
  final Side orientation;

  final BoardInteraction interaction;

  /// Highlighted on the board. Pass the move that led to [position].
  final Move? lastMove;

  final List<BoardArrow> arrows;

  /// Badges such as "??", keyed by the square they sit on (usually the
  /// destination of the move they judge).
  final Map<Square, BoardGlyph> glyphs;

  final BoardTheme theme;

  /// Promote to a queen without asking. When false, the board shows its
  /// promotion picker and [onMove] fires once the user has chosen.
  final bool autoQueen;

  /// Files and ranks along the edge of the board.
  final bool showCoordinates;

  /// Whether the change to a new [position] slides the pieces. Set it to
  /// false for the rebuild that jumps to an unrelated position.
  final bool animate;

  final Duration animationDuration;

  /// What a screen reader says. Inject the localised instance; the default is
  /// English.
  final BoardSemanticsLabels semanticsLabels;

  /// A legal move made by tapping two squares, by dragging, or through the
  /// accessibility tree. A promotion arrives with its role set. Castling
  /// arrives the way the user made it, as king to g1 or as king onto the
  /// rook; `Position.play` and `makeSan` accept both, and
  /// `Position.normalizeMove` gives one canonical form.
  final ValueChanged<NormalMove>? onMove;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  // Synthetic pointers for semantic taps. Device pointers count up from
  // zero, so this range does not meet them.
  static int _nextSyntheticPointer = 1 << 24;

  final GlobalKey _boardKey = GlobalKey(debugLabel: 'BoardView.board');
  late final ChessboardController _controller;
  NormalMove? _pendingPromotion;

  GameData get _gameData => gameDataOf(
    widget.position,
    interaction: widget.interaction,
    lastMove: widget.lastMove,
  );

  @override
  void initState() {
    super.initState();
    _controller = ChessboardController(game: _gameData);
  }

  @override
  void didUpdateWidget(BoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final positionChanged = oldWidget.position.fen != widget.position.fen;
    if (positionChanged ||
        oldWidget.lastMove != widget.lastMove ||
        oldWidget.interaction != widget.interaction) {
      if (positionChanged || widget.interaction == BoardInteraction.readOnly) {
        // A picker that belongs to the old position must not survive it.
        _controller.pendingPromotion = null;
      }
      _controller.updatePosition(_gameData, animate: widget.animate);
      _pendingPromotion = _controller.pendingPromotion;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onMove(Move move, {bool? viaDragAndDrop}) {
    if (move is! NormalMove || !widget.position.isLegal(move)) return;
    widget.onMove?.call(move);
  }

  /// chessground opens and closes its promotion picker without telling
  /// anyone, and the semantics overlay has to relabel its squares while the
  /// picker is open. Every way in and out of the picker is a pointer event,
  /// so look at the controller once the event has been handled.
  void _syncPendingPromotionSoon(PointerEvent _) {
    scheduleMicrotask(() {
      if (!mounted) return;
      final pending = _controller.pendingPromotion;
      if (pending != _pendingPromotion) {
        setState(() => _pendingPromotion = pending);
      }
    });
  }

  /// The tap action of a square's semantics node (VoiceOver's double tap).
  ///
  /// It is turned into a real tap on the middle of the square, so that it
  /// takes exactly the path of a finger: selection, legal-move dots, the
  /// promotion picker and [BoardView.onMove] all behave the same.
  void _activateSquare(Square square, double size) {
    final box = _boardKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final position = box.localToGlobal(
      squareRect(square, widget.orientation, size).center,
    );
    final viewId = View.of(context).viewId;
    final pointer = _nextSyntheticPointer++;
    GestureBinding.instance
      ..handlePointerEvent(
        PointerDownEvent(viewId: viewId, pointer: pointer, position: position),
      )
      ..handlePointerEvent(
        PointerUpEvent(viewId: viewId, pointer: pointer, position: position),
      );
  }

  Widget _buildBoard(double size) {
    final interactive = widget.interaction == BoardInteraction.entry;
    return SizedBox.square(
      key: _boardKey,
      dimension: size,
      child: Stack(
        children: [
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _syncPendingPromotionSoon,
            onPointerUp: _syncPendingPromotionSoon,
            onPointerCancel: _syncPendingPromotionSoon,
            // The board is a canvas plus a few unlabelled gesture detectors;
            // the overlay below is what assistive technology should see.
            child: ExcludeSemantics(
              child: Chessboard(
                size: size,
                controller: _controller,
                orientation: widget.orientation,
                settings: boardSettingsOf(
                  widget.theme,
                  showCoordinates: widget.showCoordinates,
                  autoQueen: widget.autoQueen,
                  animationDuration: widget.animationDuration,
                ),
                shapes: shapesOf(widget.arrows),
                annotations: annotationsOf(widget.glyphs),
                onMove: _onMove,
              ),
            ),
          ),
          BoardSemanticsOverlay(
            size: size,
            orientation: widget.orientation,
            board: widget.position.board,
            labels: widget.semanticsLabels,
            pendingPromotion: _pendingPromotion,
            onActivate: interactive
                ? (square) => _activateSquare(square, size)
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    if (size != null) return _buildBoard(size);
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        assert(side.isFinite, 'BoardView needs a size or a bounded parent.');
        return _buildBoard(side);
      },
    );
  }
}
