// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';

import '../domain/eval_verdict.dart';

/// Words for what the analysis document says in codes. The primary UI never
/// shows raw centipawns.
extension ReviewWords on AppLocalizations {
  /// "White is slightly better", "Mate in 3 for Black", ...
  String evalWords(EvalScore eval) {
    final verdict = EvalVerdict.of(eval);
    final side = verdict.side?.name ?? 'none';
    return switch (verdict.level) {
      EvalLevel.equal => reviewEvalEqual,
      EvalLevel.slight => reviewEvalSlight(side),
      EvalLevel.clear => reviewEvalClear(side),
      EvalLevel.winning => reviewEvalWinning(side),
      EvalLevel.mate => reviewEvalMate(verdict.mateIn ?? 0, side),
      EvalLevel.checkmate => reviewEvalCheckmate(side),
    };
  }

  /// "Blunder", "Best move", ... A move the coach praised is a "Strong move"
  /// whatever the engine called it.
  String classificationWords(
    MoveClassification classification, {
    bool praised = false,
  }) => reviewClassification(praised ? 'strong' : classification.name);

  /// The chip label of a theme, or null for a theme this build has no word
  /// for (it is then not shown at all, rather than in English snake case).
  String? themeWords(String theme) {
    final key = _themeKeys[theme];
    return key == null ? null : reviewTheme(key);
  }

  /// `1–0`, `0–1`, `½–½`, or null for an unfinished game.
  String? resultWords(String? pgnResult, GameResult fallback) =>
      switch (pgnResult) {
        '1-0' => '1–0',
        '0-1' => '0–1',
        '1/2-1/2' => '½–½',
        _ => switch (fallback) {
          GameResult.whiteWins => '1–0',
          GameResult.blackWins => '0–1',
          GameResult.draw => '½–½',
          GameResult.unfinished => null,
        },
      };
}

const Map<String, String> _themeKeys = {
  'opening': 'opening',
  'development': 'development',
  'central_break': 'centralBreak',
  'king_safety': 'kingSafety',
  'tactics': 'tactics',
  'hanging_piece': 'hangingPiece',
  'calculation': 'calculation',
  'piece_activity': 'pieceActivity',
  'pawn_structure': 'pawnStructure',
  'endgame': 'endgame',
  'material_conversion': 'materialConversion',
};
