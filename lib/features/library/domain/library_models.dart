// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/storage/app_database.dart' show DraftState;
import 'package:flutter/foundation.dart';

/// What the badge of a library row says.
enum LibraryStatus {
  /// A draft the user is still entering.
  draft,

  /// A finished draft that waits for the submit queue (or is being sent).
  waitingToUpload,

  /// A draft the submit queue gave up on.
  uploadFailed,

  /// An analysis job is queued or running.
  analysing,
  analysisReady,
  analysisFailed,
  notAnalysed,
}

/// The status of a game on the server, given its newest job.
LibraryStatus statusOfGame({required bool hasAnalysis, JobInfo? job}) {
  if (job != null && job.status.isActive) {
    return LibraryStatus.analysing;
  }
  if (hasAnalysis || job?.status == JobStatus.done) {
    return LibraryStatus.analysisReady;
  }
  if (job?.status == JobStatus.failed) {
    return LibraryStatus.analysisFailed;
  }
  return LibraryStatus.notAnalysed;
}

LibraryStatus statusOfDraft(DraftState state) => switch (state) {
  DraftState.editing => LibraryStatus.draft,
  DraftState.ready ||
  DraftState.submitting ||
  DraftState.submitted => LibraryStatus.waitingToUpload,
  DraftState.failed => LibraryStatus.uploadFailed,
};

/// The search field and the date range of the library (AC-2).
@immutable
class LibraryFilter {
  const LibraryFilter({this.text = '', this.from, this.to});

  /// Part of a player's or an event's name.
  final String text;

  /// Inclusive. With either set, games without a date are left out.
  final GameDate? from;
  final GameDate? to;

  String get needle => text.trim().toLowerCase();
  bool get hasText => needle.isNotEmpty;
  bool get hasDates => from != null || to != null;
  bool get isActive => hasText || hasDates;

  LibraryFilter withText(String value) =>
      LibraryFilter(text: value, from: from, to: to);

  LibraryFilter withDates(GameDate? from, GameDate? to) =>
      LibraryFilter(text: text, from: from, to: to);

  /// The same rule the server applies to `search`: a case-insensitive
  /// "contains" on the names and the event.
  bool matchesText(Iterable<String?> fields) {
    if (!hasText) {
      return true;
    }
    final wanted = needle;
    return fields.any((f) => f != null && f.toLowerCase().contains(wanted));
  }

  bool matchesDate(GameDate? date) {
    if (!hasDates) {
      return true;
    }
    if (date == null) {
      return false;
    }
    return (from == null || date.compareTo(from!) >= 0) &&
        (to == null || date.compareTo(to!) <= 0);
  }

  @override
  bool operator ==(Object other) =>
      other is LibraryFilter &&
      other.needle == needle &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(needle, from, to);
}

/// A row of the library: a game on the server or a draft on this device.
@immutable
sealed class LibraryRow {
  const LibraryRow();

  String? get whiteName;
  String? get blackName;
  GameResult get result;
  GameDate? get playedDate;
  String? get eventName;
  LibraryStatus get status;
}

final class LibraryGameRow extends LibraryRow {
  const LibraryGameRow(this.game, {this.job});

  final GameSummary game;

  /// The newest job the app knows of: the tracker's, else the server's.
  final JobInfo? job;

  @override
  String? get whiteName => game.whiteName;
  @override
  String? get blackName => game.blackName;
  @override
  GameResult get result => game.result;
  @override
  GameDate? get playedDate => game.playedDate;
  @override
  String? get eventName => game.eventName;
  @override
  LibraryStatus get status =>
      statusOfGame(hasAnalysis: game.hasAnalysis, job: job);
}

final class LibraryDraftRow extends LibraryRow {
  const LibraryDraftRow({
    required this.draftId,
    required this.state,
    required this.metadata,
    required this.updatedAt,
  });

  final String draftId;
  final DraftState state;
  final GameMetadata metadata;
  final DateTime updatedAt;

  /// Only a draft that nobody is sending right now may be deleted here.
  bool get canDelete => state != DraftState.submitting;

  @override
  String? get whiteName => metadata.whiteName;
  @override
  String? get blackName => metadata.blackName;
  @override
  GameResult get result => metadata.result;
  @override
  GameDate? get playedDate => metadata.playedDate;
  @override
  String? get eventName => metadata.eventName;
  @override
  LibraryStatus get status => statusOfDraft(state);
}
