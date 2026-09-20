// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/game/game_metadata.dart';

/// [GameSummary] as the JSON text in `cached_games.summary_json`.
///
/// The format is private to the app (version key `v`). Reading is tolerant:
/// a row this build cannot read is null and simply does not show until the
/// next refresh replaces it.
abstract final class GameSummaryCodec {
  static const int version = 1;

  static String encode(GameSummary game) => jsonEncode(toJson(game));

  static Map<String, Object?> toJson(GameSummary game) => {
    'v': version,
    'id': game.id,
    'clientGameId': game.clientGameId,
    'white': game.whiteName,
    'black': game.blackName,
    'opponent': game.opponentName,
    'whiteRating': game.whiteRating,
    'blackRating': game.blackRating,
    'playerColor': game.playerColor.name,
    'result': game.result.pgn,
    'playedDate': game.playedDate?.toIso(),
    'event': game.eventName,
    'timeControl': game.timeControlTag,
    'createdAt': game.createdAt?.toUtc().toIso8601String(),
    'hasAnalysis': game.hasAnalysis,
    'job': switch (game.latestJob) {
      null => null,
      final job => jobToJson(job),
    },
  };

  static Map<String, Object?> jobToJson(JobInfo job) => {
    'id': job.id,
    'gameId': job.gameId,
    'status': job.status.name,
    'stage': job.stage,
    'queuePosition': job.queuePosition,
    'requestedAt': job.requestedAt.toUtc().toIso8601String(),
    'finishedAt': job.finishedAt?.toUtc().toIso8601String(),
    'failureCode': job.failureCode,
  };

  static GameSummary? decode(String text) {
    try {
      final json = jsonDecode(text);
      return json is Map<String, dynamic> ? fromJson(json) : null;
    } on FormatException {
      return null;
    }
  }

  static GameSummary? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      return null;
    }
    return GameSummary(
      id: id,
      clientGameId: _string(json['clientGameId']),
      whiteName: _string(json['white']),
      blackName: _string(json['black']),
      opponentName: _string(json['opponent']),
      whiteRating: _int(json['whiteRating']),
      blackRating: _int(json['blackRating']),
      playerColor: json['playerColor'] == PlayerColor.black.name
          ? PlayerColor.black
          : PlayerColor.white,
      result: GameResult.fromPgn(json['result']),
      playedDate: GameDate.tryParseIso(_string(json['playedDate'])),
      eventName: _string(json['event']),
      timeControlTag: _string(json['timeControl']),
      createdAt: _instant(json['createdAt']),
      hasAnalysis: json['hasAnalysis'] == true,
      latestJob: switch (json['job']) {
        final Map<String, dynamic> job => jobFromJson(job),
        _ => null,
      },
    );
  }

  static JobInfo? jobFromJson(Map<String, dynamic> json) {
    final id = _string(json['id']);
    final gameId = _string(json['gameId']);
    final requestedAt = _instant(json['requestedAt']);
    if (id == null || gameId == null || requestedAt == null) {
      return null;
    }
    return JobInfo(
      id: id,
      gameId: gameId,
      status: JobStatus.values.asNameMap()[json['status']] ?? JobStatus.unknown,
      stage: _string(json['stage']),
      queuePosition: _int(json['queuePosition']),
      requestedAt: requestedAt,
      finishedAt: _instant(json['finishedAt']),
      failureCode: _string(json['failureCode']),
    );
  }

  static String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static int? _int(Object? value) => value is int ? value : null;

  static DateTime? _instant(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}

/// [game] with another job and analysis flag; everything else unchanged.
GameSummary gameSummaryWith(
  GameSummary game, {
  required JobInfo? latestJob,
  required bool hasAnalysis,
}) {
  return GameSummary(
    id: game.id,
    clientGameId: game.clientGameId,
    whiteName: game.whiteName,
    blackName: game.blackName,
    opponentName: game.opponentName,
    whiteRating: game.whiteRating,
    blackRating: game.blackRating,
    playerColor: game.playerColor,
    result: game.result,
    playedDate: game.playedDate,
    eventName: game.eventName,
    timeControlTag: game.timeControlTag,
    plyCount: game.plyCount,
    createdAt: game.createdAt,
    hasAnalysis: hasAnalysis,
    latestJob: latestJob,
  );
}
