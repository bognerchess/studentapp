// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/game/time_control.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toPgnTag', () {
    String? tag(String? detail) =>
        TimeControl(TimeControlKind.other, detail: detail).toPgnTag();

    test('minutes plus increment become seconds', () {
      expect(tag('90+30'), '5400+30');
      expect(tag('5+0'), '300+0');
      expect(tag('5'), '300');
      expect(tag(' 15 + 10 '), '900+10');
      expect(tag('1.5+2'), '90+2');
      expect(tag('0,5'), '30');
    });

    test('anything else is passed through', () {
      expect(tag('40/7200:3600'), '40/7200:3600');
      expect(tag('2 h for 40 moves'), '2 h for 40 moves');
    });

    test('no detail, no tag', () {
      expect(tag(null), isNull);
      expect(tag('   '), isNull);
    });
  });

  group('fromPgnTag', () {
    test('a single period reads the way players write it', () {
      expect(
        TimeControl.fromPgnTag('600+5'),
        const TimeControl(TimeControlKind.rapid, detail: '10+5'),
      );
      expect(
        TimeControl.fromPgnTag('5400+30'),
        const TimeControl(TimeControlKind.classical, detail: '90+30'),
      );
      expect(
        TimeControl.fromPgnTag('300'),
        const TimeControl(TimeControlKind.blitz, detail: '5'),
      );
      expect(
        TimeControl.fromPgnTag('60+0'),
        const TimeControl(TimeControlKind.bullet, detail: '1+0'),
      );
      expect(
        TimeControl.fromPgnTag('90+2'),
        const TimeControl(TimeControlKind.blitz, detail: '1.5+2'),
      );
    });

    test('several periods keep the tag text', () {
      expect(
        TimeControl.fromPgnTag('40/7200:3600'),
        const TimeControl(TimeControlKind.classical, detail: '40/7200:3600'),
      );
      expect(
        TimeControl.fromPgnTag('40/5400+30:1800+30'),
        const TimeControl(
          TimeControlKind.classical,
          detail: '40/5400+30:1800+30',
        ),
      );
      expect(
        TimeControl.fromPgnTag('*180'),
        const TimeControl(TimeControlKind.blitz, detail: '*180'),
      );
    });

    test('free text is kept as "other"', () {
      expect(
        TimeControl.fromPgnTag('G/90'),
        const TimeControl(TimeControlKind.other, detail: 'G/90'),
      );
    });

    test('unknown and "no clock" are null', () {
      expect(TimeControl.fromPgnTag(null), isNull);
      expect(TimeControl.fromPgnTag(''), isNull);
      expect(TimeControl.fromPgnTag('?'), isNull);
      expect(TimeControl.fromPgnTag('-'), isNull);
    });

    test('tag to detail to tag is stable, odd seconds included', () {
      for (final tag in ['600+5', '5400+30', '300', '95+1', '15+0', '7+3']) {
        expect(TimeControl.fromPgnTag(tag)!.toPgnTag(), tag, reason: tag);
      }
    });
  });

  group('kindForDetail', () {
    test('FIDE bands on base plus 60 increments, bullet under 3 minutes', () {
      expect(TimeControl.kindForDetail('1+0'), TimeControlKind.bullet);
      expect(TimeControl.kindForDetail('2+1'), TimeControlKind.blitz);
      expect(TimeControl.kindForDetail('3+2'), TimeControlKind.blitz);
      expect(TimeControl.kindForDetail('10+0'), TimeControlKind.blitz);
      expect(TimeControl.kindForDetail('10+5'), TimeControlKind.rapid);
      expect(TimeControl.kindForDetail('15+10'), TimeControlKind.rapid);
      expect(TimeControl.kindForDetail('60'), TimeControlKind.classical);
      expect(TimeControl.kindForDetail('90+30'), TimeControlKind.classical);
    });

    test('is null when the text is not numbers', () {
      expect(TimeControl.kindForDetail(null), isNull);
      expect(TimeControl.kindForDetail(''), isNull);
      expect(TimeControl.kindForDetail('40/7200:3600'), isNull);
      expect(TimeControl.kindForDetail('quick'), isNull);
    });

    test('fromDetail', () {
      expect(
        TimeControl.fromDetail('15+10'),
        const TimeControl(TimeControlKind.rapid, detail: '15+10'),
      );
      expect(TimeControl.fromDetail('quick').kind, TimeControlKind.other);
    });
  });

  group('JSON and equality', () {
    test('round trip', () {
      for (final timeControl in const [
        TimeControl(TimeControlKind.rapid, detail: '15+10'),
        TimeControl(TimeControlKind.blitz),
      ]) {
        expect(TimeControl.fromJson(timeControl.toJson()), timeControl);
      }
    });

    test('tolerant reading', () {
      expect(
        TimeControl.fromJson('blitz'),
        const TimeControl(TimeControlKind.blitz),
      );
      expect(
        TimeControl.fromJson(const {'kind': 'armageddon'}),
        const TimeControl(TimeControlKind.other),
      );
      expect(
        TimeControl.fromJson(const {'kind': 'rapid', 'detail': 5}),
        const TimeControl(TimeControlKind.rapid),
      );
      expect(TimeControl.fromJson(null), isNull);
      expect(TimeControl.fromJson(3), isNull);
    });

    test('a blank detail equals no detail', () {
      expect(
        const TimeControl(TimeControlKind.rapid, detail: '  '),
        const TimeControl(TimeControlKind.rapid),
      );
      expect(
        const TimeControl(TimeControlKind.rapid, detail: ' 15+10 ').detail,
        '15+10',
      );
    });
  });
}
