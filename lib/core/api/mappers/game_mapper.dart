// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/generated/operations/fragments.graphql.dart';
import 'package:bogner_chess/core/api/generated/operations/games.graphql.dart';
import 'package:bogner_chess/core/api/generated/schema.graphql.dart';
import 'package:bogner_chess/core/api/mappers/enum_mappers.dart';
import 'package:bogner_chess/core/api/models/analysis_models.dart';
import 'package:bogner_chess/core/api/models/game_models.dart';
import 'package:bogner_chess/core/api/scalars.dart';
import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:dartchess/dartchess.dart' show PgnGame;

JobInfo jobOf(Fragment$JobFields job) => JobInfo(
  id: job.id,
  gameId: job.chessGameId,
  status: jobStatusOf(job.status),
  stage: _text(job.stage),
  // The position only means something while the job waits.
  queuePosition: job.status == Enum$AnalysisJobStatus.QUEUED
      ? job.queuePosition
      : null,
  requestedAt: job.requestedAt,
  finishedAt: job.finishedAt,
  failureCode: _text(job.failureCode),
);

GameSummary gameSummaryOf(Fragment$GameFields game) => GameSummary(
  id: game.id,
  clientGameId: _text(game.clientGameId),
  whiteName: _text(game.whitePlayerName),
  blackName: _text(game.blackPlayerName),
  opponentName: _text(game.opponentName),
  whiteRating: game.whiteElo,
  blackRating: game.blackElo,
  playerColor: playerColorOf(game.playerColor),
  result: gameResultOf(game.result),
  playedDate: localDateFromJson(game.playedDate),
  eventName: _text(game.eventName),
  timeControlTag: _text(game.timeControl),
  createdAt: game.created,
  hasAnalysis: game.hasAnalysis,
  latestJob: switch (game.latestAnalysisJob) {
    null => null,
    final job => jobOf(job),
  },
);

GameDetail gameDetailOf(Query$GameById$myChessGameById game) {
  final summary = gameSummaryOf(game);
  return GameDetail(
    id: summary.id,
    clientGameId: summary.clientGameId,
    whiteName: summary.whiteName,
    blackName: summary.blackName,
    opponentName: summary.opponentName,
    whiteRating: summary.whiteRating,
    blackRating: summary.blackRating,
    playerColor: summary.playerColor,
    result: summary.result,
    playedDate: summary.playedDate,
    eventName: summary.eventName,
    timeControlTag: summary.timeControlTag,
    createdAt: summary.createdAt,
    hasAnalysis: summary.hasAnalysis,
    latestJob: summary.latestJob,
    plyCount: plyCountOf(game.rawPgn),
    pgn: game.rawPgn,
    startingFen: _text(game.startingFen),
    site: _text(game.site),
    round: _text(game.round),
  );
}

/// Half moves of the main line; null when the PGN cannot be read.
int? plyCountOf(String pgn) {
  try {
    return PgnGame.parsePgn(pgn).moves.mainline().length;
  } on Object {
    return null;
  }
}

/// The PGN that `importMobileGame` receives: the tag pairs of [metadata],
/// then [movetext]. A result token is appended unless the movetext ends with
/// one already.
String buildImportPgn(GameMetadata metadata, String movetext) {
  final buffer = StringBuffer();
  for (final MapEntry(:key, :value) in metadata.toPgnHeaders().entries) {
    final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    buffer.writeln('[$key "$escaped"]');
  }
  buffer.writeln();
  final moves = movetext.trim();
  buffer.write(moves);
  if (!_endsWithResult.hasMatch(moves)) {
    buffer.write(
      moves.isEmpty ? metadata.result.pgn : ' ${metadata.result.pgn}',
    );
  }
  buffer.writeln();
  return buffer.toString();
}

final RegExp _endsWithResult = RegExp(r'(^|\s)(1-0|0-1|1/2-1/2|\*)$');

String? _text(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
