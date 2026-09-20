// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

import 'package:bogner_chess/core/api/models/game_models.dart'
    show ImportSource;
import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/foundation.dart';

/// How a game got into the app. Stored by name.
enum DraftSource {
  /// Entered on the board.
  board,

  /// Pasted or typed PGN text.
  pgn,

  /// A PGN file picked on the import screen.
  file,

  /// Handed over from outside: "Open in…" or the share extension.
  share;

  /// What the server is told. It knows no "file".
  ImportSource get importSource => switch (this) {
    DraftSource.board => ImportSource.board,
    DraftSource.pgn || DraftSource.file => ImportSource.pgn,
    DraftSource.share => ImportSource.share,
  };
}

/// Why the game is on the server but its analysis was not started. The game
/// detail screen offers to start it. Stored by name.
enum AnalysisHold {
  limitReached,
  queueFull,
  rateLimited,
  emailNotVerified,
  aiConsentRequired,

  /// The request itself kept failing (network, server).
  requestFailed,
}

/// The `meta_json` column of a draft: the game's metadata (the keys of
/// `GameMetadata.toJson`, at the top level, so that anybody can read them
/// with `GameMetadata.fromJson`) plus, under the key `draft`, what only the
/// device cares about.
///
///     {"v": 1, "whiteName": "…", …,
///      "draft": {"source": "board", "cursorPly": 12, "orientation": "black",
///                "analysisHold": "limitReached"}}
///
/// Reading never throws: anything unknown or damaged reads as "not known".
@immutable
class DraftMeta {
  const DraftMeta({
    this.metadata = const GameMetadata(),
    this.source = DraftSource.board,
    this.cursorPly,
    this.orientation,
    this.analysisHold,
  });

  factory DraftMeta.decode(String metaJson) {
    Object? json;
    try {
      json = jsonDecode(metaJson);
    } on FormatException {
      json = null;
    }
    final draft = switch (json) {
      {'draft': final Map<String, dynamic> draft} => draft,
      _ => const <String, dynamic>{},
    };
    T? byName<T extends Enum>(List<T> values, Object? name) {
      for (final value in values) {
        if (value.name == name) return value;
      }
      return null;
    }

    return DraftMeta(
      metadata: GameMetadata.fromJson(json),
      source: byName(DraftSource.values, draft['source']) ?? DraftSource.board,
      cursorPly: switch (draft['cursorPly']) {
        final int ply when ply >= 0 => ply,
        _ => null,
      },
      orientation: byName(Side.values, draft['orientation']),
      analysisHold: byName(AnalysisHold.values, draft['analysisHold']),
    );
  }

  final GameMetadata metadata;
  final DraftSource source;

  /// Where the entry screen's cursor was; null means the end of the line.
  final int? cursorPly;

  /// The side at the bottom of the entry board.
  final Side? orientation;

  final AnalysisHold? analysisHold;

  String encode() => jsonEncode({
    ...metadata.toJson(),
    'draft': {
      'source': source.name,
      'cursorPly': ?cursorPly,
      'orientation': ?orientation?.name,
      'analysisHold': ?analysisHold?.name,
    },
  });

  DraftMeta withMetadata(GameMetadata metadata) => DraftMeta(
    metadata: metadata,
    source: source,
    cursorPly: cursorPly,
    orientation: orientation,
    analysisHold: analysisHold,
  );

  DraftMeta withEntryView({
    required int cursorPly,
    required Side orientation,
  }) => DraftMeta(
    metadata: metadata,
    source: source,
    cursorPly: cursorPly,
    orientation: orientation,
    analysisHold: analysisHold,
  );

  DraftMeta withAnalysisHold(AnalysisHold? hold) => DraftMeta(
    metadata: metadata,
    source: source,
    cursorPly: cursorPly,
    orientation: orientation,
    analysisHold: hold,
  );

  @override
  bool operator ==(Object other) =>
      other is DraftMeta &&
      other.metadata == metadata &&
      other.source == source &&
      other.cursorPly == cursorPly &&
      other.orientation == orientation &&
      other.analysisHold == analysisHold;

  @override
  int get hashCode =>
      Object.hash(metadata, source, cursorPly, orientation, analysisHold);

  // No names: see GameMetadata.toString.
  @override
  String toString() =>
      'DraftMeta(${source.name}, ply $cursorPly, hold ${analysisHold?.name})';
}
