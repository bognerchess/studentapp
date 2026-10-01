// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:intl/intl.dart';

/// "1-0 · You won", "½-½ · Draw", or just the token when the outcome for the
/// user is not known. Null for a game without a result.
String? resultLine(
  AppLocalizations l10n,
  GameResult result,
  PlayerColor playerColor,
) {
  if (result == GameResult.unknown) {
    return null;
  }
  final token = result == GameResult.draw ? '½-½' : result.pgn;
  final outcome = switch (result) {
    GameResult.draw => l10n.gameDetailOutcomeDraw,
    GameResult.whiteWins =>
      playerColor == PlayerColor.white
          ? l10n.gameDetailOutcomeWin
          : l10n.gameDetailOutcomeLoss,
    GameResult.blackWins =>
      playerColor == PlayerColor.black
          ? l10n.gameDetailOutcomeWin
          : l10n.gameDetailOutcomeLoss,
    GameResult.unknown => null,
  };
  return outcome == null ? token : '$token · $outcome';
}

String formatGameDate(AppLocalizations l10n, GameDate date) =>
    DateFormat.yMMMd(l10n.localeName).format(date.toLocalDateTime());

/// A reset instant for the limit sheet, in the device's time zone: "00:00"
/// when it is within a day, else "1 Oct, 00:00".
String formatResetAt(AppLocalizations l10n, DateTime resetAt, DateTime now) {
  final local = resetAt.toLocal();
  final time = DateFormat.jm(l10n.localeName).format(local);
  if (local.difference(now).inHours < 24) {
    return time;
  }
  return '${DateFormat.MMMd(l10n.localeName).format(local)}, $time';
}

/// "Rapid · 15+10", or whichever half is known.
String timeControlText(AppLocalizations l10n, TimeControl control) {
  final kind = switch (control.kind) {
    TimeControlKind.classical => l10n.metadataTimeControlClassical,
    TimeControlKind.rapid => l10n.metadataTimeControlRapid,
    TimeControlKind.blitz => l10n.metadataTimeControlBlitz,
    TimeControlKind.bullet => l10n.metadataTimeControlBullet,
    TimeControlKind.other => null,
  };
  final detail = control.detail;
  if (kind == null) {
    return detail ?? l10n.metadataTimeControlOther;
  }
  return detail == null ? kind : '$kind · $detail';
}
