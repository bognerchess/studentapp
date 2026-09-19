// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/foundation.dart';

/// A calendar date without a time or a time zone: the day a game was played.
///
/// A `DateTime` would drag a time zone along, and "midnight UTC" shown in
/// local time is the day before for half the world. This type cannot have
/// that bug. Only real calendar dates exist: `GameDate(2026, 2, 30)` throws,
/// the `tryParse` constructors return null instead.
@immutable
class GameDate implements Comparable<GameDate> {
  /// Throws an [ArgumentError] when the date does not exist.
  factory GameDate(int year, int month, int day) {
    final date = GameDate._maybe(year, month, day);
    if (date == null) {
      throw ArgumentError('not a calendar date: $year-$month-$day');
    }
    return date;
  }

  const GameDate._(this.year, this.month, this.day);

  /// The calendar day of [dateTime], in whatever zone it is expressed in.
  factory GameDate.fromDateTime(DateTime dateTime) =>
      GameDate._(dateTime.year, dateTime.month, dateTime.day);

  /// Today on this device's calendar.
  factory GameDate.today() => GameDate.fromDateTime(DateTime.now());

  final int year;
  final int month;
  final int day;

  static GameDate? _maybe(int year, int month, int day) {
    if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1) {
      return null;
    }
    // DateTime normalises an overflow (30 February becomes 2 March), which
    // is how a date that does not exist shows itself.
    final normalised = DateTime.utc(year, month, day);
    if (normalised.month != month || normalised.day != day) {
      return null;
    }
    return GameDate._(year, month, day);
  }

  static final RegExp _iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');
  static final RegExp _pgn = RegExp(r'^(\d{4})[./-](\d{1,2})[./-](\d{1,2})$');

  /// Parses `2026-09-19`. Null for anything else.
  static GameDate? tryParseIso(String? text) => _tryParse(_iso, text);

  /// Parses the PGN form `2026.09.19` (and, because files in the wild have
  /// them, `-` and `/` as separators). A partial date such as `2026.??.??`
  /// or `????.??.??` is null: the app knows a game's day or it does not.
  static GameDate? tryParsePgn(String? text) => _tryParse(_pgn, text);

  static GameDate? _tryParse(RegExp pattern, String? text) {
    if (text == null) {
      return null;
    }
    final match = pattern.firstMatch(text.trim());
    if (match == null) {
      return null;
    }
    return _maybe(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  /// `2026-09-19`.
  String toIso() => '${_pad(year, 4)}-${_pad(month, 2)}-${_pad(day, 2)}';

  /// `2026.09.19`, the form of the PGN `Date` tag.
  String toPgn() => '${_pad(year, 4)}.${_pad(month, 2)}.${_pad(day, 2)}';

  /// Local midnight of this day, for date pickers and date formatting.
  DateTime toLocalDateTime() => DateTime(year, month, day);

  static String _pad(int value, int width) =>
      value.toString().padLeft(width, '0');

  bool isAfter(GameDate other) => compareTo(other) > 0;

  @override
  int compareTo(GameDate other) {
    if (year != other.year) {
      return year.compareTo(other.year);
    }
    if (month != other.month) {
      return month.compareTo(other.month);
    }
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is GameDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
