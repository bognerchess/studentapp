// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:math' as math;

import 'package:bogner_chess/core/analysis/eval_score.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/foundation.dart';

/// How big an advantage is, in the words a club player uses.
enum EvalLevel {
  /// Nobody is better.
  equal,

  /// "Slightly better".
  slight,

  /// "Clearly better".
  clear,

  /// "Winning".
  winning,

  /// A forced mate; [EvalVerdict.mateIn] says in how many moves.
  mate,

  /// Checkmate is on the board.
  checkmate,
}

/// An [EvalScore] as a verdict in words: the primary UI never shows raw
/// centipawns. The l10n mapping lives in `ui/review_l10n.dart`.
@immutable
class EvalVerdict {
  const EvalVerdict(this.level, {this.side, this.mateIn});

  /// Centipawn limits (White's or Black's advantage, absolute). Up to and
  /// including [equalUpTo] is equal, and so on. The engine gives White about
  /// 0.3 in the start position; a player calls that equal.
  static const int equalUpTo = 40;
  static const int slightUpTo = 120;
  static const int clearUpTo = 300;

  factory EvalVerdict.of(EvalScore eval) {
    if (eval.isCheckmate) {
      return EvalVerdict(EvalLevel.checkmate, side: eval.mateWinner);
    }
    final mate = eval.mate;
    if (mate != null) {
      return EvalVerdict(
        EvalLevel.mate,
        side: eval.mateWinner,
        mateIn: mate.abs(),
      );
    }
    final cp = eval.cp!;
    final abs = cp.abs();
    if (abs <= equalUpTo) return const EvalVerdict(EvalLevel.equal);
    final side = cp > 0 ? Side.white : Side.black;
    if (abs <= slightUpTo) return EvalVerdict(EvalLevel.slight, side: side);
    if (abs <= clearUpTo) return EvalVerdict(EvalLevel.clear, side: side);
    return EvalVerdict(EvalLevel.winning, side: side);
  }

  final EvalLevel level;

  /// Who is better. Null for [EvalLevel.equal] (and for a checkmate whose
  /// winner the document did not say).
  final Side? side;

  /// Moves to mate, for [EvalLevel.mate].
  final int? mateIn;

  @override
  bool operator ==(Object other) =>
      other is EvalVerdict &&
      other.level == level &&
      other.side == side &&
      other.mateIn == mateIn;

  @override
  int get hashCode => Object.hash(level, side, mateIn);

  @override
  String toString() => 'EvalVerdict(${level.name}, ${side?.name}, $mateIn)';
}

/// Maps clamped centipawns (White's point of view) to `-1 .. 1` for the eval
/// graph, along the usual winning-chances curve: a pawn early on is visible,
/// and +6 and +9 look alike, which is how they feel at the board.
double graphValueOf(int centipawns) =>
    2 / (1 + math.exp(-0.00368208 * centipawns)) - 1;
