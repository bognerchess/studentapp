// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

import 'package:bogner_chess/core/analytics/props_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('numbers, booleans and enum-like strings pass', () {
    expect(
      sanitizeEventProps({
        'plies': 80,
        'duration_s': 12.5,
        'cold_start': true,
        'source': 'pgn_paste',
        'reason': 'after-first-submit',
        'app': '1.2.0',
      }),
      {
        'plies': 80,
        'duration_s': 12.5,
        'cold_start': true,
        'source': 'pgn_paste',
        'reason': 'after-first-submit',
        'app': '1.2.0',
      },
    );
  });

  test('free text never passes', () {
    expect(
      sanitizeEventProps({
        'white': 'Hans Muster',
        'email': 'hans@example.test',
        'pgn': '1. e4 e5 2. Nf3',
        'san': 'Nf3',
        'error': 'FormatException: bad tag',
        'umlaut': 'schön',
        'empty': '',
        'long': 'a' * 41,
      }),
      isEmpty,
    );
  });

  test('a string of exactly 40 characters passes', () {
    expect(sanitizeEventProps({'k': 'a' * 40}), {'k': 'a' * 40});
  });

  test('null, NaN, infinity, lists, maps and objects are dropped', () {
    expect(
      sanitizeEventProps({
        'a': null,
        'b': double.nan,
        'c': double.infinity,
        'd': [1, 2],
        'e': {'x': 1},
        'f': DateTime(2026),
        'g': const Duration(seconds: 1),
      }),
      isEmpty,
    );
  });

  test('keys must be snake case and short', () {
    expect(
      sanitizeEventProps({
        'ok_key1': 1,
        'CamelCase': 1,
        '1st': 1,
        'with space': 1,
        'with-dash': 1,
        '': 1,
        'k' * 41: 1,
      }),
      {'ok_key1': 1},
    );
  });

  test('at most twelve properties, the first ones', () {
    final props = {for (var i = 0; i < 20; i++) 'p$i': i};
    final result = sanitizeEventProps(props);
    expect(result, hasLength(kMaxEventProps));
    expect(result.keys.first, 'p0');
    expect(result.keys.last, 'p11');
  });

  test('dropped properties do not count towards the cap', () {
    final props = <String, Object?>{
      for (var i = 0; i < 12; i++) 'text$i': 'Free Text',
      'kept': 1,
    };
    expect(sanitizeEventProps(props), {'kept': 1});
  });

  test('the largest possible result fits the 2 KB limit of the server', () {
    final props = {
      for (var i = 0; i < 12; i++)
        'k${'$i'.padLeft(2, '0')}${'x' * 37}': 'v' * 40,
    };
    final result = sanitizeEventProps(props);
    expect(result, hasLength(12));
    expect(utf8.encode(jsonEncode(result)).length, lessThan(2048));
  });
}
