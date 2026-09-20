// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

final GameMetadata full = GameMetadata(
  whiteName: 'Muster, Max',
  blackName: 'Beispiel, Bettina',
  playerColor: PlayerColor.black,
  result: GameResult.blackWins,
  playedDate: GameDate(2026, 9, 12),
  eventName: 'Vereinsmeisterschaft',
  timeControl: const TimeControl(TimeControlKind.classical, detail: '90+30'),
  whiteRating: 1712,
  blackRating: 1840,
);

void main() {
  group('the user\'s view', () {
    test('is derived from the colour played', () {
      expect(full.playerName, 'Beispiel, Bettina');
      expect(full.opponentName, 'Muster, Max');
      expect(full.playerRating, 1840);
      expect(full.opponentRating, 1712);
      expect(full.playerOutcome, PlayerOutcome.win);

      final asWhite = full.copyWith(playerColor: PlayerColor.white);
      expect(asWhite.opponentName, 'Beispiel, Bettina');
      expect(asWhite.playerRating, 1712);
      expect(asWhite.playerOutcome, PlayerOutcome.loss);
    });

    test('is unknown while the colour is unknown', () {
      final noColor = full.copyWith(playerColor: null);
      expect(noColor.playerName, isNull);
      expect(noColor.opponentName, isNull);
      expect(noColor.playerRating, isNull);
      expect(noColor.opponentRating, isNull);
      expect(noColor.playerOutcome, isNull);
      // The facts are still there.
      expect(noColor.whiteName, 'Muster, Max');
      expect(noColor.blackRating, 1840);
    });

    test('outcome: draw and unknown', () {
      expect(
        full.copyWith(result: GameResult.draw).playerOutcome,
        PlayerOutcome.draw,
      );
      expect(full.copyWith(result: GameResult.unknown).playerOutcome, isNull);
    });

    test('forPlayer puts the user on the right side', () {
      final asBlack = GameMetadata.forPlayer(
        playerColor: PlayerColor.black,
        playerName: 'Me',
        opponentName: 'Them',
        playerRating: 1500,
        opponentRating: 1600,
      );
      expect(asBlack.whiteName, 'Them');
      expect(asBlack.blackName, 'Me');
      expect(asBlack.whiteRating, 1600);
      expect(asBlack.blackRating, 1500);

      final asWhite = GameMetadata.forPlayer(
        playerColor: PlayerColor.white,
        playerName: 'Me',
        opponentName: 'Them',
        playerRating: 1500,
      );
      expect(asWhite.whiteName, 'Me');
      expect(asWhite.whiteRating, 1500);
      expect(asWhite.blackRating, isNull);
    });

    test('withSidesSwapped', () {
      final swapped = full.withSidesSwapped();
      expect(swapped.whiteName, 'Beispiel, Bettina');
      expect(swapped.blackRating, 1712);
      expect(swapped.playerColor, PlayerColor.black);
      expect(swapped.result, GameResult.blackWins);
      expect(
        full.withSidesSwapped(flipPlayerColor: true).playerName,
        full.playerName,
      );
    });
  });

  group('value semantics', () {
    test('equality and hashCode', () {
      final same = GameMetadata.fromJson(full.toJson());
      expect(same, full);
      expect(same.hashCode, full.hashCode);
      expect(full.copyWith(whiteRating: 1713), isNot(full));
      expect(const GameMetadata(), const GameMetadata());
      expect(const GameMetadata().isEmpty, isTrue);
      expect(full.isEmpty, isFalse);
    });

    test('text is trimmed, collapsed to one line, and blank is null', () {
      const messy = GameMetadata(
        whiteName: '  Max \n Muster ',
        blackName: '   ',
        eventName: '',
      );
      expect(messy.whiteName, 'Max Muster');
      expect(messy.blackName, isNull);
      expect(messy.eventName, isNull);
      expect(messy, const GameMetadata(whiteName: 'Max Muster'));
    });

    test('copyWith keeps, replaces and clears', () {
      expect(full.copyWith(), full);
      final changed = full.copyWith(
        eventName: null,
        playedDate: null,
        timeControl: null,
        blackRating: null,
        whiteName: 'Other',
        result: GameResult.draw,
      );
      expect(changed.eventName, isNull);
      expect(changed.playedDate, isNull);
      expect(changed.timeControl, isNull);
      expect(changed.blackRating, isNull);
      expect(changed.whiteName, 'Other');
      expect(changed.result, GameResult.draw);
      expect(changed.blackName, full.blackName);
      expect(changed.playerColor, full.playerColor);
    });

    test('toString does not contain names or the event', () {
      final text = full.toString();
      expect(text, isNot(contains('Muster')));
      expect(text, isNot(contains('Bettina')));
      expect(text, isNot(contains('Vereinsmeisterschaft')));
      expect(text, contains('0-1'));
    });
  });

  group('JSON', () {
    test('round trip through a string, full and empty', () {
      for (final metadata in [full, const GameMetadata()]) {
        final text = jsonEncode(metadata.toJson());
        expect(GameMetadata.fromJson(jsonDecode(text)), metadata);
      }
    });

    test('the stored shape', () {
      expect(full.toJson(), {
        'v': 1,
        'whiteName': 'Muster, Max',
        'blackName': 'Beispiel, Bettina',
        'playerColor': 'black',
        'result': '0-1',
        'playedDate': '2026-09-12',
        'eventName': 'Vereinsmeisterschaft',
        'timeControl': {'kind': 'classical', 'detail': '90+30'},
        'whiteRating': 1712,
        'blackRating': 1840,
      });
      expect(const GameMetadata().toJson(), {'v': 1, 'result': '*'});
    });

    test('unknown keys and values from a newer version are tolerated', () {
      final metadata = GameMetadata.fromJson({
        'v': 7,
        'whiteName': 'A',
        'playerColor': 'green',
        'result': 'abandoned',
        'timeControl': {'kind': 'hyperbullet', 'detail': '0.25', 'x': 1},
        'opening': {'eco': 'C50'},
        'tags': ['a', 'b'],
      });
      expect(metadata.whiteName, 'A');
      expect(metadata.playerColor, isNull);
      expect(metadata.result, GameResult.unknown);
      expect(
        metadata.timeControl,
        const TimeControl(TimeControlKind.other, detail: '0.25'),
      );
    });

    test('values of the wrong type read as not known', () {
      final metadata = GameMetadata.fromJson({
        'whiteName': 12,
        'blackName': null,
        'playedDate': 20260912,
        'eventName': ['x'],
        'timeControl': 3,
        'whiteRating': '1500',
        'blackRating': 1499.6,
        'result': 1,
      });
      expect(metadata.whiteName, isNull);
      expect(metadata.blackName, isNull);
      expect(metadata.playedDate, isNull);
      expect(metadata.eventName, isNull);
      expect(metadata.timeControl, isNull);
      expect(metadata.whiteRating, 1500);
      expect(metadata.blackRating, 1500);
      expect(metadata.result, GameResult.unknown);
    });

    test('an impossible date reads as not known', () {
      expect(
        GameMetadata.fromJson({'playedDate': '2026-02-30'}).playedDate,
        isNull,
      );
    });

    test('anything that is not an object gives empty metadata', () {
      for (final Object? json in [null, 'x', 3, <Object?>[], true]) {
        expect(GameMetadata.fromJson(json), const GameMetadata());
      }
    });
  });

  group('toPgnHeaders', () {
    test('the Seven Tag Roster comes first and in order', () {
      expect(full.toPgnHeaders().entries.map((e) => '${e.key}=${e.value}'), [
        'Event=Vereinsmeisterschaft',
        'Site=?',
        'Date=2026.09.12',
        'Round=?',
        'White=Muster, Max',
        'Black=Beispiel, Bettina',
        'Result=0-1',
        'WhiteElo=1712',
        'BlackElo=1840',
        'TimeControl=5400+30',
      ]);
    });

    test('unknown values are "?", the date "????.??.??", the result "*"', () {
      expect(const GameMetadata().toPgnHeaders(), {
        'Event': '?',
        'Site': '?',
        'Date': '????.??.??',
        'Round': '?',
        'White': '?',
        'Black': '?',
        'Result': '*',
      });
    });

    test('every result', () {
      String result(GameResult r) =>
          GameMetadata(result: r).toPgnHeaders()['Result']!;
      expect(result(GameResult.whiteWins), '1-0');
      expect(result(GameResult.blackWins), '0-1');
      expect(result(GameResult.draw), '1/2-1/2');
      expect(result(GameResult.unknown), '*');
    });

    test('only one rating known; a kind without numbers has no tag', () {
      final headers = const GameMetadata(
        blackRating: 1500,
        timeControl: TimeControl(TimeControlKind.rapid),
      ).toPgnHeaders();
      expect(headers.containsKey('WhiteElo'), isFalse);
      expect(headers['BlackElo'], '1500');
      expect(headers.containsKey('TimeControl'), isFalse);
    });

    test('dates are zero-padded', () {
      expect(
        GameMetadata(playedDate: GameDate(2026, 1, 5)).toPgnHeaders()['Date'],
        '2026.01.05',
      );
    });
  });

  group('fromPgnHeaders', () {
    test('reads a complete set of tags', () {
      final metadata = GameMetadata.fromPgnHeaders(
        full.toPgnHeaders(),
        playerColor: PlayerColor.black,
      );
      expect(metadata, full);
    });

    test('"?", "-" and blank are not known', () {
      final metadata = GameMetadata.fromPgnHeaders(const {
        'Event': '?',
        'Site': '?',
        'Date': '????.??.??',
        'Round': '-',
        'White': '?',
        'Black': ' ',
        'Result': '*',
        'WhiteElo': '?',
        'BlackElo': '-',
        'TimeControl': '?',
      });
      expect(metadata, const GameMetadata());
    });

    test('an empty map gives empty metadata', () {
      expect(GameMetadata.fromPgnHeaders(const {}), const GameMetadata());
    });

    test('partial and broken dates are not known, other separators are', () {
      GameDate? date(String text) =>
          GameMetadata.fromPgnHeaders({'Date': text}).playedDate;
      expect(date('2019.??.??'), isNull);
      expect(date('2019.05.??'), isNull);
      expect(date('????.05.12'), isNull);
      expect(date('2019.13.01'), isNull);
      expect(date('2019.02.29'), isNull);
      expect(date('yesterday'), isNull);
      expect(date('2019.05.12'), GameDate(2019, 5, 12));
      expect(date('2020.02.29'), GameDate(2020, 2, 29));
      expect(date('2019-05-12'), GameDate(2019, 5, 12));
      expect(date('2019/5/2'), GameDate(2019, 5, 2));
    });

    test('UTCDate stands in for a missing or partial Date', () {
      expect(
        GameMetadata.fromPgnHeaders(const {
          'Date': '2024.??.??',
          'UTCDate': '2024.03.02',
        }).playedDate,
        GameDate(2024, 3, 2),
      );
      expect(
        GameMetadata.fromPgnHeaders(const {
          'Date': '2024.03.01',
          'UTCDate': '2024.03.02',
        }).playedDate,
        GameDate(2024, 3, 1),
      );
    });

    test('results in the forms found in the wild', () {
      GameResult result(String text) =>
          GameMetadata.fromPgnHeaders({'Result': text}).result;
      expect(result('1-0'), GameResult.whiteWins);
      expect(result('0-1'), GameResult.blackWins);
      expect(result('1/2-1/2'), GameResult.draw);
      expect(result('½-½'), GameResult.draw);
      expect(result(' 1/2 - 1/2 '), GameResult.draw);
      expect(result('*'), GameResult.unknown);
      expect(result('+/-'), GameResult.unknown);
      expect(result(''), GameResult.unknown);
    });

    test('ratings: provisional marks are read, nonsense is dropped', () {
      final metadata = GameMetadata.fromPgnHeaders(const {
        'WhiteElo': '1850?',
        'BlackElo': '0',
      });
      expect(metadata.whiteRating, 1850);
      expect(metadata.blackRating, isNull);
      expect(
        GameMetadata.fromPgnHeaders(const {'WhiteElo': 'unr'}).whiteRating,
        isNull,
      );
      expect(
        GameMetadata.fromPgnHeaders(const {'WhiteElo': '99999'}).whiteRating,
        isNull,
      );
    });

    test('tag names match without regard to case', () {
      final metadata = GameMetadata.fromPgnHeaders(const {
        'white': 'A',
        'BLACK': 'B',
        'whiteelo': '1500',
      });
      expect(metadata.whiteName, 'A');
      expect(metadata.blackName, 'B');
      expect(metadata.whiteRating, 1500);
    });

    test('the colour is worked out from the account name', () {
      const headers = {'White': 'Muster, Max', 'Black': 'Beispiel, Bettina'};
      PlayerColor? color(String? name) =>
          GameMetadata.fromPgnHeaders(headers, playerName: name).playerColor;
      expect(color('Max Muster'), PlayerColor.white);
      expect(color('max  muster'), PlayerColor.white);
      expect(color('Bettina Beispiel'), PlayerColor.black);
      expect(color('Max'), isNull);
      expect(color(''), isNull);
      expect(color(null), isNull);
      // An explicit colour wins.
      expect(
        GameMetadata.fromPgnHeaders(
          headers,
          playerColor: PlayerColor.black,
          playerName: 'Max Muster',
        ).playerColor,
        PlayerColor.black,
      );
      // Both sides with the same name: no guess.
      expect(
        GameMetadata.fromPgnHeaders(const {
          'White': 'Max Muster',
          'Black': 'Muster, Max',
        }, playerName: 'Max Muster').playerColor,
        isNull,
      );
    });

    test('names with umlauts take part in the comparison', () {
      expect(
        const GameMetadata(
          whiteName: 'Müller, Jörg',
          blackName: 'Muller, Jorg',
        ).inferPlayerColor('Jörg Müller'),
        PlayerColor.white,
      );
    });
  });

  group('validate', () {
    final today = GameDate(2026, 9, 19);

    test('complete metadata is valid', () {
      final validation = full.validate(today: today);
      expect(validation.isValid, isTrue);
      expect(validation.issues, isEmpty);
    });

    test('only the colour is required', () {
      final validation = const GameMetadata().validate(today: today);
      expect(validation.isValid, isFalse);
      expect(validation.issues, const [
        MetadataIssue(MetadataField.playerColor, MetadataProblem.missing),
      ]);
      expect(validation.missing, {MetadataField.playerColor});
      expect(validation.invalid, isEmpty);
      expect(
        const GameMetadata(playerColor: PlayerColor.white)
            .validate(today: today)
            .isValid,
        isTrue,
      );
    });

    test('rating bounds are inclusive', () {
      bool ok(int? rating) => GameMetadata(
        playerColor: PlayerColor.white,
        whiteRating: rating,
      ).validate(today: today).isValid;
      expect(ok(null), isTrue);
      expect(ok(100), isTrue);
      expect(ok(3500), isTrue);
      expect(ok(99), isFalse);
      expect(ok(3501), isFalse);
      expect(ok(-5), isFalse);

      final both = const GameMetadata(
        playerColor: PlayerColor.white,
        whiteRating: 5,
        blackRating: 9000,
      ).validate(today: today);
      expect(both.invalid, {
        MetadataField.whiteRating,
        MetadataField.blackRating,
      });
      expect(
        both.problemOf(MetadataField.blackRating),
        MetadataProblem.invalid,
      );
      expect(both.problemOf(MetadataField.eventName), isNull);
    });

    test('a date may be tomorrow (UTC dates in online PGNs) but no later', () {
      MetadataValidation on(GameDate date) => GameMetadata(
        playerColor: PlayerColor.white,
        playedDate: date,
      ).validate(today: today);
      expect(on(GameDate(2026, 9, 19)).isValid, isTrue);
      expect(on(GameDate(2026, 9, 20)).isValid, isTrue);
      expect(on(GameDate(2026, 9, 21)).invalid, {MetadataField.playedDate});
      expect(on(GameDate(1972, 7, 11)).isValid, isTrue);
    });

    test('over-long text is invalid', () {
      final validation = GameMetadata(
        playerColor: PlayerColor.white,
        whiteName: 'a' * (GameMetadata.maxNameLength + 1),
        blackName: 'b' * GameMetadata.maxNameLength,
        eventName: 'e' * (GameMetadata.maxEventLength + 1),
        timeControl: TimeControl(
          TimeControlKind.other,
          detail: 't' * (TimeControl.maxDetailLength + 1),
        ),
      ).validate(today: today);
      expect(validation.invalid, {
        MetadataField.whiteName,
        MetadataField.eventName,
        MetadataField.timeControl,
      });
    });

    test('field helpers', () {
      expect(MetadataField.nameOf(PlayerColor.black), MetadataField.blackName);
      expect(
        MetadataField.ratingOf(PlayerColor.white),
        MetadataField.whiteRating,
      );
    });
  });
}
