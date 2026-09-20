// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/foundation.dart';

/// The custom part of a push payload, next to `aps`:
/// `{"type": "analysis_ready", "gameId": "…", "jobId": "…"}`.
///
/// A payload is input from outside. The native side forwards only these
/// three keys, and only strings; [PushMessage.parse] accepts a game id only
/// in the form a link may carry, and the location it leads to is checked
/// once more by the mapping table of `link_target.dart`.
@immutable
sealed class PushMessage {
  const PushMessage();

  static const String analysisReadyType = 'analysis_ready';

  /// Never throws. A type this version does not know, or a known type
  /// without what it needs, is an [UnknownPushMessage].
  static PushMessage parse(Object? payload) {
    if (payload is! Map) {
      return const UnknownPushMessage(null);
    }
    final type = payload['type'];
    if (type is! String) {
      return const UnknownPushMessage(null);
    }
    if (type == analysisReadyType) {
      final gameId = payload['gameId'];
      final jobId = payload['jobId'];
      if (gameId is String && _idPattern.hasMatch(gameId)) {
        return AnalysisReadyMessage(
          gameId: gameId,
          jobId: jobId is String && _idPattern.hasMatch(jobId) ? jobId : null,
        );
      }
    }
    return UnknownPushMessage(type);
  }

  // The same alphabet as ids in links (link_target.dart).
  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_.~=+:-]{1,128}$');
}

final class AnalysisReadyMessage extends PushMessage {
  const AnalysisReadyMessage({required this.gameId, this.jobId});

  final String gameId;
  final String? jobId;

  @override
  bool operator ==(Object other) =>
      other is AnalysisReadyMessage &&
      other.gameId == gameId &&
      other.jobId == jobId;

  @override
  int get hashCode => Object.hash(AnalysisReadyMessage, gameId, jobId);

  // Ids stay out of logs.
  @override
  String toString() => 'AnalysisReadyMessage';
}

/// A notification this version cannot act on. Tapping it opens the app where
/// it was, nothing else.
final class UnknownPushMessage extends PushMessage {
  const UnknownPushMessage(this.type);

  final String? type;

  @override
  bool operator ==(Object other) =>
      other is UnknownPushMessage && other.type == type;

  @override
  int get hashCode => Object.hash(UnknownPushMessage, type);

  @override
  String toString() => 'UnknownPushMessage';
}
