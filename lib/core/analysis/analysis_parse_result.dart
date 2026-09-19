// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:dartchess/dartchess.dart';

import 'analysis_document.dart';

/// What `AnalysisParser` made of a payload. Switch over it:
///
/// ```dart
/// switch (AnalysisParser.parseString(payload)) {
///   case AnalysisSupported(:final document): // full review
///   case AnalysisNewerMajor(:final partial): // board, moves, "update the app"
///   case AnalysisInvalid(:final reason):     // error state, log the reason
/// }
/// ```
sealed class AnalysisParseResult {
  const AnalysisParseResult();
}

/// The document has a major version this build understands.
final class AnalysisSupported extends AnalysisParseResult {
  AnalysisSupported(this.document, {List<String> warnings = const []})
    : warnings = List.unmodifiable(warnings);

  final AnalysisDocument document;

  /// What the parser dropped or repaired, for logs. Never shown to the user.
  final List<String> warnings;
}

/// The document has a higher major version than this build supports. The UI
/// shows the board and the moves of [partial] with an "update the app" banner.
final class AnalysisNewerMajor extends AnalysisParseResult {
  AnalysisNewerMajor(this.partial, {List<String> warnings = const []})
    : warnings = List.unmodifiable(warnings);

  final PartialAnalysis partial;
  final List<String> warnings;
}

/// The payload is not an analysis document, or it is broken at its core
/// (envelope, main line). [reason] is for logs, not for the user.
final class AnalysisInvalid extends AnalysisParseResult {
  const AnalysisInvalid(this.reason);

  final String reason;

  @override
  String toString() => 'AnalysisInvalid($reason)';
}

/// The part of a document of an unknown major version that could be read
/// without guessing: the legal prefix of the main line.
final class PartialAnalysis {
  PartialAnalysis({
    required this.schemaVersion,
    required this.schemaMinor,
    required this.analysisId,
    required this.startFen,
    required this.startPosition,
    required this.result,
    required List<PartialMove> moves,
  }) : moves = List.unmodifiable(moves);

  final int schemaVersion;
  final int? schemaMinor;
  final String? analysisId;

  /// Null for the standard starting position.
  final String? startFen;
  final Position startPosition;

  /// The result, if it was where version 1 keeps it.
  final GameResult? result;

  /// The moves that could be read and replayed legally, from ply 1 without a
  /// gap. Empty when the new format keeps its moves somewhere else.
  final List<PartialMove> moves;

  /// The position after [ply] plies; out-of-range values are clamped.
  Position positionAt(int ply) {
    if (ply <= 0 || moves.isEmpty) return startPosition;
    return moves[ply > moves.length ? moves.length - 1 : ply - 1].positionAfter;
  }
}

/// One replayed move of a [PartialAnalysis].
final class PartialMove {
  const PartialMove({
    required this.ply,
    required this.moveNumber,
    required this.side,
    required this.san,
    required this.uci,
    required this.move,
    required this.fenAfter,
    required this.positionAfter,
  });

  final int ply;
  final int moveNumber;
  final Side side;

  /// SAN as dartchess writes it for the replayed move.
  final String san;
  final String uci;
  final NormalMove move;

  /// FEN of [positionAfter], computed by the replay.
  final String fenAfter;
  final Position positionAfter;
}
