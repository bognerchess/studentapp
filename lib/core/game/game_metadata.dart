// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/game/game_date.dart';
import 'package:bogner_chess/core/game/time_control.dart';
import 'package:flutter/foundation.dart';

export 'package:bogner_chess/core/game/game_date.dart';
export 'package:bogner_chess/core/game/time_control.dart';

/// The colour the app's user played.
enum PlayerColor {
  white,
  black;

  PlayerColor get opposite => this == white ? black : white;

  /// The value stored in JSON.
  String get wireName => name;

  static PlayerColor? fromWireName(Object? value) {
    for (final color in values) {
      if (color.name == value) {
        return color;
      }
    }
    return null;
  }
}

/// How the game ended, from the board's point of view.
enum GameResult {
  whiteWins('1-0'),
  blackWins('0-1'),
  draw('1/2-1/2'),

  /// Not known, or the game is not over.
  unknown('*');

  const GameResult(this.pgn);

  /// The PGN `Result` tag, which is also the value stored in JSON.
  final String pgn;

  /// Reads a PGN result. Anything that is not clearly a result is [unknown].
  static GameResult fromPgn(Object? value) {
    if (value is! String) {
      return unknown;
    }
    final text = value.replaceAll(RegExp(r'\s'), '').replaceAll('–', '-');
    return switch (text) {
      '1-0' => whiteWins,
      '0-1' => blackWins,
      '1/2-1/2' || '½-½' || '1/2' || '½' || '0.5-0.5' => draw,
      _ => unknown,
    };
  }
}

/// What a [GameResult] means for the user.
enum PlayerOutcome { win, loss, draw }

/// A field of [GameMetadata], as named by [MetadataValidation].
enum MetadataField {
  playerColor,
  whiteName,
  blackName,
  playedDate,
  eventName,
  timeControl,
  whiteRating,
  blackRating;

  static MetadataField nameOf(PlayerColor color) =>
      color == PlayerColor.white ? whiteName : blackName;

  static MetadataField ratingOf(PlayerColor color) =>
      color == PlayerColor.white ? whiteRating : blackRating;
}

enum MetadataProblem {
  /// Required before the game can be submitted, and not there.
  missing,

  /// There, but not acceptable (a rating of 12, a date next year).
  invalid,
}

@immutable
class MetadataIssue {
  const MetadataIssue(this.field, this.problem);

  final MetadataField field;
  final MetadataProblem problem;

  @override
  bool operator ==(Object other) =>
      other is MetadataIssue &&
      other.field == field &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(field, problem);

  @override
  String toString() => '${field.name}: ${problem.name}';
}

/// The result of [GameMetadata.validate].
@immutable
class MetadataValidation {
  const MetadataValidation(this.issues);

  final List<MetadataIssue> issues;

  /// True when the metadata may be saved and the game submitted.
  bool get isValid => issues.isEmpty;

  Set<MetadataField> get missing => _fields(MetadataProblem.missing);
  Set<MetadataField> get invalid => _fields(MetadataProblem.invalid);

  MetadataProblem? problemOf(MetadataField field) {
    for (final issue in issues) {
      if (issue.field == field) {
        return issue.problem;
      }
    }
    return null;
  }

  Set<MetadataField> _fields(MetadataProblem problem) => {
    for (final issue in issues)
      if (issue.problem == problem) issue.field,
  };

  @override
  String toString() => 'MetadataValidation($issues)';
}

const Object _unset = Object();

/// What a player knows about a game besides its moves (PRD IN-2): who played,
/// which colour the user had, the result, the day, the event, the time
/// control and both ratings.
///
/// Names and ratings are stored by colour, because that is what a PGN and
/// the server want and because it stays true while [playerColor] is still
/// unknown (a freshly imported PGN). The user's view is derived:
/// [playerName], [opponentName], [playerRating], [opponentRating]. To build
/// one from the user's view, use [GameMetadata.forPlayer].
///
/// Text is normalised on the way out: the getters trim, collapse white space
/// (a PGN header is one line) and turn blank into null. Equality and JSON use
/// the normalised values.
///
/// [toString] leaves the names out, so that logging one by accident does not
/// leak personal data.
@immutable
class GameMetadata {
  const GameMetadata({
    this._whiteName,
    this._blackName,
    this.playerColor,
    this.result = GameResult.unknown,
    this.playedDate,
    this._eventName,
    this.timeControl,
    this.whiteRating,
    this.blackRating,
  });

  /// From the user's point of view: "I had [playerColor], my opponent was
  /// [opponentName]".
  factory GameMetadata.forPlayer({
    required PlayerColor playerColor,
    String? playerName,
    String? opponentName,
    int? playerRating,
    int? opponentRating,
    GameResult result = GameResult.unknown,
    GameDate? playedDate,
    String? eventName,
    TimeControl? timeControl,
  }) {
    final isWhite = playerColor == PlayerColor.white;
    return GameMetadata(
      whiteName: isWhite ? playerName : opponentName,
      blackName: isWhite ? opponentName : playerName,
      playerColor: playerColor,
      result: result,
      playedDate: playedDate,
      eventName: eventName,
      timeControl: timeControl,
      whiteRating: isWhite ? playerRating : opponentRating,
      blackRating: isWhite ? opponentRating : playerRating,
    );
  }

  /// Reads what [toJson] wrote. Never throws: unknown keys are ignored, a
  /// value of the wrong type or an enum value from a newer version reads as
  /// "not known". Anything that is not a JSON object gives empty metadata.
  factory GameMetadata.fromJson(Object? json) {
    if (json is! Map) {
      return const GameMetadata();
    }
    return GameMetadata(
      whiteName: _string(json[_kWhiteName]),
      blackName: _string(json[_kBlackName]),
      playerColor: PlayerColor.fromWireName(json[_kPlayerColor]),
      result: GameResult.fromPgn(json[_kResult]),
      playedDate: GameDate.tryParseIso(_string(json[_kPlayedDate])),
      eventName: _string(json[_kEventName]),
      timeControl: TimeControl.fromJson(json[_kTimeControl]),
      whiteRating: _int(json[_kWhiteRating]),
      blackRating: _int(json[_kBlackRating]),
    );
  }

  /// Reads the tag pairs of a PGN. Never throws. "?", "-" and blank values
  /// are "not known", and so is a partial date ("2019.??.??"); the `Date`
  /// tag wins over `UTCDate`. A rating outside [minRating]..[maxRating] is
  /// dropped. Tag names are matched without regard to case.
  ///
  /// A PGN does not say which side the user was. Pass [playerColor] when it
  /// is known, or [playerName] (the account's name) to have it worked out
  /// with [inferPlayerColor]; otherwise it stays null and the form asks.
  factory GameMetadata.fromPgnHeaders(
    Map<String, String> headers, {
    PlayerColor? playerColor,
    String? playerName,
  }) {
    final tags = {
      for (final MapEntry(:key, :value) in headers.entries)
        key.toLowerCase(): value,
    };
    String? known(String tag) {
      final value = tags[tag]?.trim() ?? '';
      return value.isEmpty || value == '?' || value == '-' ? null : value;
    }

    final metadata = GameMetadata(
      whiteName: known('white'),
      blackName: known('black'),
      result: GameResult.fromPgn(tags['result']),
      playedDate:
          GameDate.tryParsePgn(tags['date']) ??
          GameDate.tryParsePgn(tags['utcdate']),
      eventName: known('event'),
      timeControl: TimeControl.fromPgnTag(tags['timecontrol']),
      whiteRating: _rating(known('whiteelo')),
      blackRating: _rating(known('blackelo')),
    );
    return metadata.copyWith(
      playerColor: playerColor ?? metadata.inferPlayerColor(playerName),
    );
  }

  static const String _kVersion = 'v';
  static const String _kWhiteName = 'whiteName';
  static const String _kBlackName = 'blackName';
  static const String _kPlayerColor = 'playerColor';
  static const String _kResult = 'result';
  static const String _kPlayedDate = 'playedDate';
  static const String _kEventName = 'eventName';
  static const String _kTimeControl = 'timeControl';
  static const String _kWhiteRating = 'whiteRating';
  static const String _kBlackRating = 'blackRating';

  /// The bounds of a plausible rating, both inclusive.
  static const int minRating = 100;
  static const int maxRating = 3500;

  /// The longest name and event the validation accepts.
  static const int maxNameLength = 100;
  static const int maxEventLength = 120;

  /// How far a [playedDate] may lie after the device's today. One day,
  /// because online PGNs carry the UTC date, which is already tomorrow for
  /// an evening game in America.
  static const int futureDateSlackDays = 1;

  final String? _whiteName;
  final String? _blackName;
  final String? _eventName;

  String? get whiteName => _clean(_whiteName);
  String? get blackName => _clean(_blackName);
  String? get eventName => _clean(_eventName);

  /// Which colour the user played. Required before a game is submitted: the
  /// coach speaks to one side of the board.
  final PlayerColor? playerColor;

  final GameResult result;
  final GameDate? playedDate;
  final TimeControl? timeControl;
  final int? whiteRating;
  final int? blackRating;

  // ---- The user's view. All null while playerColor is unknown. ----

  String? get playerName => _byColor(playerColor, whiteName, blackName);
  String? get opponentName =>
      _byColor(playerColor?.opposite, whiteName, blackName);
  int? get playerRating => _byColor(playerColor, whiteRating, blackRating);
  int? get opponentRating =>
      _byColor(playerColor?.opposite, whiteRating, blackRating);

  /// Win, loss or draw for the user; null while the colour or the result is
  /// unknown.
  PlayerOutcome? get playerOutcome {
    final color = playerColor;
    if (color == null) {
      return null;
    }
    return switch (result) {
      GameResult.unknown => null,
      GameResult.draw => PlayerOutcome.draw,
      GameResult.whiteWins =>
        color == PlayerColor.white ? PlayerOutcome.win : PlayerOutcome.loss,
      GameResult.blackWins =>
        color == PlayerColor.black ? PlayerOutcome.win : PlayerOutcome.loss,
    };
  }

  static T? _byColor<T>(PlayerColor? color, T? white, T? black) =>
      switch (color) {
        null => null,
        PlayerColor.white => white,
        PlayerColor.black => black,
      };

  /// True when nothing at all is known.
  bool get isEmpty => this == const GameMetadata();

  /// The side whose name is [name], or null when neither or both match.
  /// "Weis, Roman", "Roman Weis" and "roman weis" are the same name.
  PlayerColor? inferPlayerColor(String? name) {
    final wanted = _nameKey(name);
    if (wanted.isEmpty) {
      return null;
    }
    final isWhite = _nameKey(whiteName) == wanted;
    final isBlack = _nameKey(blackName) == wanted;
    if (isWhite == isBlack) {
      return null;
    }
    return isWhite ? PlayerColor.white : PlayerColor.black;
  }

  /// Lists what is missing or not acceptable. [today] is for tests.
  MetadataValidation validate({GameDate? today}) {
    final issues = <MetadataIssue>[];
    void invalid(MetadataField field) =>
        issues.add(MetadataIssue(field, MetadataProblem.invalid));

    if (playerColor == null) {
      issues.add(
        const MetadataIssue(MetadataField.playerColor, MetadataProblem.missing),
      );
    }
    if ((whiteName?.length ?? 0) > maxNameLength) {
      invalid(MetadataField.whiteName);
    }
    if ((blackName?.length ?? 0) > maxNameLength) {
      invalid(MetadataField.blackName);
    }
    final date = playedDate;
    if (date != null) {
      final latest = GameDate.fromDateTime(
        (today ?? GameDate.today()).toLocalDateTime().add(
          // 12 extra hours keep a daylight-saving switch from eating a day.
          const Duration(days: futureDateSlackDays, hours: 12),
        ),
      );
      if (date.isAfter(latest)) {
        invalid(MetadataField.playedDate);
      }
    }
    if ((eventName?.length ?? 0) > maxEventLength) {
      invalid(MetadataField.eventName);
    }
    if ((timeControl?.detail?.length ?? 0) > TimeControl.maxDetailLength) {
      invalid(MetadataField.timeControl);
    }
    if (!isPlausibleRating(whiteRating)) {
      invalid(MetadataField.whiteRating);
    }
    if (!isPlausibleRating(blackRating)) {
      invalid(MetadataField.blackRating);
    }
    return MetadataValidation(List.unmodifiable(issues));
  }

  /// True for null (not known) and for [minRating]..[maxRating].
  static bool isPlausibleRating(int? rating) =>
      rating == null || (rating >= minRating && rating <= maxRating);

  /// The tag pairs for a PGN, in the order they belong: the Seven Tag Roster
  /// (`Event`, `Site`, `Date`, `Round`, `White`, `Black`, `Result`) with "?"
  /// for what is not known and "????.??.??" for an unknown date, followed by
  /// `WhiteElo`, `BlackElo` and `TimeControl` only when they are known.
  ///
  /// The values are plain text. Escaping `"` and `\` is the PGN writer's job.
  Map<String, String> toPgnHeaders() => {
    'Event': eventName ?? '?',
    'Site': '?',
    'Date': playedDate?.toPgn() ?? '????.??.??',
    'Round': '?',
    'White': whiteName ?? '?',
    'Black': blackName ?? '?',
    'Result': result.pgn,
    if (whiteRating != null) 'WhiteElo': '$whiteRating',
    if (blackRating != null) 'BlackElo': '$blackRating',
    if (timeControl?.toPgnTag() case final String tag) 'TimeControl': tag,
  };

  /// A JSON object for the draft store (`meta_json`). Unknown values are left
  /// out.
  Map<String, Object?> toJson() => {
    _kVersion: 1,
    if (whiteName != null) _kWhiteName: whiteName,
    if (blackName != null) _kBlackName: blackName,
    if (playerColor != null) _kPlayerColor: playerColor!.wireName,
    _kResult: result.pgn,
    if (playedDate != null) _kPlayedDate: playedDate!.toIso(),
    if (eventName != null) _kEventName: eventName,
    if (timeControl != null) _kTimeControl: timeControl!.toJson(),
    if (whiteRating != null) _kWhiteRating: whiteRating,
    if (blackRating != null) _kBlackRating: blackRating,
  };

  /// A copy with some fields replaced. Passing null clears a field; leaving
  /// an argument out keeps it.
  GameMetadata copyWith({
    Object? whiteName = _unset,
    Object? blackName = _unset,
    Object? playerColor = _unset,
    GameResult? result,
    Object? playedDate = _unset,
    Object? eventName = _unset,
    Object? timeControl = _unset,
    Object? whiteRating = _unset,
    Object? blackRating = _unset,
  }) {
    T? pick<T>(Object? value, T? current) =>
        identical(value, _unset) ? current : value as T?;
    return GameMetadata(
      whiteName: pick(whiteName, _whiteName),
      blackName: pick(blackName, _blackName),
      playerColor: pick(playerColor, this.playerColor),
      result: result ?? this.result,
      playedDate: pick(playedDate, this.playedDate),
      eventName: pick(eventName, _eventName),
      timeControl: pick(timeControl, this.timeControl),
      whiteRating: pick(whiteRating, this.whiteRating),
      blackRating: pick(blackRating, this.blackRating),
    );
  }

  /// The same game seen from the other chair: names and ratings change
  /// sides, and so does [playerColor] when [flipPlayerColor] is set. The
  /// result is left alone; it belongs to the board, not to a player.
  GameMetadata withSidesSwapped({bool flipPlayerColor = false}) => copyWith(
    whiteName: _blackName,
    blackName: _whiteName,
    whiteRating: blackRating,
    blackRating: whiteRating,
    playerColor: flipPlayerColor ? playerColor?.opposite : playerColor,
  );

  static final RegExp _whiteSpace = RegExp(r'\s+');
  static final RegExp _notNamePart = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  static String? _clean(String? text) {
    if (text == null) {
      return null;
    }
    final cleaned = text.replaceAll(_whiteSpace, ' ').trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  /// The parts of a name, lower-cased and sorted, so that word order and
  /// punctuation do not matter.
  static String _nameKey(String? name) {
    final parts =
        (name ?? '')
            .toLowerCase()
            .split(_notNamePart)
            .where((part) => part.isNotEmpty)
            .toList()
          ..sort();
    return parts.join(' ');
  }

  static String? _string(Object? value) => value is String ? value : null;

  static int? _int(Object? value) => switch (value) {
    final int number => number,
    final double number when number.isFinite => number.round(),
    final String text => int.tryParse(text.trim()),
    _ => null,
  };

  /// "1850" and lichess' provisional "1850?" are 1850; out of bounds is null.
  static int? _rating(String? text) {
    final digits = RegExp(r'^\d{1,5}').stringMatch(text ?? '');
    final rating = digits == null ? null : int.parse(digits);
    return rating != null && isPlausibleRating(rating) ? rating : null;
  }

  @override
  bool operator ==(Object other) =>
      other is GameMetadata &&
      other.whiteName == whiteName &&
      other.blackName == blackName &&
      other.playerColor == playerColor &&
      other.result == result &&
      other.playedDate == playedDate &&
      other.eventName == eventName &&
      other.timeControl == timeControl &&
      other.whiteRating == whiteRating &&
      other.blackRating == blackRating;

  @override
  int get hashCode => Object.hash(
    whiteName,
    blackName,
    playerColor,
    result,
    playedDate,
    eventName,
    timeControl,
    whiteRating,
    blackRating,
  );

  @override
  String toString() =>
      'GameMetadata(color: ${playerColor?.name}, result: ${result.pgn}, '
      'date: $playedDate, timeControl: $timeControl, '
      'names: ${[whiteName, blackName].nonNulls.length}/2, '
      'ratings: ${[whiteRating, blackRating].nonNulls.length}/2)';
}
