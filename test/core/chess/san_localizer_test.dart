// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/chess/san_localizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const Locale de = Locale('de');
const Locale en = Locale('en');

void main() {
  group('localizeSan', () {
    test('every piece letter', () {
      expect(localizeSan('Ke2', de), 'Ke2'); // König
      expect(localizeSan('Qd4', de), 'Dd4'); // Dame
      expect(localizeSan('Ra8', de), 'Ta8'); // Turm
      expect(localizeSan('Bf5', de), 'Lf5'); // Läufer
      expect(localizeSan('Nf3', de), 'Sf3'); // Springer
    });

    test('a pawn move has no piece letter and does not change', () {
      expect(localizeSan('e4', de), 'e4');
      expect(localizeSan('exd5', de), 'exd5');
      expect(localizeSan('b1', de), 'b1');
    });

    test('captures, checks and mate keep their signs', () {
      expect(localizeSan('Bxc4', de), 'Lxc4');
      expect(localizeSan('Qd4+', de), 'Dd4+');
      expect(localizeSan('Rxe8#', de), 'Txe8#');
      expect(localizeSan('Nxe4', de), 'Sxe4');
    });

    test('disambiguation by file or rank is kept', () {
      expect(localizeSan('Nbd7', de), 'Sbd7');
      expect(localizeSan('R1a3', de), 'T1a3');
      expect(localizeSan('Qh4xe1', de), 'Dh4xe1');
    });

    test('promotion converts the promoted piece', () {
      expect(localizeSan('e8=Q', de), 'e8=D');
      expect(localizeSan('e8=Q+', de), 'e8=D+');
      expect(localizeSan('axb8=N#', de), 'axb8=S#');
      expect(localizeSan('a1=R', de), 'a1=T');
      expect(localizeSan('h8=B', de), 'h8=L');
    });

    test('castling is the same in both languages', () {
      expect(localizeSan('O-O', de), 'O-O');
      expect(localizeSan('O-O-O', de), 'O-O-O');
      expect(localizeSan('O-O-O+', de), 'O-O-O+');
    });

    test('English and every other locale are the identity', () {
      expect(localizeSan('Nf3', en), 'Nf3');
      expect(localizeSan('e8=Q', en), 'e8=Q');
      expect(localizeSan('Qxd4+', const Locale('fr')), 'Qxd4+');
      expect(
        localizeSanInText('After Nxe4 comes Qd8+.', en),
        'After Nxe4 comes Qd8+.',
      );
    });

    test('a move label is rewritten token by token', () {
      expect(localizeSan('5. Nf3', de), '5. Sf3');
      expect(localizeSan('5... Qa5+', de), '5... Da5+');
      expect(localizeSan('1. e4', de), '1. e4');
    });

    test('something that is not a move is left alone', () {
      expect(localizeSan('Nxe', de), 'Nxe'); // a truncated token
      expect(localizeSan('', de), '');
      expect(localizeSan('Better', de), 'Better');
    });
  });

  group('localizeSanInText', () {
    test('the moves in a sentence, and nothing else', () {
      expect(
        localizeSanInText(
          'Nach Nf3 gewinnt Bxc4 einen Bauern, und Qd8+ setzt matt.',
          de,
        ),
        'Nach Sf3 gewinnt Lxc4 einen Bauern, und Dd8+ setzt matt.',
      );
    });

    test('German words that look like notation are untouched', () {
      const german =
          'Die Dame und der Turm decken den Bauer, der Springer und der '
          'Läufer stehen schlecht. Behalte die Kontrolle, Karte und Abfahrt.';
      expect(localizeSanInText(german, de), german);
    });

    test('a square named as a square is left alone', () {
      const german = 'Der Bauer auf f7 ist schwach, das Feld d4 gehört dir.';
      expect(localizeSanInText(german, de), german);
    });

    test('a move inside a word is not a move', () {
      expect(localizeSanInText('Nf3x', de), 'Nf3x');
      expect(localizeSanInText('xNf3', de), 'xNf3');
      expect(localizeSanInText('Variante3Nf3', de), 'Variante3Nf3');
    });

    test('a whole line of moves', () {
      expect(
        localizeSanInText('Qd8+ Kxd8 Bg5+ Kc7 Bd8#', de),
        'Dd8+ Kxd8 Lg5+ Kc7 Ld8#',
      );
      expect(
        localizeSanInText('1.e4 c6 2.d4 d5 3.Nc3 dxe4 4.Nxe4 Nf6', de),
        '1.e4 c6 2.d4 d5 3.Sc3 dxe4 4.Sxe4 Sf6',
      );
    });

    test('the coach text of a fixture, as the German reader sees it', () {
      expect(
        localizeSanInText(
          'Playing e5 opens the position. After dxe5 you are a pawn down. '
          'Nxe4 was simpler, and after Qxe4 you develop with Qd5 and Bf5.',
          de,
        ),
        'Playing e5 opens the position. After dxe5 you are a pawn down. '
        'Sxe4 was simpler, and after Dxe4 you develop with Dd5 and Lf5.',
      );
    });

    test('castling in a sentence', () {
      expect(
        localizeSanInText('Mit O-O bringst du den König in Sicherheit.', de),
        'Mit O-O bringst du den König in Sicherheit.',
      );
    });
  });
}
