// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/chess/board_view.dart';
import 'package:bogner_chess/core/l10n/board_labels.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/features/entry/data/screen_wakelock.dart';
import 'package:bogner_chess/features/entry/domain/entry_controller.dart';
import 'package:bogner_chess/features/entry/domain/entry_game.dart';
import 'package:bogner_chess/features/entry/domain/entry_result.dart';
import 'package:bogner_chess/features/entry/domain/entry_settings.dart';
import 'package:bogner_chess/features/entry/ui/entry_identified.dart';
import 'package:bogner_chess/features/entry/ui/entry_move_list.dart';
import 'package:bogner_chess/features/entry/ui/entry_overwrite_sheet.dart';
import 'package:bogner_chess/router.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Move entry: play the game on the board, tap-tap or drag.
///
/// Built for speed (a 40-move game in under three minutes) and for cheap
/// recovery from a slip: a large Undo within thumb reach, a move list that
/// jumps on tap, a confirmation before anything but the last move is lost,
/// and an autosave after every ply.
class EntryScreen extends ConsumerStatefulWidget {
  const EntryScreen({super.key, this.draftId, this.onDone});

  /// The draft to resume (query parameter `draftId` of `/new/entry`). Null
  /// starts a new game.
  final String? draftId;

  /// Where the flow goes after Done. When null, the screen confirms "Saved as
  /// draft" and pops with the [EntryResult].
  final ValueChanged<EntryResult>? onDone;

  @override
  ConsumerState<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends ConsumerState<EntryScreen>
    with WidgetsBindingObserver {
  final GlobalKey<PopupMenuButtonState<_MenuAction>> _menuKey = GlobalKey();
  late final ScreenWakelock _wakelock;

  EntryController get _controller =>
      ref.read(entryControllerProvider(widget.draftId).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wakelock = ref.read(screenWakelockProvider);
    unawaited(_wakelock.enable());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_wakelock.disable());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // iOS may kill a paused app without another word: write the draft now.
    if (state != AppLifecycleState.resumed) unawaited(_controller.flush());
  }

  Future<void> _onMove(NormalMove move) async {
    final controller = _controller;
    switch (controller.play(move)) {
      case EntryPlayOutcome.played:
        unawaited(HapticFeedback.selectionClick());
      case EntryPlayOutcome.rejected:
        break;
      case EntryPlayOutcome.needsConfirmation:
        final game = ref.read(entryControllerProvider(widget.draftId)).game;
        final replace = await showEntryOverwriteSheet(
          context,
          removedMoves: game.tailLength,
          newSan: game.position.makeSan(move).$2,
          oldSan: game.moves[game.cursor].san,
        );
        if (replace && mounted) {
          controller.play(move, overwrite: true);
          unawaited(HapticFeedback.selectionClick());
        }
    }
  }

  Future<void> _done() async {
    final result = await _controller.finish();
    if (!mounted) return;
    final onDone = widget.onDone;
    if (onDone != null) {
      onDone(result);
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.entrySavedAsDraft)));
    if (context.canPop()) {
      context.pop(result);
    } else {
      context.go(AppRoutes.newGame);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(entryControllerProvider(widget.draftId));
    final autoQueen = ref.watch(entryAutoQueenProvider);
    final game = state.game;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.entryTitle),
        actions: [
          EntryIdentified(
            identifier: EntryIds.done,
            label: l10n.entryDone,
            onTap: game.plyCount == 0 || state.loading ? null : _done,
            child: TextButton(
              onPressed: game.plyCount == 0 || state.loading ? null : _done,
              child: Text(l10n.entryDone),
            ),
          ),
          EntryIdentified(
            identifier: EntryIds.menu,
            label: l10n.entryMoreOptions,
            onTap: () => _menuKey.currentState?.showButtonMenu(),
            child: PopupMenuButton<_MenuAction>(
              key: _menuKey,
              tooltip: l10n.entryMoreOptions,
              onSelected: (action) {
                switch (action) {
                  case _MenuAction.autoQueen:
                    unawaited(
                      ref
                          .read(entryAutoQueenProvider.notifier)
                          .set(enabled: !autoQueen),
                    );
                }
              },
              itemBuilder: (context) => [
                CheckedPopupMenuItem(
                  value: _MenuAction.autoQueen,
                  checked: autoQueen,
                  child: Semantics(
                    identifier: EntryIds.autoQueen,
                    child: Text(l10n.entryAutoQueen),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: state.loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        // The board is as wide as the screen and only gives
                        // way when a small screen with large type needs the
                        // height for the controls.
                        Flexible(
                          child: Center(
                            heightFactor: 1,
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: BoardView(
                                position: game.position,
                                orientation: state.orientation,
                                interaction: BoardInteraction.entry,
                                lastMove: game.lastMove?.highlight,
                                autoQueen: autoQueen,
                                animate: state.animate,
                                semanticsLabels: boardLabelsOf(l10n),
                                onMove: _onMove,
                              ),
                            ),
                          ),
                        ),
                        _StatusLine(game: game),
                        EntryMoveList(game: game, onSelect: _controller.goTo),
                      ],
                    ),
                  ),
                  _Controls(
                    canUndo: game.canUndo,
                    canRedo: game.canRedo,
                    onUndo: _controller.undo,
                    onRedo: _controller.redo,
                    onFlip: _controller.flip,
                  ),
                ],
              ),
      ),
    );
  }
}

enum _MenuAction { autoQueen }

/// "Move 12 · Black to move", or how the game ended.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.game});

  final EntryGame game;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final position = game.position;
    final String text;
    if (position.isCheckmate) {
      text = l10n.entryStatusCheckmate(position.turn.opposite.name);
    } else if (position.isStalemate) {
      text = l10n.entryStatusStalemate;
    } else if (position.isInsufficientMaterial) {
      text = l10n.entryStatusInsufficientMaterial;
    } else {
      text = l10n.entryStatusToMove(position.fullmoves, position.turn.name);
    }
    return Semantics(
      identifier: EntryIds.status,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          0,
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// The bottom row, within reach of the thumb: flip, a large Undo, forward.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onFlip,
  });

  static const double _height = 64;

  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sideButton = IconButton.styleFrom(
      fixedSize: const Size(_height, _height),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          EntryIdentified(
            identifier: EntryIds.flip,
            label: l10n.entryFlipBoard,
            onTap: onFlip,
            child: IconButton.outlined(
              style: sideButton,
              tooltip: l10n.entryFlipBoard,
              onPressed: onFlip,
              icon: const Icon(Icons.swap_vert),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: EntryIdentified(
              identifier: EntryIds.undo,
              label: l10n.entryUndo,
              onTap: canUndo ? onUndo : null,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(_height),
                  textStyle: theme.textTheme.titleMedium,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
                onPressed: canUndo ? onUndo : null,
                icon: const Icon(Icons.undo, size: 28),
                label: Text(l10n.entryUndo),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          EntryIdentified(
            identifier: EntryIds.redo,
            label: l10n.entryRedo,
            onTap: canRedo ? onRedo : null,
            child: IconButton.filledTonal(
              style: sideButton,
              tooltip: l10n.entryRedo,
              onPressed: canRedo ? onRedo : null,
              icon: const Icon(Icons.redo),
            ),
          ),
        ],
      ),
    );
  }
}
