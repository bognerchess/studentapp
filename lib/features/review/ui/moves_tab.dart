// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/ui/theme.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import 'review_ids.dart';

/// One move of the move list, already in display terms.
@immutable
class MoveListEntry {
  const MoveListEntry({
    required this.ply,
    required this.moveNumber,
    required this.isWhite,
    required this.san,
    required this.semanticLabel,
    this.glyph,
    this.glyphColor,
    this.hasComment = false,
  });

  final int ply;
  final int moveNumber;
  final bool isWhite;
  final String san;

  /// "??", "?!", "!" ..., in [glyphColor].
  final String? glyph;
  final Color? glyphColor;

  /// A small marker: the coach has something to say here.
  final bool hasComment;

  final String semanticLabel;
}

/// The game in two columns with move numbers. The move on the board is
/// highlighted and kept in view; a tap jumps to a move.
class MovesTab extends StatefulWidget {
  const MovesTab({
    super.key,
    required this.moves,
    required this.currentPly,
    required this.onSelect,
  });

  final List<MoveListEntry> moves;
  final int currentPly;
  final ValueChanged<int> onSelect;

  @override
  State<MovesTab> createState() => _MovesTabState();
}

class _MovesTabState extends State<MovesTab> {
  final GlobalKey _currentKey = GlobalKey(debugLabel: 'current move');
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _revealCurrentSoon(jump: true);
  }

  @override
  void didUpdateWidget(MovesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPly != widget.currentPly) _revealCurrentSoon();
  }

  void _revealCurrentSoon({bool jump = false}) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _currentKey.currentContext;
      if (context == null) {
        // The start position: no move is current, show the first ones.
        if (_scroll.hasClients) _scroll.jumpTo(0);
        return;
      }
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: jump ? Duration.zero : const Duration(milliseconds: 150),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final moves = widget.moves;
    if (moves.isEmpty) return const SizedBox.shrink();

    // Rows of (white, black). A game that starts with Black to move has an
    // empty white cell in its first row.
    final rows = <(MoveListEntry?, MoveListEntry?)>[];
    for (var i = 0; i < moves.length;) {
      final move = moves[i];
      if (!move.isWhite) {
        rows.add((null, move));
        i += 1;
      } else {
        final reply = i + 1 < moves.length && !moves[i + 1].isWhite
            ? moves[i + 1]
            : null;
        rows.add((move, reply));
        i += reply == null ? 1 : 2;
      }
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          for (final (index, (white, black)) in rows.indexed)
            DecoratedBox(
              decoration: BoxDecoration(
                color: index.isOdd
                    ? scheme.surfaceContainerLow
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: AppSpacing.sm,
                      ),
                      child: Text(
                        '${(white ?? black)!.moveNumber}.',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: _cell(white)),
                  Expanded(child: _cell(black)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(MoveListEntry? move) {
    if (move == null) return const SizedBox.shrink();
    final current = move.ply == widget.currentPly;
    return _MoveCell(
      key: current ? _currentKey : null,
      move: move,
      current: current,
      onTap: () => widget.onSelect(move.ply),
    );
  }
}

class _MoveCell extends StatelessWidget {
  const _MoveCell({
    super.key,
    required this.move,
    required this.current,
    required this.onTap,
  });

  final MoveListEntry move;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = current ? scheme.onSecondaryContainer : scheme.onSurface;
    return ReviewIdentified(
      identifier: ReviewIds.move(move.ply),
      label: move.semanticLabel,
      selected: current,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: current ? scheme.secondaryContainer : null,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: move.san),
                      if (move.glyph != null)
                        TextSpan(
                          text: move.glyph,
                          style: TextStyle(
                            // The highlight is a light tint in both themes;
                            // the verdict colours stay readable on it.
                            color: move.glyphColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: foreground,
                    fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (move.hasComment) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.chat_bubble,
                  size: 13,
                  color: current ? foreground : scheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
