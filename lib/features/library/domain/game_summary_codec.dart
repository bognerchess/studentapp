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
/// next refresh replaces it. Version 2 added `workflow`, so a version-1 row
/// reads as a game whose pipeline this device knows nothing about — which is
/// exactly what it was. Version 3 added `state` and `targetReason` inside
/// `workflow` (WP-61); a version-2 row has neither, and
/// `GameWorkflowSummary.workflowState` reads its stage states instead.
///
/// A version-1 row also carries a `job` key, the whole-game analysis job of
/// the path WP-60 replaced. It is read past: that job is transient state of a
/// pipeline that no longer exists in this app, and the badge never depended on
/// it (`hasAnalysis` and `workflow` decide). The next refresh writes the row
/// without the key.
abstract final class GameSummaryCodec {
  static const int version = 3;

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
    'workflow': game.workflow?.toJson(),
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
      workflow: workflowFromJson(json['workflow']),
    );
  }

  /// The pipeline summary of a row, or null: a version-1 row has no key, and
  /// damaged content reads as "nothing known" rather than failing the row.
  static GameWorkflowSummary? workflowFromJson(Object? value) =>
      value is Map<String, dynamic>
      ? GameWorkflowSummary.fromJson(value)
      : null;

  static String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static int? _int(Object? value) => value is int ? value : null;

  static DateTime? _instant(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}

/// [game] with another pipeline summary and analysis flag; everything else
/// unchanged.
GameSummary gameSummaryWith(
  GameSummary game, {
  required bool hasAnalysis,
  GameWorkflowSummary? workflow,
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
    workflow: workflow ?? game.workflow,
  );
}
