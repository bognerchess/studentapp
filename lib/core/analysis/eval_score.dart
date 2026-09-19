// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:dartchess/dartchess.dart' show Side;

/// An engine evaluation from **White's** point of view: either centipawns or
/// a distance to mate, never both.
///
/// `mate > 0` means White mates, `mate < 0` means Black mates. `mate == 0`
/// only occurs after a checkmating move; the sign cannot say who won then, so
/// the parser records the winner in [mateWinner].
final class EvalScore {
  /// A centipawn score.
  const EvalScore.cp(int this.cp) : mate = null, _deliveredBy = null;

  /// A mate score. [deliveredBy] is only needed (and only used) when
  /// [mate] is 0.
  const EvalScore.mate(int this.mate, {this._deliveredBy}) : cp = null;

  /// The value the eval graph clamps to by default: ten pawns.
  static const int defaultCap = 1000;

  /// Centipawns, or null for a mate score.
  final int? cp;

  /// Moves to mate, or null for a centipawn score.
  final int? mate;

  final Side? _deliveredBy;

  bool get isMate => mate != null;

  /// True for `{"mate": 0}`: the move before this eval delivered checkmate.
  bool get isCheckmate => mate == 0;

  /// The side that mates, or null for a centipawn score (and for a mate 0
  /// whose winner is not known).
  Side? get mateWinner => switch (mate) {
    null => null,
    0 => _deliveredBy,
    final m => m > 0 ? Side.white : Side.black,
  };

  /// Pawns from White's point of view, or null for a mate score.
  double? get pawns => cp == null ? null : cp! / 100.0;

  /// The value for the eval graph: centipawns from White's point of view,
  /// clamped to `[-cap, cap]`. A mate score is `cap` for the side that mates.
  /// A mate 0 without a known winner is 0.
  int whitePovCentipawnsClamped({int cap = defaultCap}) {
    assert(cap > 0, 'cap must be positive');
    final cp = this.cp;
    if (cp != null) return cp.clamp(-cap, cap);
    return switch (mateWinner) {
      Side.white => cap,
      Side.black => -cap,
      null => 0,
    };
  }

  /// Short text for a badge, from White's point of view: `+0.4`, `-1.2`,
  /// `0.0`, `M3` (White mates in 3), `-M3` (Black mates in 3), `#` (checkmate
  /// on the board). The decimal separator is a dot; a localised UI formats
  /// [pawns] itself.
  String get displayText {
    final mate = this.mate;
    if (mate != null) {
      if (mate == 0) return '#';
      return mate > 0 ? 'M$mate' : '-M${-mate}';
    }
    final cp = this.cp!;
    // Round half away from zero on tenths of a pawn, without going through
    // floating point: 35 -> 0.4, -35 -> -0.4, 4 -> 0.0.
    final tenths = (cp.abs() + 5) ~/ 10;
    if (tenths == 0) return '0.0';
    final sign = cp < 0 ? '-' : '+';
    return '$sign${tenths ~/ 10}.${tenths % 10}';
  }

  @override
  bool operator ==(Object other) =>
      other is EvalScore &&
      other.cp == cp &&
      other.mate == mate &&
      other.mateWinner == mateWinner;

  @override
  int get hashCode => Object.hash(cp, mate, mateWinner);

  @override
  String toString() => 'EvalScore($displayText)';
}
