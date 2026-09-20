// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:io' as io;

import 'package:bogner_chess/core/pgn/pgn_import.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

String fixture(String name) =>
    io.File('test/fixtures/pgn/$name').readAsStringSync();

PgnImportedGame single(String text) {
  final result = parsePgnText(text);
  expect(result.error, isNull, reason: '${result.error}');
  expect(result.games, hasLength(1));
  final game = result.games.single;
  if (game is PgnRejectedGame) fail('rejected: ${game.error}');
  return game as PgnImportedGame;
}

PgnImportError rejected(String text) {
  final result = parsePgnText(text);
  expect(result.error, isNull, reason: '${result.error}');
  expect(result.games, hasLength(1));
  final game = result.games.single;
  expect(game, isA<PgnRejectedGame>());
  return (game as PgnRejectedGame).error;
}

const _operaMoves =
    '1. e4 e5 2. Nf3 d6 3. d4 Bg4 4. dxe5 Bxf3 5. Qxf3 dxe5 6. Bc4 Nf6 '
    '7. Qb3 Qe7 8. Nc3 c6 9. Bg5 b5 10. Nxb5 cxb5 11. Bxb5+ Nbd7 12. O-O-O Rd8 '
    '13. Rxd7 Rxd7 14. Rd1 Qe6 15. Bxd7+ Nxd7 16. Qb8+ Nxb8 17. Rd8#';

void main() {
  group('fixtures', () {
    test('Lichess-style export: clocks and evals are not comments', () {
      final game = single(fixture('lichess_style.pgn'));
      expect(game.movetext, _operaMoves);
      expect(game.plyCount, 33);
      expect(game.result, '1-0');
      expect(
        game.finalFen,
        '1n1Rkb1r/p4ppp/4q3/4p1B1/4P3/8/PPP2PPP/2K5 b k - 1 17',
      );
      expect(game.headers['White'], 'anna_example');
      expect(game.headers['TimeControl'], '600+5');
      expect(game.headers.keys.first, 'Event');
      expect(game.warnings, isEmpty);
      expect(game.lastMove, const NormalMove(from: Square.d1, to: Square.d8));
    });

    test(
      'Chess.com-style export: "1... e5" numbering, move split over lines',
      () {
        final game = single(fixture('chesscom_style.pgn'));
        expect(game.movetext, '1. f3 e5 2. g4 Qh4#');
        expect(game.result, '0-1');
        expect(game.warnings, isEmpty);
        // The final position matches the one the site wrote into the tags.
        expect(game.finalFen, game.headers['CurrentPosition']);
      },
    );

    test('annotated OTB game: variations, comments, NAGs, glyphs, 0-0', () {
      final game = single(fixture('otb_annotated.pgn'));
      expect(
        game.movetext,
        '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 '
        '7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7 11. Nbd2 Bb7 12. Bc2 Re8 '
        '13. Nf1 Bf8 14. Ng3 g6',
      );
      expect(game.result, '1/2-1/2');
      expect(game.variationCount, 2, reason: 'nested ones are not counted');
      expect(game.commentCount, 5, reason: 'four in braces, one after ";"');
      expect(game.nagCount, 2, reason: '"!?" and "\$1"; "\$10" is in a line');
      expect(game.warnings, {
        PgnImportWarning.variationsRemoved,
        PgnImportWarning.commentsRemoved,
      });
      expect(game.headers['Site'], 'Zürich SUI');
      expect(game.headers['White'], 'Muster, Anna');
    });

    test('multi-game file', () {
      final result = parsePgnText(fixture('multi_game.pgn'));
      expect(result.error, isNull);
      expect(result.games, hasLength(3));
      expect(result.importable, hasLength(3));
      expect([for (final g in result.games) g.index], [0, 1, 2]);
      expect([for (final g in result.games) g.line], [1, 11, 21]);
      expect(
        [for (final g in result.games) g.headers['Round']],
        ['1', '2', '3'],
      );
      final [first, second, third] = result.importable;
      expect(first.movetext, '1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7#');
      expect(second.plyCount, 13);
      expect(second.result, '1-0');
      expect(third.result, '*');
      expect(third.movetext, endsWith('7. Bh4 b6'));
    });

    test('game from a set-up position is rejected as such', () {
      final error = rejected(fixture('fen_start.pgn'));
      expect(error.code, PgnImportErrorCode.customStartPosition);
      expect(error.line, 1);
    });

    test('broken game: the error names move, side, SAN and line', () {
      final error = rejected(fixture('broken.pgn'));
      expect(error.code, PgnImportErrorCode.illegalMove);
      expect(error.moveNumber, 13);
      expect(error.side, Side.white);
      expect(error.token, 'Rh5');
      expect(error.line, 12);
      expect(error.moveLabel, '13. Rh5');
      expect('$error', contains('13. Rh5'));
    });
  });

  group('text around the game', () {
    test('byte order mark', () {
      final game = single(
        '\ufeff${fixture('multi_game.pgn').split('\n\n[').first}',
      );
      expect(game.headers['Event'], 'Schulschach-Turnier');
      expect(game.plyCount, 7);
    });

    test('CRLF and lone CR line endings', () {
      final crlf = fixture('multi_game.pgn').replaceAll('\n', '\r\n');
      expect(parsePgnText(crlf).importable, hasLength(3));
      expect(parsePgnText(crlf).games.last.line, 21);
      final cr = fixture('multi_game.pgn').replaceAll('\n', '\r');
      expect(parsePgnText(cr).importable, hasLength(3));
    });

    test('junk before the first tag', () {
      final game = single(
        'Hi coach, here is my game from Saturday (round 3), see below:\n\n'
        '${fixture('chesscom_style.pgn')}',
      );
      expect(game.headers['Event'], 'Live Chess');
      expect(game.movetext, '1. f3 e5 2. g4 Qh4#');
      expect(game.line, 3);
    });

    test('junk before movetext without tags', () {
      final game = single('My game on 12.09.2026: 1. e4 e5 2. Nf3');
      expect(game.movetext, '1. e4 e5 2. Nf3');
      expect(game.headers, isEmpty);
    });

    test('movetext without any tags', () {
      final game = single('1. e4 e5 2. Nf3');
      expect(game.headers, isEmpty);
      expect(game.movetext, '1. e4 e5 2. Nf3');
      expect(game.plyCount, 3);
      expect(game.result, '*');
      expect(
        game.finalFen,
        'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2',
      );
    });

    test('movetext without move numbers, and numbers glued to moves', () {
      expect(single('e4 e5 Nf3 Nc6').movetext, '1. e4 e5 2. Nf3 Nc6');
      expect(single('1.e4 e5 2.Nf3 Nc6').movetext, '1. e4 e5 2. Nf3 Nc6');
      expect(single('1.e4 1...e5 2.Nf3').movetext, '1. e4 e5 2. Nf3');
      expect(single('1. e4 1\u2026 e5').movetext, '1. e4 e5');
    });

    test('escape lines starting with % are skipped', () {
      final game = single('% exported by SomeTool\n1. e4 e5\n%more\n2. Nf3');
      expect(game.movetext, '1. e4 e5 2. Nf3');
    });

    test('tags: escapes, several on one line, a broken tag line', () {
      final game = single(
        '[Event "The \\"Open\\" \\\\ 2026"] [Site "?"]\n'
        '[White "Broken\n'
        '[Black "B"]\n\n1. e4 *',
      );
      expect(game.headers, {
        'Event': r'The "Open" \ 2026',
        'Site': '?',
        'Black': 'B',
      });
    });

    test('headers are unmodifiable', () {
      final game = single('[White "A"]\n\n1. e4');
      expect(() => game.headers['White'] = 'B', throwsUnsupportedError);
    });
  });

  group('results', () {
    test('missing result', () {
      expect(single('[White "A"]\n[Black "B"]\n\n1. e4 e5').result, '*');
    });

    test('"*" in the movetext falls back to the tag', () {
      expect(single('[Result "1-0"]\n\n1. e4 e5 *').result, '1-0');
      expect(single('[Result "*"]\n\n1. e4 e5 *').result, '*');
    });

    test('the termination marker wins over the tag', () {
      expect(single('[Result "1-0"]\n\n1. e4 e5 0-1').result, '0-1');
    });

    test('the tag is used when the movetext has no marker', () {
      expect(single('[Result "1/2-1/2"]\n\n1. e4 e5').result, '1/2-1/2');
      expect(single('[Result "whatever"]\n\n1. e4 e5').result, '*');
    });

    test('draw without tags, which dartchess\'s own parser does not read', () {
      expect(single('1. e4 e5 1/2-1/2').result, '1/2-1/2');
      expect(single('1. e4 e5 \u00bd-\u00bd').result, '1/2-1/2');
    });

    test('a result inside a variation is not the game\'s result', () {
      final game = single('1. e4 e5 (1... c5 2. Nf3 1-0) 2. Nf3 0-1');
      expect(game.result, '0-1');
      expect(game.movetext, '1. e4 e5 2. Nf3');
    });
  });

  group('comments and annotations', () {
    test('brace comments over several lines, with tag-like text inside', () {
      final game = single(
        '1. e4 {a long\n\n[Event "not a tag"]\ncomment} e5 2. Nf3',
      );
      expect(game.movetext, '1. e4 e5 2. Nf3');
      expect(game.commentCount, 1);
    });

    test('line comments', () {
      final game = single('1. e4 e5 ; the open game 2. d4\n2. Nf3');
      expect(game.movetext, '1. e4 e5 2. Nf3');
      expect(game.warnings, {PgnImportWarning.commentsRemoved});
    });

    test('NAGs and glyphs', () {
      final game = single(r'1. e4! e5?! 2. Nf3!! $14 Nc6 $1 $36 3. Bb5 ?');
      expect(game.movetext, '1. e4 e5 2. Nf3 Nc6 3. Bb5');
      expect(game.nagCount, 7);
      expect(game.warnings, {PgnImportWarning.commentsRemoved});
    });

    test('check and mate marks are regenerated, not trusted', () {
      final game = single('1. e4+ e5 2. Bc4 Nc6# 3. Qh5 Nf6 4. Qxf7');
      expect(game.movetext, '1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7#');
    });

    test('clock, eval and arrow annotations alone give no warning', () {
      final game = single(
        '1. e4 {[%clk 0:03:00]} e5 {[%eval 0.3] [%clk 0:02:58]} '
        '2. Nf3 {[%csl Ge5][%cal Gf3e5]}',
      );
      expect(game.warnings, isEmpty);
      expect(single('1. e4 {[%clk 0:03:00] book} e5').commentCount, 1);
    });

    test('variations: nested, with comments inside', () {
      final game = single(
        '1. e4 (1. c4 {English} (1. Nf3)) e5 (1... c5) 2. Nf3',
      );
      expect(game.movetext, '1. e4 e5 2. Nf3');
      expect(game.variationCount, 2);
      expect(game.commentCount, 0);
      expect(game.warnings, {PgnImportWarning.variationsRemoved});
    });

    test('illegal moves inside a variation do not matter', () {
      expect(single('1. e4 (1. Qh5 Zz9 --) e5').movetext, '1. e4 e5');
    });

    test('evaluation symbols and "e.p." are tolerated', () {
      final game = single('1. e4 d5 2. e5 f5 3. exf6 e.p. +/- Nxf6 =');
      expect(game.movetext, '1. e4 d5 2. e5 f5 3. exf6 Nxf6');
    });
  });

  group('SAN', () {
    test('castling with zeros, with glyphs and with check', () {
      final game = single(
        '1. e4 e5 2. Nf3 Nf6 3. Bc4 Bc5 4. 0-0 0-0! 5. d3 d6',
      );
      expect(game.movetext, contains('4. O-O O-O 5.'));
      final long = single(
        '1. d4 d5 2. Nc3 Nc6 3. Bf4 Bf5 4. Qd2 Qd7 5. 0-0-0 O-O-O',
      );
      expect(long.movetext, endsWith('5. O-O-O O-O-O'));
    });

    test('castling that is not possible is an illegal move', () {
      final error = rejected('1. e4 e5 2. O-O');
      expect(error.code, PgnImportErrorCode.illegalMove);
      expect(error.token, 'O-O');
      expect(error.moveLabel, '2. O-O');
    });

    test('"Kg1" is not castling', () {
      final error = rejected('1. e4 e5 2. Nf3 Nf6 3. Bc4 Bc5 4. Kg1');
      expect(error.code, PgnImportErrorCode.illegalMove);
    });

    test('promotion with and without "="; missing promotion piece', () {
      const prefix = '1. a4 b5 2. axb5 a6 3. bxa6 Bb7 4. axb7 Nc6 5. ';
      expect(single('${prefix}bxa8=Q').sanMoves.last, 'bxa8=Q');
      expect(single('${prefix}bxa8N').sanMoves.last, 'bxa8=N');
      final error = rejected('${prefix}bxa8');
      expect(error.code, PgnImportErrorCode.illegalMove);
      expect(error.token, 'bxa8');
    });

    test('over-specified and long algebraic moves are normalised', () {
      expect(
        single('1. e2-e4 e7e5 2. Ng1f3 Nb8-c6').movetext,
        '1. e4 e5 2. Nf3 Nc6',
      );
      expect(single('1. Ngf3').movetext, '1. Nf3');
    });

    test('an ambiguous move is named as such', () {
      final error = rejected(
        '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 '
        '7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nd7',
      );
      expect(error.code, PgnImportErrorCode.ambiguousMove);
      expect(error.moveNumber, 10);
      expect(error.side, Side.black);
      expect(error.token, 'Nd7');
      expect(error.moveLabel, '10... Nd7');
    });

    test('a pinned piece does not make a move ambiguous', () {
      // The knight on c3 is pinned by the bishop on b4, so "Ne2" can only be
      // the knight from g1.
      final game = single('1. d4 e6 2. Nc3 Bb4 3. e4 Nf6 4. Ne2');
      expect(game.sanMoves.last, 'Ne2');
    });

    test('an illegal move: the glyph is not part of the reported SAN', () {
      final error = rejected('1. e4 e5 2. Ke3?? Nc6');
      expect(error.code, PgnImportErrorCode.illegalMove);
      expect(error.token, 'Ke3');
      expect(error.side, Side.white);
      expect(error.moveNumber, 2);
    });

    test('a word that is not a move', () {
      final error = rejected('1. e4 e5\n2. Nf3 Nc6\n3. Bb5 hello 4. Ba4');
      expect(error.code, PgnImportErrorCode.unreadableToken);
      expect(error.token, 'hello');
      expect(error.line, 3);
      expect(error.moveNumber, 3);
      expect(error.side, Side.black);
    });

    test('a typo is an error, never a skipped move', () {
      // dartchess's parser would drop "Nf9" and read 3. Bb5 as Black's move.
      final error = rejected('1. e4 e5 2. Nf3 Nf9 3. Bb5');
      expect(error.code, PgnImportErrorCode.unreadableToken);
      expect(error.token, 'Nf9');
    });

    test('null moves are not supported in the main line', () {
      expect(
        rejected('1. e4 -- 2. d4').code,
        PgnImportErrorCode.unreadableToken,
      );
    });

    test('moves after mate are illegal', () {
      final error = rejected('1. f3 e5 2. g4 Qh4# 3. a3');
      expect(error.code, PgnImportErrorCode.illegalMove);
      expect(error.moveLabel, '3. a3');
    });
  });

  group('rejections', () {
    test('FEN tag, SetUp tag, in any letter case', () {
      const fen = '8/8/8/4k3/8/8/4P3/4K3 w - - 0 1';
      for (final tags in [
        '[FEN "$fen"]\n[SetUp "1"]',
        '[FEN "$fen"]',
        '[Fen "$fen"]',
        '[SetUp "1"]',
      ]) {
        final error = rejected('$tags\n\n1. Kd2 Kd4');
        expect(
          error.code,
          PgnImportErrorCode.customStartPosition,
          reason: tags,
        );
      }
    });

    test('a FEN tag with the normal starting position is fine', () {
      final game = single('[SetUp "1"]\n[FEN "$kInitialFEN"]\n\n1. e4 e5');
      expect(game.plyCount, 2);
      expect(single('[SetUp "0"]\n\n1. e4').plyCount, 1);
    });

    test('variants', () {
      for (final variant in ['Chess960', 'Crazyhouse', 'Atomic', 'Horde']) {
        final error = rejected('[Variant "$variant"]\n\n1. e4 e5');
        expect(error.code, PgnImportErrorCode.unsupportedVariant);
        expect(error.token, variant);
      }
      expect(single('[Variant "Standard"]\n\n1. e4').plyCount, 1);
      expect(single('[Variant "standard"]\n\n1. e4').plyCount, 1);
      // Crazyhouse drops do not even read as moves; the variant is what
      // the user has to hear about.
      expect(
        rejected('[Variant "Crazyhouse"]\n\n1. e4 d5 2. exd5 Qxd5 3. P@e4')
            .code,
        PgnImportErrorCode.unsupportedVariant,
      );
    });

    test('tags without moves', () {
      final error = rejected('[Event "Empty"]\n[White "A"]\n\n*');
      expect(error.code, PgnImportErrorCode.noMoves);
      expect(rejected('[Event "Empty"]').code, PgnImportErrorCode.noMoves);
    });

    test('unterminated comment', () {
      final error = rejected('1. e4 e5\n2. Nf3 {never closed\n2... Nc6');
      expect(error.code, PgnImportErrorCode.unterminatedComment);
      expect(error.line, 2);
    });

    test('unterminated variation', () {
      final error = rejected('1. e4 e5\n\n2. Nf3 (2. f4 exf4\n3. Nf3 1-0');
      expect(error.code, PgnImportErrorCode.unterminatedVariation);
      expect(error.line, 3);
    });

    test('a stray ")" or "}" is ignored', () {
      expect(single('1. e4 ) e5 } 2. Nf3').movetext, '1. e4 e5 2. Nf3');
    });
  });

  group('whole-input errors', () {
    test('empty and blank', () {
      expect(parsePgnText('').error?.code, PgnImportErrorCode.empty);
      expect(parsePgnText(' \n\t\r\n').error?.code, PgnImportErrorCode.empty);
      expect(parsePgnText('\ufeff').error?.code, PgnImportErrorCode.empty);
    });

    test('text without a game', () {
      final result = parsePgnText('Hello, this is not a game of chess.');
      expect(result.error?.code, PgnImportErrorCode.noGames);
      expect(result.games, isEmpty);
    });

    test('too large', () {
      final result = parsePgnText('1. e4 e5 ' * 10, maxChars: 50);
      expect(result.error?.code, PgnImportErrorCode.tooLarge);
      expect(result.error?.limit, 50);
      expect(parsePgnText('1. e4 ', maxChars: 6).error, isNull);
      expect(kPgnMaxChars, 2 * 1024 * 1024);
    });

    test('too many games', () {
      final text = '[Event "x"]\n\n1. e4 e5 1-0\n\n' * 4;
      expect(parsePgnText(text, maxGames: 4).games, hasLength(4));
      final result = parsePgnText(text, maxGames: 3);
      expect(result.error?.code, PgnImportErrorCode.tooManyGames);
      expect(result.error?.limit, 3);
      expect(result.games, isEmpty);
      expect(kPgnMaxGames, 500);
    });

    test('500 games at the default limit are read in reasonable time', () {
      final text = '${fixture('lichess_style.pgn')}\n\n' * 500;
      final watch = Stopwatch()..start();
      final result = parsePgnText(text);
      expect(result.importable, hasLength(500));
      expect(watch.elapsed, lessThan(const Duration(seconds: 20)));
      expect(
        parsePgnText('$text\n1. e4').error?.code,
        PgnImportErrorCode.tooManyGames,
      );
    });
  });

  group('several games', () {
    test('a bad game does not hide the good ones', () {
      final text =
          '${fixture('broken.pgn')}\n${fixture('multi_game.pgn')}\n'
          '${fixture('fen_start.pgn')}';
      final result = parsePgnText(text);
      expect(result.games, hasLength(5));
      expect(result.importable, hasLength(3));
      expect(result.games.first, isA<PgnRejectedGame>());
      expect(result.games.last, isA<PgnRejectedGame>());
      expect(result.games[1].headers['White'], 'Carla Probe');
    });

    test('games without tags are split at the result', () {
      final result = parsePgnText('1. e4 e5 1-0\n\n1. d4 d5 0-1 1. c4 *');
      expect(result.importable.map((g) => g.movetext), [
        '1. e4 e5',
        '1. d4 d5',
        '1. c4',
      ]);
      expect(result.importable.map((g) => g.result), ['1-0', '0-1', '*']);
    });

    test('a comment after the result belongs to no game', () {
      final result = parsePgnText(
        '1. e4 e5 1-0 {White won on time}\n\n1. d4 *',
      );
      expect(result.importable, hasLength(2));
      expect(result.importable.first.commentCount, 0);
    });

    test('games without a blank line or a result between them', () {
      final result = parsePgnText(
        '[Event "A"]\n1. e4 e5\n[Event "B"]\n1. d4 d5 1-0',
      );
      expect(result.importable.map((g) => g.headers['Event']), ['A', 'B']);
    });

    test('two tag sections in a row: the first game has no moves', () {
      final result = parsePgnText(
        '[Event "A"]\n[White "x"]\n\n[Event "B"]\n\n1. d4 d5 1-0',
      );
      expect(result.games, hasLength(2));
      expect(
        (result.games.first as PgnRejectedGame).error.code,
        PgnImportErrorCode.noMoves,
      );
      expect(result.importable.single.headers, {'Event': 'B'});
    });
  });

  group('toPgn', () {
    test('writes tags, the clean main line and the result', () {
      final game = single(
        '[White "A \\"x\\""]\n[Result "*"]\n\n1. e4 {hi} e5 (1... c5) 1-0',
      );
      expect(
        game.toPgn(),
        '[White "A \\"x\\""]\n[Result "1-0"]\n\n1. e4 e5 1-0\n',
      );
    });

    test('its output reads back as the same game', () {
      for (final name in ['lichess_style.pgn', 'otb_annotated.pgn']) {
        final game = single(fixture(name));
        final again = single(game.toPgn());
        expect(again.movetext, game.movetext);
        expect(again.result, game.result);
        expect(again.finalFen, game.finalFen);
        expect(again.warnings, isEmpty);
        expect(again.headers['White'], game.headers['White']);
      }
    });

    test('dartchess reads the output as well', () {
      final game = single(fixture('otb_annotated.pgn'));
      final parsed = PgnGame.parsePgn(game.toPgn());
      expect(parsed.moves.mainline().map((n) => n.san), game.sanMoves);
      expect(parsed.headers['White'], 'Muster, Anna');
    });
  });
}
