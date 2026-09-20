// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/crash/crash_scrubber.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PGN tags and quoted text go, the kind of error stays', () {
    final scrubbed = scrubCrashText(
      'FormatException: unexpected token in [White "Muster, Hans"] '
      '[Black "Carlsen, Magnus"] near "1. e4 e5"',
    );
    expect(scrubbed, startsWith('FormatException: unexpected token'));
    for (final secret in ['Muster', 'Hans', 'Carlsen', 'Magnus', 'e4']) {
      expect(scrubbed, isNot(contains(secret)));
    }
  });

  test('move lists go, with and without numbers', () {
    for (final text in [
      'illegal move in 1. e4 e5 2. Nf3 Nc6 3. Bb5 a6',
      'illegal move in 1.e4 e5 2.Nf3 Nc6',
      'line: e4 e5 Nf3 Nc6 Bb5',
      'line: O-O O-O-O Qxe7+ Kh8 exd8=Q#',
      'after 12... Nxe4 13. Qd5!? Be6??',
      'at 23. Rxf7',
    ]) {
      final scrubbed = scrubCrashText(text);
      expect(scrubbed, contains('<moves>'), reason: text);
      expect(
        scrubbed,
        isNot(matches(RegExp('[KQRBN]?x?[a-h][1-8]'))),
        reason: '$text -> $scrubbed',
      );
    }
  });

  test('a FEN goes', () {
    final scrubbed = scrubCrashText(
      'bad position rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
    );
    expect(scrubbed, contains('<fen>'));
    expect(scrubbed, isNot(contains('rnbqkbnr')));
  });

  test('e-mail addresses and tokens go', () {
    final scrubbed = scrubCrashText(
      'user hans.muster+chess@example.ch token '
      'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.c2lnbmF0dXJlLXZhbHVl '
      'refresh 0123456789abcdef0123456789abcdef0123',
    );
    expect(scrubbed, 'user <email> token <token> refresh <token>');
  });

  test('ids in paths go, the shape of the path stays', () {
    expect(
      scrubCrashText('no route for /games/3f2a-77/review'),
      'no route for /games/:id/review',
    );
  });

  test('what a developer wrote stays readable', () {
    const text = 'Bad state: No element (flutter) in EventFlusher._flush';
    expect(scrubCrashText(text), text);
    expect(
      scrubCrashText('RangeError (index): Invalid value: 7 not in 0..3'),
      'RangeError (index): Invalid value: 7 not in 0..3',
    );
  });

  test('long text is cut', () {
    final scrubbed = scrubCrashText('x ' * 500);
    expect(scrubbed.length, lessThanOrEqualTo(kMaxCrashTextLength + 1));
  });

  test('never throws on odd input', () {
    for (final text in [
      '',
      '"',
      "'",
      '[',
      '1.',
      '@',
      '/games/',
      String.fromCharCode(0),
    ]) {
      expect(() => scrubCrashText(text), returnsNormally);
    }
  });
}
