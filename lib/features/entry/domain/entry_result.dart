// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:dartchess/dartchess.dart';

/// What the entry screen hands over when the user taps Done: everything the
/// metadata step needs to go on.
class EntryResult {
  const EntryResult({
    required this.draftId,
    required this.pgnMoves,
    required this.plyCount,
    required this.suggestedResult,
    required this.orientation,
  });

  /// The draft the moves were autosaved under (already flushed to the store).
  final String draftId;

  /// Movetext of the whole line, `1. e4 e5 2. Nf3`, no headers, no result.
  final String pgnMoves;

  final int plyCount;

  /// `1-0`, `0-1` or `1/2-1/2` when the final position decides the game
  /// (checkmate, stalemate, insufficient material); null otherwise. A
  /// suggestion to preselect the result chip, not a fact.
  final String? suggestedResult;

  /// The side at the bottom of the board when the user finished; a hint for
  /// "which colour did you play".
  final Side orientation;

  @override
  bool operator ==(Object other) =>
      other is EntryResult &&
      other.draftId == draftId &&
      other.pgnMoves == pgnMoves &&
      other.plyCount == plyCount &&
      other.suggestedResult == suggestedResult &&
      other.orientation == orientation;

  @override
  int get hashCode =>
      Object.hash(draftId, pgnMoves, plyCount, suggestedResult, orientation);

  @override
  String toString() =>
      'EntryResult($draftId, $plyCount plies, result $suggestedResult)';
}
