// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/foundation.dart';

import 'draft_meta.dart';

/// Why an upload did not work, as stored in `drafts.last_error`: a short
/// code, never a sentence, because the language may change before the text
/// is shown. The UI turns it into words.
enum SubmitErrorKind {
  /// No connection, or a time-out.
  network,

  /// The server answered with an error that may pass.
  server,

  /// The server is rate limiting this account.
  rateLimited,

  /// The session ended; signing in again helps.
  unauthenticated,

  /// The server could not read the moves. Does not pass by itself.
  pgnInvalid,

  /// The server refused the game for another reason. Does not pass by itself.
  rejected,

  /// A bug on this side (the database, an unexpected exception).
  internal,
}

@immutable
class SubmitError {
  const SubmitError(this.kind, {this.moveNumber, this.san});

  /// Reads `drafts.last_error`. Unknown text reads as [SubmitErrorKind.server],
  /// the most harmless wording.
  factory SubmitError.parse(String? stored) {
    final parts = (stored ?? '').split('|');
    final kind = SubmitErrorKind.values.asNameMap()[parts.first];
    if (kind == null) return const SubmitError(SubmitErrorKind.server);
    return SubmitError(
      kind,
      moveNumber: parts.length > 1 ? int.tryParse(parts[1]) : null,
      san: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
    );
  }

  final SubmitErrorKind kind;

  /// For [SubmitErrorKind.pgnInvalid], when the server said where.
  final int? moveNumber;
  final String? san;

  /// Whether trying again without changing anything can help.
  bool get isTransient => switch (kind) {
    SubmitErrorKind.pgnInvalid || SubmitErrorKind.rejected => false,
    _ => true,
  };

  String encode() => switch (kind) {
    SubmitErrorKind.pgnInvalid => [
      kind.name,
      moveNumber?.toString() ?? '',
      // SAN is at most a handful of letters; cut whatever else arrives.
      (san ?? '').replaceAll('|', '').truncated(12),
    ].join('|'),
    _ => kind.name,
  };

  @override
  bool operator ==(Object other) =>
      other is SubmitError &&
      other.kind == kind &&
      other.moveNumber == moveNumber &&
      other.san == san;

  @override
  int get hashCode => Object.hash(kind, moveNumber, san);

  @override
  String toString() => 'SubmitError(${encode()})';
}

extension on String {
  String truncated(int max) => length <= max ? this : substring(0, max);
}

/// What the queue surface shows. Counts are of the signed-in user's drafts.
@immutable
class SubmitQueueStatus {
  const SubmitQueueStatus({
    this.waiting = 0,
    this.failed = 0,
    this.uploading = false,
    this.offline = false,
    this.nextAttemptAt,
  });

  static const SubmitQueueStatus idle = SubmitQueueStatus();

  /// Games that will be uploaded without the user doing anything: ready
  /// (possibly waiting for a back-off to end) or being sent right now.
  final int waiting;

  /// Games the queue has given up on. They need Retry or Delete.
  final int failed;

  /// A request is under way.
  final bool uploading;

  /// The device reports no network. A hint for the wording.
  final bool offline;

  /// When the queue tries again by itself; null when nothing waits for a
  /// back-off.
  final DateTime? nextAttemptAt;

  bool get isEmpty => waiting == 0 && failed == 0;

  SubmitQueueStatus copyWith({
    int? waiting,
    int? failed,
    bool? uploading,
    bool? offline,
    DateTime? Function()? nextAttemptAt,
  }) => SubmitQueueStatus(
    waiting: waiting ?? this.waiting,
    failed: failed ?? this.failed,
    uploading: uploading ?? this.uploading,
    offline: offline ?? this.offline,
    nextAttemptAt: nextAttemptAt == null ? this.nextAttemptAt : nextAttemptAt(),
  );

  @override
  bool operator ==(Object other) =>
      other is SubmitQueueStatus &&
      other.waiting == waiting &&
      other.failed == failed &&
      other.uploading == uploading &&
      other.offline == offline &&
      other.nextAttemptAt == nextAttemptAt;

  @override
  int get hashCode =>
      Object.hash(waiting, failed, uploading, offline, nextAttemptAt);

  @override
  String toString() =>
      'SubmitQueueStatus(waiting $waiting, failed $failed, '
      '${uploading ? 'uploading' : 'idle'}, ${offline ? 'offline' : 'online'})';
}

/// What became of the analysis that "Save & analyse" asked for.
enum SubmittedAnalysis { notRequested, started, held }

/// Something the user should hear about, whatever screen is showing.
@immutable
sealed class SubmitEvent {
  const SubmitEvent(this.draftId);

  final String draftId;
}

/// The game is on the server.
final class GameUploaded extends SubmitEvent {
  const GameUploaded(
    super.draftId, {
    required this.gameId,
    required this.analysis,
    this.hold,
  });

  final String gameId;
  final SubmittedAnalysis analysis;

  /// Set when [analysis] is [SubmittedAnalysis.held].
  final AnalysisHold? hold;

  @override
  String toString() => 'GameUploaded(${analysis.name}, ${hold?.name})';
}

/// The queue gave up on the draft. It stays on the device.
final class UploadFailed extends SubmitEvent {
  const UploadFailed(super.draftId, this.error);

  final SubmitError error;

  @override
  String toString() => 'UploadFailed(${error.kind.name})';
}
