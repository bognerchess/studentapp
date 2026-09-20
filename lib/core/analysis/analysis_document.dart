// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// The analysis document (annotated move tree) as the app sees it.
///
/// Pure Dart: no Flutter, no JSON. Instances come from `AnalysisParser`, which
/// has replayed every move with dartchess, so every [Position], [NormalMove]
/// and [Square] in here is legal chess. All lists and maps are unmodifiable.
library;

import 'package:dartchess/dartchess.dart';

import 'analysis_enums.dart';
import 'eval_score.dart';

export 'analysis_enums.dart';
export 'eval_score.dart';

/// A parsed analysis document of a supported major version.
final class AnalysisDocument {
  AnalysisDocument({
    required this.schemaVersion,
    required this.schemaMinor,
    required this.analysisId,
    required this.generatedAt,
    required this.language,
    required this.perspective,
    required this.ratingBand,
    required this.engine,
    required this.coach,
    required this.result,
    required this.startFen,
    required this.startPosition,
    required this.accuracyWhite,
    required this.accuracyBlack,
    required List<AnalysisNode> nodes,
    required List<CoachComment> comments,
    required List<Lesson> lessons,
  }) : nodes = List.unmodifiable(nodes),
       comments = List.unmodifiable(comments),
       commentsById = Map.unmodifiable({
         for (final comment in comments) comment.id: comment,
       }),
       lessons = List.unmodifiable(lessons);

  /// Major version of the wire format.
  final int schemaVersion;

  /// Minor version of the wire format. Any value is acceptable.
  final int schemaMinor;

  /// The job uuid. Empty when the document did not carry one.
  final String analysisId;

  /// When the server produced the document (UTC), if it said so.
  final DateTime? generatedAt;

  /// Language of all coach texts (BCP 47 primary subtag, for example `en`).
  final String language;

  /// Whose moves are coached.
  final AnalysisPerspective perspective;

  /// The rating band the win percentages are calibrated for, as sent
  /// (`1000-1200`, `unknown`, …). Open enum, display only.
  final String ratingBand;

  final EngineInfo engine;
  final CoachInfo coach;
  final GameResult result;

  /// The FEN the game starts from, or null for the standard position.
  final String? startFen;

  /// The position before ply 1.
  final Position startPosition;

  /// Accuracy in percent (0 to 100), if the document carried it.
  final double? accuracyWhite;
  final double? accuracyBlack;

  /// One node per played ply, in order: `nodes[i].ply == i + 1`.
  final List<AnalysisNode> nodes;

  /// The coach comments this build can show, ordered by ply.
  final List<CoachComment> comments;

  /// [comments] by id.
  final Map<String, CoachComment> commentsById;

  /// The lessons of the summary. Normally three.
  final List<Lesson> lessons;

  int get plyCount => nodes.length;

  /// The node of [ply] (1-based), or null when out of range.
  AnalysisNode? nodeAt(int ply) =>
      ply >= 1 && ply <= nodes.length ? nodes[ply - 1] : null;

  /// The position after [ply] plies; `positionAt(0)` is [startPosition].
  /// Out-of-range values are clamped.
  Position positionAt(int ply) {
    if (ply <= 0 || nodes.isEmpty) return startPosition;
    return nodes[ply > nodes.length ? nodes.length - 1 : ply - 1].positionAfter;
  }

  @override
  String toString() =>
      'AnalysisDocument($analysisId, v$schemaVersion.$schemaMinor, '
      '$plyCount plies, ${comments.length} comments)';
}

/// Which engine produced the numbers.
final class EngineInfo {
  const EngineInfo({
    required this.name,
    required this.humanModel,
    this.pass1Nodes,
    this.pass2Nodes,
    this.pass2MultiPv,
  });

  /// For example `Stockfish 19`. Empty when missing.
  final String name;

  /// For example `maia2-rapid`, or `unavailable`. Open enum.
  final String humanModel;

  /// Node budget per position of the fast pass over the whole game.
  final int? pass1Nodes;

  /// Node budget and number of lines of the deep pass over the moments.
  final int? pass2Nodes;
  final int? pass2MultiPv;

  /// False when the pipeline ran without a human model; then no node has
  /// [AnalysisNode.human].
  bool get hasHumanModel =>
      humanModel.isNotEmpty && humanModel != 'unavailable';
}

/// Which language model and prompt wrote the texts.
final class CoachInfo {
  const CoachInfo({
    required this.provider,
    required this.model,
    required this.promptSet,
    required this.promptVersion,
    required this.pipelineVersion,
  });

  final String provider;
  final String model;
  final String promptSet;
  final String promptVersion;
  final String pipelineVersion;
}

/// One played move with everything the engine said about it.
final class AnalysisNode {
  AnalysisNode({
    required this.ply,
    required this.moveNumber,
    required this.side,
    required this.san,
    required this.uci,
    required this.move,
    required this.fenBefore,
    required this.fenAfter,
    required this.positionBefore,
    required this.positionAfter,
    required this.evalBefore,
    required this.evalAfter,
    required this.winPctBefore,
    required this.winPctAfter,
    required this.winPctLoss,
    required this.classification,
    required this.classificationRaw,
    required this.isCritical,
    required this.best,
    required this.human,
    required List<Variation> variations,
    required List<String> commentIds,
  }) : variations = List.unmodifiable(variations),
       commentIds = List.unmodifiable(commentIds);

  /// 1-based index into [AnalysisDocument.nodes].
  final int ply;

  /// Full-move number and mover, taken from the replayed position (so they
  /// are right for a game that does not start at move 1).
  final int moveNumber;
  final Side side;

  final String san;
  final String uci;

  /// [uci] as a dartchess move, legal in [positionBefore]. Castling is kept
  /// as sent (`e1g1`); `Position.play` accepts that form.
  final NormalMove move;

  final String fenBefore;
  final String fenAfter;
  final Position positionBefore;
  final Position positionAfter;

  /// From White's point of view.
  final EvalScore evalBefore;
  final EvalScore evalAfter;

  /// Win probabilities in percent from the **mover's** point of view,
  /// rating-calibrated by the server. Display them; never recompute them.
  final double winPctBefore;
  final double winPctAfter;

  /// `max(0, winPctBefore - winPctAfter)`.
  final double winPctLoss;

  final MoveClassification classification;

  /// The classification as sent, for logs. Null when it was not a string.
  final String? classificationRaw;

  /// True when the server picked this move as a moment (critical or
  /// positive).
  final bool isCritical;

  /// The engine's first choice at [fenBefore], or null when the played move
  /// is that choice (or there is no engine result).
  final BestMove? best;

  /// Human-model probabilities, if the pipeline had a human model.
  final HumanStats? human;

  /// Engine lines. Empty for nodes without a deep pass.
  final List<Variation> variations;

  /// Ids of the comments on this node that are in
  /// [AnalysisDocument.commentsById].
  final List<String> commentIds;

  /// The variation with [id] on this node, or null.
  Variation? variationById(String id) {
    for (final variation in variations) {
      if (variation.id == id) return variation;
    }
    return null;
  }

  /// `5. Nf3` or `5... e5`.
  String get moveLabel =>
      side == Side.white ? '$moveNumber. $san' : '$moveNumber... $san';

  @override
  String toString() => 'AnalysisNode($ply, $moveLabel, ${classification.name})';
}

/// The engine's first choice with its eval.
final class BestMove {
  const BestMove({
    required this.san,
    required this.uci,
    required this.move,
    required this.eval,
  });

  final String san;
  final String uci;
  final NormalMove move;
  final EvalScore eval;
}

/// How likely a player of the mover's rating is to find a move (0 to 1).
final class HumanStats {
  const HumanStats({required this.playedProb, required this.bestProb});

  final double playedProb;
  final double bestProb;
}

/// An engine line that belongs to a node.
final class Variation {
  Variation({
    required this.id,
    required this.kind,
    required this.kindRaw,
    required this.eval,
    required this.startFen,
    required this.startPosition,
    required List<VariationMove> moves,
  }) : moves = List.unmodifiable(moves);

  /// Opaque, unique within the document.
  final String id;
  final VariationKind kind;
  final String? kindRaw;

  /// Eval of the line from White's point of view.
  final EvalScore eval;

  /// The position the first move is played from: the node's `fenBefore` for
  /// [VariationKind.bestLine] and [VariationKind.alternative], its `fenAfter`
  /// for [VariationKind.refutation].
  final String startFen;
  final Position startPosition;

  /// At least one move.
  final List<VariationMove> moves;

  /// The moves in SAN.
  List<String> get sans => [for (final move in moves) move.san];
}

/// One move of a [Variation].
final class VariationMove {
  const VariationMove({
    required this.san,
    required this.uci,
    required this.move,
    required this.fenAfter,
    required this.positionAfter,
  });

  final String san;
  final String uci;
  final NormalMove move;
  final String fenAfter;
  final Position positionAfter;
}

/// A coach comment on one node.
final class CoachComment {
  CoachComment({
    required this.id,
    required this.type,
    required this.typeRaw,
    required this.ply,
    required this.title,
    required this.text,
    required this.theme,
    required List<SquareMark> squares,
    required List<CommentArrow> arrows,
    required List<LineRef> lines,
    required List<String> movesMentioned,
    required this.verificationStatus,
  }) : squares = List.unmodifiable(squares),
       arrows = List.unmodifiable(arrows),
       lines = List.unmodifiable(lines),
       movesMentioned = List.unmodifiable(movesMentioned);

  final String id;
  final CommentType type;
  final String? typeRaw;

  /// The node this comment belongs to.
  final int ply;

  /// May be empty.
  final String title;
  final String text;

  /// Open enum, as sent (`king_safety`, `tactics`, …). A UI shows a chip for
  /// the values it has a label for and none otherwise.
  final String theme;

  final List<SquareMark> squares;
  final List<CommentArrow> arrows;

  /// References to variations of the node at [ply]. Every reference resolves.
  final List<LineRef> lines;

  /// SAN tokens used in [title] and [text], for tappable moves.
  final List<String> movesMentioned;

  final VerificationStatus verificationStatus;

  /// True for a deterministic template text.
  bool get isFallback => verificationStatus == VerificationStatus.fallback;

  bool get isPositive => type == CommentType.positiveMoment;
}

/// A highlighted square.
final class SquareMark {
  const SquareMark({required this.square, required this.role, this.roleRaw});

  final Square square;
  final SquareRole role;
  final String? roleRaw;
}

/// An arrow of a comment.
final class CommentArrow {
  const CommentArrow({
    required this.from,
    required this.to,
    required this.role,
    this.roleRaw,
  });

  final Square from;
  final Square to;
  final ArrowRole role;
  final String? roleRaw;
}

/// A labelled reference from a comment to a variation of its node.
final class LineRef {
  const LineRef({required this.variationId, required this.label});

  final String variationId;
  final String label;
}

/// One lesson of the game summary.
final class Lesson {
  Lesson({
    required this.id,
    required this.title,
    required this.text,
    required List<int> evidencePlies,
    required this.theme,
  }) : evidencePlies = List.unmodifiable(evidencePlies);

  final String id;
  final String title;
  final String text;

  /// Plies that illustrate the lesson. All of them exist in the document.
  final List<int> evidencePlies;

  /// Open enum, as sent.
  final String theme;
}
