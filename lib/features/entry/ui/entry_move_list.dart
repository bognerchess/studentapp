// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/features/entry/domain/entry_game.dart';
import 'package:material_ui/material_ui.dart';

/// Semantics identifier of the move after [ply] half-moves (`entry-move-1` is
/// White's first move). `entry-move-0` is the jump to the starting position.
String entryMoveIdentifier(int ply) => 'entry-move-$ply';

/// One horizontally scrolling line of move pairs, "1. e4 e5 2. Nf3 Nc6".
///
/// The move under the cursor is highlighted and kept in view. Tapping a move
/// reports its ply through [onSelect]; the leading item reports 0.
class EntryMoveList extends StatefulWidget {
  const EntryMoveList({super.key, required this.game, required this.onSelect});

  final EntryGame game;
  final ValueChanged<int> onSelect;

  @override
  State<EntryMoveList> createState() => _EntryMoveListState();
}

class _EntryMoveListState extends State<EntryMoveList> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _currentKey = GlobalKey(debugLabel: 'entry current move');

  @override
  void initState() {
    super.initState();
    _revealCurrentSoon(animate: false);
  }

  @override
  void didUpdateWidget(EntryMoveList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.cursor != widget.game.cursor ||
        oldWidget.game.plyCount != widget.game.plyCount) {
      _revealCurrentSoon(animate: true);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _revealCurrentSoon({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final duration = animate
          ? const Duration(milliseconds: 150)
          : Duration.zero;
      final current = _currentKey.currentContext;
      if (current == null) {
        // The cursor is on the starting position.
        if (animate) {
          _scroll.animateTo(0, duration: duration, curve: Curves.easeOut);
        } else {
          _scroll.jumpTo(0);
        }
        return;
      }
      Scrollable.ensureVisible(
        current,
        alignment: 0.5,
        duration: duration,
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final game = widget.game;

    if (game.plyCount == 0) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _MoveChip.minHeight),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              l10n.entryMoveListEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          _MoveChip(
            identifier: entryMoveIdentifier(0),
            semanticsLabel: l10n.entryMoveListStart,
            selected: game.cursor == 0,
            onTap: () => widget.onSelect(0),
            child: const Icon(Icons.first_page, size: 20),
          ),
          for (final (index, move) in game.moves.indexed) ...[
            if (index.isEven)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: ExcludeSemantics(
                  child: Text(
                    '${index ~/ 2 + 1}.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            _MoveChip(
              key: index + 1 == game.cursor ? _currentKey : null,
              identifier: entryMoveIdentifier(index + 1),
              semanticsLabel: l10n.entryMoveSemantics(
                index ~/ 2 + 1,
                index.isEven ? 'white' : 'black',
                move.san,
              ),
              selected: index + 1 == game.cursor,
              // Moves after the cursor are still part of the game; they are
              // only dimmed to show where the board is.
              dimmed: index + 1 > game.cursor,
              onTap: () => widget.onSelect(index + 1),
              child: Text(move.san),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoveChip extends StatelessWidget {
  const _MoveChip({
    super.key,
    required this.identifier,
    required this.semanticsLabel,
    required this.selected,
    required this.onTap,
    required this.child,
    this.dimmed = false,
  });

  /// Apple's minimum tap target.
  static const double minHeight = 44;

  final String identifier;
  final String semanticsLabel;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected
        ? scheme.onPrimaryContainer
        : dimmed
        ? scheme.onSurfaceVariant
        : scheme.onSurface;
    return Semantics(
      container: true,
      excludeSemantics: true,
      identifier: identifier,
      label: semanticsLabel,
      button: true,
      selected: selected,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight, minWidth: 40),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? scheme.primaryContainer : null,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: IconTheme.merge(
                  data: IconThemeData(color: foreground),
                  child: DefaultTextStyle.merge(
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
