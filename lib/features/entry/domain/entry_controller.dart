// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/features/entry/domain/entry_draft_store.dart';
import 'package:bogner_chess/features/entry/domain/entry_game.dart';
import 'package:bogner_chess/features/entry/domain/entry_result.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the entry screen shows.
class EntryState {
  const EntryState({
    required this.draftId,
    required this.game,
    this.orientation = Side.white,
    this.loading = false,
    this.animate = true,
  });

  final String draftId;
  final EntryGame game;

  /// The side at the bottom of the board.
  final Side orientation;

  /// True while a draft is being read. The board is not shown yet.
  final bool loading;

  /// Whether the board should slide the pieces into this state: true for a
  /// single ply, false for a jump.
  final bool animate;

  EntryState copyWith({
    EntryGame? game,
    Side? orientation,
    bool? loading,
    bool? animate,
  }) => EntryState(
    draftId: draftId,
    game: game ?? this.game,
    orientation: orientation ?? this.orientation,
    loading: loading ?? this.loading,
    animate: animate ?? this.animate,
  );
}

/// What became of a move the board reported.
enum EntryPlayOutcome {
  /// The move is on the board (appended, or it was the move already there).
  played,

  /// The move differs from the line and would remove its tail. Nothing has
  /// changed; ask the user and call `play(move, overwrite: true)`.
  needsConfirmation,

  /// Not legal in the current position, or the draft is still loading.
  rejected,
}

/// The clock of the entry feature, so that tests get stable timestamps.
final entryClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// State of one visit to the entry screen. The argument is the id of the
/// draft to resume, or null for a new game. Auto-disposed: leaving the screen
/// flushes the draft and forgets the state.
final entryControllerProvider = NotifierProvider.autoDispose
    .family<EntryController, EntryState, String?>(EntryController.new);

const _log = Log('entry');

class EntryController extends Notifier<EntryState> {
  EntryController(this.resumeDraftId);

  /// The draft to resume; null starts a new game under a fresh id.
  final String? resumeDraftId;

  late EntryAutosaver _autosaver;
  bool _everSaved = false;

  @override
  EntryState build() {
    _everSaved = false;
    _autosaver = EntryAutosaver(
      ref.watch(entryDraftStoreProvider),
      onError: (error, stackTrace) =>
          _log.warning('autosave failed', error: error, stackTrace: stackTrace),
    );
    ref.onDispose(() => unawaited(_autosaver.dispose()));

    final resume = resumeDraftId;
    if (resume == null) {
      return EntryState(draftId: newEntryDraftId(), game: EntryGame.initial());
    }
    unawaited(_resume(resume));
    return EntryState(
      draftId: resume,
      game: EntryGame.initial(),
      loading: true,
    );
  }

  Future<void> _resume(String draftId) async {
    EntryDraftSnapshot? snapshot;
    try {
      snapshot = await ref.read(entryDraftStoreProvider).load(draftId);
    } on Object catch (error, stackTrace) {
      _log.warning('draft load failed', error: error, stackTrace: stackTrace);
    }
    if (!ref.mounted) return;
    if (snapshot == null) {
      // Unknown id: start an empty game under it rather than show an error.
      state = state.copyWith(loading: false);
      return;
    }
    state = state.copyWith(
      // Lenient: a damaged draft still gives back its legal prefix.
      game: EntryGame.fromPgnMoves(
        snapshot.pgnMoves,
        cursorPly: snapshot.cursorPly,
        lenient: true,
      ),
      orientation: snapshot.orientation,
      loading: false,
      animate: false,
    );
  }

  /// A move from the board. Never throws for a bad move.
  EntryPlayOutcome play(NormalMove move, {bool overwrite = false}) {
    final game = state.game;
    if (state.loading || !game.isLegal(move)) return EntryPlayOutcome.rejected;
    if (!overwrite && game.wouldOverwriteTail(move)) {
      return EntryPlayOutcome.needsConfirmation;
    }
    _update(game.play(move, overwrite: overwrite), animate: true);
    return EntryPlayOutcome.played;
  }

  /// See the undo rule on [EntryGame].
  void undo() => _update(state.game.undo(), animate: true);

  void redo() => _update(state.game.redo(), animate: true);

  /// Jumps to the position after [ply] half-moves.
  void goTo(int ply) {
    final distance = (ply - state.game.cursor).abs();
    _update(state.game.goTo(ply), animate: distance <= 1);
  }

  void flip() {
    if (state.loading) return;
    state = state.copyWith(orientation: state.orientation.opposite);
    _scheduleSave();
  }

  /// Writes what is pending now: on app pause and before handing over.
  Future<void> flush() => _autosaver.flush();

  /// Flushes the draft and describes the entered game.
  Future<EntryResult> finish() async {
    await flush();
    final game = state.game;
    return EntryResult(
      draftId: state.draftId,
      pgnMoves: game.toPgnMoves(),
      plyCount: game.plyCount,
      suggestedResult: game.suggestedResult,
      orientation: state.orientation,
    );
  }

  void _update(EntryGame game, {required bool animate}) {
    if (state.loading || identical(game, state.game)) return;
    state = state.copyWith(game: game, animate: animate);
    _scheduleSave();
  }

  void _scheduleSave() {
    final game = state.game;
    // A game nobody has touched is not a draft yet. Once there is one, an
    // emptied line is saved too, so that the store never holds stale moves.
    if (game.plyCount == 0 && resumeDraftId == null && !_everSaved) return;
    _everSaved = true;
    _autosaver.schedule(
      EntryDraftSnapshot(
        id: state.draftId,
        pgnMoves: game.toPgnMoves(),
        cursorPly: game.cursor,
        orientation: state.orientation,
        updatedAt: ref.read(entryClockProvider)(),
      ),
    );
  }
}
