// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

import 'package:bogner_chess/core/pgn/pgn_bytes.dart';
import 'package:bogner_chess/core/pgn/pgn_import.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pgn = '[White "Müller, Zoë"]\n\n1. e4 e5 *\n';

  test('UTF-8, with and without a byte order mark', () {
    expect(decodePgnBytes(utf8.encode(pgn)), pgn);
    final withBom = decodePgnBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(pgn)]);
    final game = parsePgnText(withBom).importable.single;
    expect(game.headers['White'], 'Müller, Zoë');
  });

  test('Latin-1 from an old database program', () {
    expect(decodePgnBytes(latin1.encode(pgn)), pgn);
  });

  test('UTF-16 with a byte order mark, both byte orders', () {
    final le = [
      0xFF,
      0xFE,
      for (final u in pgn.codeUnits) ...[u & 0xFF, u >> 8],
    ];
    final be = [
      0xFE,
      0xFF,
      for (final u in pgn.codeUnits) ...[u >> 8, u & 0xFF],
    ];
    expect(decodePgnBytes(le), pgn);
    expect(decodePgnBytes(be), pgn);
  });

  test('empty and tiny inputs', () {
    expect(decodePgnBytes(const []), '');
    expect(decodePgnBytes(const [0x31]), '1');
  });
}
