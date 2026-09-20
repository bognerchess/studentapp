// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// The open enums of the analysis document.
///
/// On the wire they are plain strings and a newer producer may send values
/// this build has never heard of. Every enum therefore has an `unknown`
/// member, and `fromWire` never fails.
library;

/// How good a played move was. `best` means "lost nothing", not "the engine's
/// first choice".
enum MoveClassification {
  book('book'),
  best('best'),
  good('good'),
  inaccuracy('inaccuracy'),
  mistake('mistake'),
  blunder('blunder'),

  /// A value this build does not know. Renders as no badge.
  unknown(null);

  const MoveClassification(this.wire);

  final String? wire;

  static MoveClassification fromWire(Object? value) =>
      _byWire(values, value, (e) => e.wire, unknown);
}

/// What an engine line shows.
enum VariationKind {
  /// What the player should have played. Starts at the node's `fenBefore`.
  bestLine('best_line'),

  /// The opponent's punishing reply. Starts at the node's `fenAfter`.
  refutation('refutation'),

  /// Another good option for the player. Starts at the node's `fenBefore`.
  alternative('alternative'),

  /// A kind this build does not know. Render it as a plain line from its
  /// `startFen`.
  unknown(null);

  const VariationKind(this.wire);

  final String? wire;

  static VariationKind fromWire(Object? value) =>
      _byWire(values, value, (e) => e.wire, unknown);
}

/// The kind of a coach comment.
enum CommentType {
  criticalMoment('critical_moment'),
  positiveMoment('positive_moment'),

  /// A type this build does not know. The parser skips such comments unless
  /// it is told to keep them.
  unknown(null);

  const CommentType(this.wire);

  final String? wire;

  static CommentType fromWire(Object? value) =>
      _byWire(values, value, (e) => e.wire, unknown);
}

/// Why a square is highlighted.
enum SquareRole {
  target('target'),
  weak('weak'),
  key('key'),

  /// Render in a neutral colour.
  unknown(null);

  const SquareRole(this.wire);

  final String? wire;

  static SquareRole fromWire(Object? value) =>
      _byWire(values, value, (e) => e.wire, unknown);
}

/// What a comment arrow means. `played` and `best` belong on the node's
/// `fenBefore`, `threat` on its `fenAfter`.
enum ArrowRole {
  played('played'),
  best('best'),
  threat('threat'),

  /// A role this build does not know. It is not drawn, because the contract
  /// does not say on which of the two positions it belongs.
  unknown(null);

  const ArrowRole(this.wire);

  final String? wire;

  static ArrowRole fromWire(Object? value) =>
      _byWire(values, value, (e) => e.wire, unknown);
}

/// How a coach text passed the server's verification gate.
enum VerificationStatus {
  passed('passed'),
  regenerated('regenerated'),

  /// A deterministic template text, not written by the language model.
  fallback('fallback'),

  /// Treat as [passed].
  unknown(null);

  const VerificationStatus(this.wire);

  final String? wire;

  static VerificationStatus fromWire(Object? value) =>
      _byWire(values, value, (e) => e.wire, unknown);
}

/// Whose moves are coached. Closed on the wire; anything else is read as
/// [both], which shows comments for either side.
enum AnalysisPerspective {
  white('white'),
  black('black'),

  /// A third-party game.
  both('both');

  const AnalysisPerspective(this.wire);

  final String wire;

  static AnalysisPerspective fromWire(Object? value) =>
      _byWire(values, value, (e) => e.wire, both);
}

/// The result of the game. Closed on the wire; anything else is read as
/// [unfinished].
enum GameResult {
  whiteWins('1-0'),
  blackWins('0-1'),
  draw('1/2-1/2'),
  unfinished('*');

  const GameResult(this.wire);

  final String wire;

  static GameResult fromWire(Object? value) =>
      _byWire(values, value, (e) => e.wire, unfinished);
}

T _byWire<T>(
  List<T> values,
  Object? value,
  String? Function(T) wireOf,
  T fallback,
) {
  if (value is! String) return fallback;
  for (final candidate in values) {
    if (wireOf(candidate) == value) return candidate;
  }
  return fallback;
}
