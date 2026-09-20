// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/game/game_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only real calendar dates exist', () {
    expect(() => GameDate(2026, 2, 30), throwsArgumentError);
    expect(() => GameDate(2026, 0, 1), throwsArgumentError);
    expect(() => GameDate(2026, 13, 1), throwsArgumentError);
    expect(() => GameDate(2026, 1, 0), throwsArgumentError);
    expect(() => GameDate(0, 1, 1), throwsArgumentError);
    expect(GameDate(2024, 2, 29).day, 29);
  });

  test('ISO and PGN forms', () {
    final date = GameDate(2026, 1, 5);
    expect(date.toIso(), '2026-01-05');
    expect(date.toPgn(), '2026.01.05');
    expect(date.toString(), '2026-01-05');
    expect(GameDate.tryParseIso('2026-01-05'), date);
    expect(GameDate.tryParsePgn('2026.01.05'), date);
    expect(GameDate.tryParseIso('2026.01.05'), isNull);
    expect(GameDate.tryParseIso('2026-01-05T10:00:00Z'), isNull);
    expect(GameDate.tryParseIso(null), isNull);
    expect(GameDate.tryParsePgn('????.??.??'), isNull);
  });

  test('takes the calendar day of a DateTime as it stands', () {
    expect(
      GameDate.fromDateTime(DateTime(2026, 9, 19, 23, 59)),
      GameDate(2026, 9, 19),
    );
    expect(
      GameDate.fromDateTime(DateTime.utc(2026, 9, 19, 23, 59)),
      GameDate(2026, 9, 19),
    );
    expect(GameDate(2026, 9, 19).toLocalDateTime(), DateTime(2026, 9, 19));
  });

  test('ordering and equality', () {
    final dates = [GameDate(2026, 9, 19), GameDate(2025, 12, 31)]..sort();
    expect(dates.first, GameDate(2025, 12, 31));
    expect(GameDate(2026, 9, 20).isAfter(GameDate(2026, 9, 19)), isTrue);
    expect(GameDate(2026, 9, 19).isAfter(GameDate(2026, 9, 19)), isFalse);
    expect(GameDate(2026, 8, 31).isAfter(GameDate(2026, 9, 1)), isFalse);
    expect(GameDate(2026, 9, 19).hashCode, GameDate(2026, 9, 19).hashCode);
  });
}
