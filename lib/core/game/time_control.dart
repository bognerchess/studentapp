// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/foundation.dart';

/// The pace of a game, the way players talk about it.
enum TimeControlKind {
  classical,
  rapid,
  blitz,
  bullet,

  /// Anything else: correspondence, no clock, a club's own format.
  other;

  /// The value stored in JSON. Never rename one; add new ones at will,
  /// readers map a name they do not know to [other].
  String get wireName => name;

  static TimeControlKind fromWireName(Object? value) {
    for (final kind in values) {
      if (kind.name == value) {
        return kind;
      }
    }
    return other;
  }
}

/// A game's time control: a [kind], and optionally the exact numbers as the
/// player would write them, minutes plus increment in seconds ("90+30").
@immutable
class TimeControl {
  const TimeControl(this.kind, {this._detail});

  /// Builds a time control from free text alone, with the kind worked out
  /// from the numbers where that is possible ([kindForDetail]) and
  /// [TimeControlKind.other] where it is not.
  factory TimeControl.fromDetail(String detail) => TimeControl(
    kindForDetail(detail) ?? TimeControlKind.other,
    detail: detail,
  );

  final TimeControlKind kind;
  final String? _detail;

  /// Free text such as "90+30" or "40/7200:3600". Never blank: a blank
  /// detail reads as null.
  String? get detail {
    final trimmed = _detail?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// The longest [detail] the validation accepts.
  static const int maxDetailLength = 40;

  // "90+30", "5", "1.5+2", "0,5 + 1": minutes, optionally plus an increment
  // in seconds.
  static final RegExp _minutesPlusIncrement = RegExp(
    r'^(\d{1,4}(?:[.,]\d{1,2})?)\s*(?:\+\s*(\d{1,3}))?$',
  );

  // One period of a PGN TimeControl tag: "5400", "5400+30", "40/7200",
  // "40/7200+30". Sandclock ("*180") is matched separately.
  static final RegExp _pgnPeriod = RegExp(r'^(?:(\d+)/)?(\d+)(?:\+(\d+))?$');

  /// Base time and increment in seconds when [detail] is in the simple
  /// "minutes+increment" form, otherwise null.
  ({int baseSeconds, int? incrementSeconds})? get _simple {
    final text = detail;
    if (text == null) {
      return null;
    }
    final match = _minutesPlusIncrement.firstMatch(text);
    if (match == null) {
      return null;
    }
    final minutes = double.parse(match.group(1)!.replaceAll(',', '.'));
    final increment = match.group(2);
    return (
      baseSeconds: (minutes * 60).round(),
      incrementSeconds: increment == null ? null : int.parse(increment),
    );
  }

  /// The value of the PGN `TimeControl` tag, or null when only the kind is
  /// known (the tag has no way to say "rapid").
  ///
  /// "90+30" becomes "5400+30", because the tag counts in seconds. Text in
  /// any other form is passed through as it is: it is either already in tag
  /// syntax ("40/7200:3600") or the best description there is.
  String? toPgnTag() {
    final simple = _simple;
    if (simple == null) {
      return detail;
    }
    final increment = simple.incrementSeconds;
    return increment == null
        ? '${simple.baseSeconds}'
        : '${simple.baseSeconds}+$increment';
  }

  /// Reads a PGN `TimeControl` tag. "?", "-" (no clock) and blank are null.
  ///
  /// A single period in seconds is turned into the way players write it
  /// ("600+5" becomes "10+5"); anything more complicated keeps the tag text
  /// as detail. The kind is estimated from the numbers.
  static TimeControl? fromPgnTag(String? tag) {
    final text = tag?.trim() ?? '';
    if (text.isEmpty || text == '?' || text == '-') {
      return null;
    }
    final estimate = _estimatePgnSeconds(text);
    final kind = estimate == null
        ? TimeControlKind.other
        : _kindForSeconds(estimate);

    final single = _pgnPeriod.firstMatch(text);
    if (single != null && single.group(1) == null) {
      final base = int.parse(single.group(2)!);
      final increment = single.group(3);
      final minutes = _formatMinutes(base);
      return TimeControl(
        kind,
        detail: increment == null ? minutes : '$minutes+$increment',
      );
    }
    return TimeControl(kind, detail: text);
  }

  /// The kind the numbers in [detail] point to, or null when [detail] is not
  /// in the simple "minutes+increment" form.
  ///
  /// The bands are FIDE's, on the time for a 60-move game (base plus 60
  /// increments): up to 10 minutes is blitz, under 60 minutes is rapid,
  /// above that classical. Under 3 minutes counts as bullet, which FIDE does
  /// not know but every player does.
  static TimeControlKind? kindForDetail(String? detail) {
    final simple = TimeControl(TimeControlKind.other, detail: detail)._simple;
    if (simple == null) {
      return null;
    }
    return _kindForSeconds(
      simple.baseSeconds + 60 * (simple.incrementSeconds ?? 0),
    );
  }

  static TimeControlKind _kindForSeconds(int seconds) {
    if (seconds < 180) {
      return TimeControlKind.bullet;
    }
    if (seconds <= 600) {
      return TimeControlKind.blitz;
    }
    if (seconds < 3600) {
      return TimeControlKind.rapid;
    }
    return TimeControlKind.classical;
  }

  /// Total thinking time for 60 moves over all periods of a tag, or null
  /// when the tag is not in PGN syntax.
  static int? _estimatePgnSeconds(String tag) {
    var total = 0;
    for (final period in tag.split(':')) {
      final text = period.trim();
      if (text.startsWith('*')) {
        final sandclock = int.tryParse(text.substring(1));
        if (sandclock == null) {
          return null;
        }
        total += sandclock;
        continue;
      }
      final match = _pgnPeriod.firstMatch(text);
      if (match == null) {
        return null;
      }
      final base = int.tryParse(match.group(2)!);
      final increment = int.tryParse(match.group(3) ?? '0');
      if (base == null || increment == null) {
        return null;
      }
      total += base + 60 * increment;
    }
    return total;
  }

  /// 600 is "10", 90 is "1.5", 95 is "1.58" (which [_simple] reads back as
  /// 95 seconds).
  static String _formatMinutes(int seconds) {
    if (seconds % 60 == 0) {
      return '${seconds ~/ 60}';
    }
    final text = (seconds / 60).toStringAsFixed(2);
    return text.replaceFirst(RegExp(r'0+$'), '');
  }

  Map<String, Object?> toJson() => {
    'kind': kind.wireName,
    if (detail != null) 'detail': detail,
  };

  /// Null when [json] is not a time control at all. A kind this version does
  /// not know reads as [TimeControlKind.other].
  static TimeControl? fromJson(Object? json) {
    if (json is String) {
      // Tolerated short form: just the kind.
      return TimeControl(TimeControlKind.fromWireName(json));
    }
    if (json is! Map) {
      return null;
    }
    final detail = json['detail'];
    return TimeControl(
      TimeControlKind.fromWireName(json['kind']),
      detail: detail is String ? detail : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TimeControl && other.kind == kind && other.detail == detail;

  @override
  int get hashCode => Object.hash(kind, detail);

  @override
  String toString() => detail == null
      ? 'TimeControl(${kind.name})'
      : 'TimeControl(${kind.name}, $detail)';
}
