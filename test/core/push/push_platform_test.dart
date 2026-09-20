// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/models/device_models.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/push/push_message.dart';
import 'package:bogner_chess/core/push/push_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The native-to-Dart contract of `ios/Runner/PushHandler.swift`, against
/// fake channels.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel(ChannelPushPlatform.methodChannelName);
  const events = EventChannel(ChannelPushPlatform.eventChannelName);
  const platform = ChannelPushPlatform();

  setUp(() => Log.sink = (_) {});
  tearDown(() {
    Log.resetSink();
    messenger
      ..setMockMethodCallHandler(methods, null)
      ..setMockStreamHandler(events, null);
  });

  const token =
      '00ff10a9b8c7d6e5f40123456789abcdef0123456789abcdef0123456789abcd';

  group('decode', () {
    test('a token', () {
      final event =
          ChannelPushPlatform.decode({
                'kind': 'token',
                'token': token,
                'environment': 'SANDBOX',
              })!
              as PushTokenEvent;
      expect(event.token, token);
      expect(event.environment, ApnsEnvironment.sandbox);
    });

    test('a token that is not lowercase hex, or without a known environment, '
        'is dropped', () {
      for (final event in [
        {
          'kind': 'token',
          'token': token.toUpperCase(),
          'environment': 'SANDBOX',
        },
        {'kind': 'token', 'token': '<00ff 10a9>', 'environment': 'SANDBOX'},
        {'kind': 'token', 'token': token, 'environment': 'STAGING'},
        {'kind': 'token', 'token': token},
        {'kind': 'token', 'environment': 'SANDBOX'},
      ]) {
        expect(ChannelPushPlatform.decode(event), isNull, reason: '$event');
      }
    });

    test('a token error', () {
      final event =
          ChannelPushPlatform.decode({
                'kind': 'tokenError',
                'code': 'NSCocoaErrorDomain#3010',
              })!
              as PushTokenErrorEvent;
      expect(event.code, 'NSCocoaErrorDomain#3010');
    });

    test('received and opened carry the parsed payload', () {
      const payload = {'type': 'analysis_ready', 'gameId': 'g', 'jobId': 'j'};
      final received =
          ChannelPushPlatform.decode({'kind': 'received', 'payload': payload})!
              as PushReceivedEvent;
      expect(
        received.message,
        const AnalysisReadyMessage(gameId: 'g', jobId: 'j'),
      );

      final opened =
          ChannelPushPlatform.decode({
                'kind': 'opened',
                'coldStart': true,
                'payload': payload,
              })!
              as PushOpenedEvent;
      expect(opened.message, received.message);
      expect(opened.coldStart, isTrue);
    });

    test(
      'an unknown type stays an event, so a tap still counts as handled',
      () {
        final opened =
            ChannelPushPlatform.decode({
                  'kind': 'opened',
                  'payload': {'type': 'weekly_summary'},
                })!
                as PushOpenedEvent;
        expect(opened.message, const UnknownPushMessage('weekly_summary'));
        expect(opened.coldStart, isFalse);
      },
    );

    test('anything else is dropped, never thrown', () {
      for (final event in <Object?>[
        null,
        'token',
        42,
        <Object?>[],
        <Object?, Object?>{},
        {'kind': 'somethingNew'},
        {'token': token},
      ]) {
        expect(ChannelPushPlatform.decode(event), isNull);
      }
    });
  });

  test('status and environment decoding fails closed', () {
    expect(
      ChannelPushPlatform.decodeStatus('authorized'),
      PushPermissionStatus.authorized,
    );
    expect(
      ChannelPushPlatform.decodeStatus('notDetermined'),
      PushPermissionStatus.notDetermined,
    );
    for (final value in <Object?>['denied', 'restricted', null, 3]) {
      expect(
        ChannelPushPlatform.decodeStatus(value),
        PushPermissionStatus.denied,
      );
    }
    expect(
      ChannelPushPlatform.decodeEnvironment('PRODUCTION'),
      ApnsEnvironment.production,
    );
    expect(ChannelPushPlatform.decodeEnvironment('development'), isNull);
  });

  test('the method channel: names, arguments and results', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return switch (call.method) {
        'permissionStatus' => 'notDetermined',
        'requestPermission' => true,
        'registerIfAuthorized' => 'authorized',
        'environment' => 'PRODUCTION',
        _ => null,
      };
    });

    expect(
      await platform.permissionStatus(),
      PushPermissionStatus.notDetermined,
    );
    expect(await platform.requestPermission(), isTrue);
    expect(
      await platform.registerIfAuthorized(),
      PushPermissionStatus.authorized,
    );
    expect(await platform.environment(), ApnsEnvironment.production);
    await platform.setVisibleGame('game-1');
    await platform.setVisibleGame(null);
    await platform.openSettings();

    expect(
      [for (final call in calls) '${call.method}(${call.arguments})'],
      [
        'permissionStatus(null)',
        'requestPermission(null)',
        'registerIfAuthorized(null)',
        'environment(null)',
        'setVisibleGame(game-1)',
        'setVisibleGame(null)',
        'openSettings(null)',
      ],
    );
  });

  test('the event channel delivers what was buffered natively, in order, and '
      'skips what it does not understand', () async {
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          // What PushHandler kept from before Dart listened: the tap that
          // started the app, then the token.
          sink
            ..success({
              'kind': 'opened',
              'coldStart': true,
              'payload': {'type': 'analysis_ready', 'gameId': 'g'},
            })
            ..success({'kind': 'fromTheFuture'})
            ..success({
              'kind': 'token',
              'token': token,
              'environment': 'SANDBOX',
            })
            ..endOfStream();
        },
      ),
    );

    final received = await platform.events.toList();
    expect(received, hasLength(2));
    expect((received[0] as PushOpenedEvent).coldStart, isTrue);
    expect(received[1], isA<PushTokenEvent>());
  });
}
