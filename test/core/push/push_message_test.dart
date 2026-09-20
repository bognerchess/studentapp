// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';
import 'dart:io';

import 'package:bogner_chess/core/push/push_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> fixture(String name) =>
      jsonDecode(File('test/fixtures/push/$name').readAsStringSync())
          as Map<String, dynamic>;

  test('the payload the backend sends', () {
    expect(
      PushMessage.parse(fixture('analysis_ready.apns')),
      const AnalysisReadyMessage(gameId: 'game-1', jobId: 'job-1'),
    );
  });

  test('the job id is optional', () {
    expect(
      PushMessage.parse({'type': 'analysis_ready', 'gameId': 'g'}),
      const AnalysisReadyMessage(gameId: 'g'),
    );
    expect(
      PushMessage.parse({'type': 'analysis_ready', 'gameId': 'g', 'jobId': 7}),
      const AnalysisReadyMessage(gameId: 'g'),
    );
  });

  test('an unknown type is kept as unknown, never thrown', () {
    expect(
      PushMessage.parse(fixture('unknown_type.apns')),
      const UnknownPushMessage('weekly_summary'),
    );
  });

  test('analysis_ready without a usable game id is unknown', () {
    for (final gameId in <Object?>[
      null,
      7,
      '',
      '../settings',
      'a/b',
      'a b',
      'a%2Fb',
      'x' * 129,
    ]) {
      expect(
        PushMessage.parse({'type': 'analysis_ready', 'gameId': gameId}),
        const UnknownPushMessage('analysis_ready'),
        reason: '$gameId',
      );
    }
  });

  test('anything that is not a payload is unknown', () {
    for (final payload in <Object?>[
      null,
      'analysis_ready',
      42,
      <Object?>[],
      <String, Object?>{},
      {'type': 7},
      {'gameId': 'g'},
    ]) {
      expect(PushMessage.parse(payload), const UnknownPushMessage(null));
    }
  });

  test('toString shows no ids', () {
    expect(
      const AnalysisReadyMessage(gameId: 'SECRET', jobId: 'SECRET').toString(),
      isNot(contains('SECRET')),
    );
  });
}
