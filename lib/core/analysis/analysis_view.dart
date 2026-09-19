// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// Pure view-model helpers over an [AnalysisDocument] for the review screen:
/// eval graph, glyphs, arrows, comment lookup, navigation between moments and
/// the summary table. No Flutter; `analysis_board_mapping.dart` turns the
/// results into `BoardView` types.
library;

import 'package:dartchess/dartchess.dart';

import 'analysis_document.dart';

/// The annotation symbol of a move.
enum AnalysisGlyph {
  /// A move the coach praised (a positive moment).
  good('!'),
  inaccuracy('?!'),
  mistake('?'),
  blunder('??');

  const AnalysisGlyph(this.symbol);

  /// One or two characters, as in chess notation.
  final String symbol;
}

/// What an [AnalysisArrow] points out.
enum AnalysisArrowKind {
  /// The engine's best move. Belongs on the node's `fenBefore`.
  best,

  /// The move that was played. Belongs on the node's `fenBefore`.
  played,

  /// What the opponent threatens after the played move. Belongs on the
  /// node's `fenAfter`.
  threat,
}

/// The two positions of a node an arrow can belong to.
enum ArrowBoard {
  /// The node's `fenBefore`: `played` and `best` arrows.
  before,

  /// The node's `fenAfter`: `threat` arrows.
  after,
}

/// An arrow in analysis terms, independent of how the board draws it.
final class AnalysisArrow {
  const AnalysisArrow({
    required this.from,
    required this.to,
    required this.kind,
  });

  final Square from;
  final Square to;
  final AnalysisArrowKind kind;

  /// The position this arrow is meant for.
  ArrowBoard get board =>
      kind == AnalysisArrowKind.threat ? ArrowBoard.after : ArrowBoard.before;

  @override
  bool operator ==(Object other) =>
      other is AnalysisArrow &&
      other.from == from &&
      other.to == to &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(from, to, kind);

  @override
  String toString() => 'AnalysisArrow(${from.name}${to.name}, ${kind.name})';
}

/// The arrows of [node] itself (as opposed to those of a comment): the
/// engine's best move and the move that was played. Both belong on the node's
/// `fenBefore`. The best arrow comes first; there is none when the played move
/// was the engine's choice.
List<AnalysisArrow> arrowsFor(
  AnalysisNode node, {
  bool showBest = true,
  bool showPlayed = true,
}) {
  final best = node.best?.move;
  return [
    if (showBest && best != null)
      AnalysisArrow(from: best.from, to: best.to, kind: AnalysisArrowKind.best),
    if (showPlayed)
      AnalysisArrow(
        from: node.move.from,
        to: node.move.to,
        kind: AnalysisArrowKind.played,
      ),
  ];
}

/// The arrows of [comment], in document order, without those of a role this
/// build does not know (the contract does not say which position they belong
/// on). With [board] only the arrows for that position: the review screen
/// passes [ArrowBoard.before] while it shows "what you should have played"
/// and [ArrowBoard.after] while it shows the position after the move.
List<AnalysisArrow> arrowsForComment(
  CoachComment comment, {
  ArrowBoard? board,
}) {
  final result = <AnalysisArrow>[];
  for (final arrow in comment.arrows) {
    final kind = switch (arrow.role) {
      ArrowRole.best => AnalysisArrowKind.best,
      ArrowRole.played => AnalysisArrowKind.played,
      ArrowRole.threat => AnalysisArrowKind.threat,
      ArrowRole.unknown => null,
    };
    if (kind == null) continue;
    final mapped = AnalysisArrow(from: arrow.from, to: arrow.to, kind: kind);
    if (board == null || mapped.board == board) result.add(mapped);
  }
  return result;
}

/// Lookups and aggregates the review UI needs.
extension AnalysisDocumentView on AnalysisDocument {
  /// Values for the eval graph, from White's point of view, clamped to
  /// `[-cap, cap]` centipawns; a mate is `cap` for the side that mates.
  ///
  /// The list has `plyCount + 1` entries and is indexed by ply: entry 0 is
  /// the start position, entry `n` the position after ply `n`.
  List<int> evalSeries({int cap = EvalScore.defaultCap}) => [
    if (nodes.isNotEmpty)
      nodes.first.evalBefore.whitePovCentipawnsClamped(cap: cap),
    for (final node in nodes)
      node.evalAfter.whitePovCentipawnsClamped(cap: cap),
  ];

  /// The glyph for [node]: `??`, `?` and `?!` by classification, `!` for a
  /// move with a positive-moment comment, otherwise none. An unknown
  /// classification has no glyph.
  AnalysisGlyph? glyphFor(AnalysisNode node) => switch (node.classification) {
    MoveClassification.blunder => AnalysisGlyph.blunder,
    MoveClassification.mistake => AnalysisGlyph.mistake,
    MoveClassification.inaccuracy => AnalysisGlyph.inaccuracy,
    MoveClassification.book ||
    MoveClassification.best ||
    MoveClassification.good ||
    MoveClassification.unknown =>
      node.isCritical && commentsOf(node).any((comment) => comment.isPositive)
          ? AnalysisGlyph.good
          : null,
  };

  /// The comments of [node], in the order of its `commentIds`.
  List<CoachComment> commentsOf(AnalysisNode node) => [
    for (final id in node.commentIds) ?commentsById[id],
  ];

  /// The comments on [ply]; empty when there are none or [ply] is out of
  /// range.
  List<CoachComment> commentsAt(int ply) {
    final node = nodeAt(ply);
    return node == null ? const [] : commentsOf(node);
  }

  /// The plies the server picked as moments (critical and positive),
  /// ascending.
  List<int> get criticalPlies => [
    for (final node in nodes)
      if (node.isCritical) node.ply,
  ];

  /// The first moment after [ply], or null. `nextCritical(0)` is the first
  /// moment of the game.
  int? nextCritical(int ply) {
    for (final node in nodes) {
      if (node.isCritical && node.ply > ply) return node.ply;
    }
    return null;
  }

  /// The last moment before [ply], or null.
  int? previousCritical(int ply) {
    for (final node in nodes.reversed) {
      if (node.isCritical && node.ply < ply) return node.ply;
    }
    return null;
  }

  /// How many moves of each classification [side] played. Every
  /// [MoveClassification] is a key, in enum order, so a table can iterate the
  /// map; [MoveClassification.unknown] counts values this build does not
  /// know and is normally left out of the table.
  Map<MoveClassification, int> classificationCounts(Side side) {
    final counts = {for (final value in MoveClassification.values) value: 0};
    for (final node in nodes) {
      if (node.side == side) {
        counts[node.classification] = counts[node.classification]! + 1;
      }
    }
    return counts;
  }

  /// The accuracy of [side] in percent, if the document carried it.
  double? accuracyOf(Side side) =>
      side == Side.white ? accuracyWhite : accuracyBlack;
}
