// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/links/shared_pgn_source.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(PlatformSharedPgnSource.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final records = <LogRecord>[];

  void answer(Future<Object?> Function() reply) {
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return reply();
    });
  }

  setUp(() {
    calls.clear();
    records.clear();
    Log.sink = records.add;
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    Log.resetSink();
  });

  test('the default source is the platform one', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(sharedPgnSourceProvider),
      isA<PlatformSharedPgnSource>(),
    );
  });

  test('the channel name is the one the Swift side registers', () {
    // ios/Runner/SharedPgnInbox.swift has the same literal.
    expect(
      PlatformSharedPgnSource.channelName,
      'com.bognerchess.mobile/shared_pgn',
    );
    expect(PlatformSharedPgnSource.takeMethod, 'take');
  });

  test('take hands over the bytes and sends no argument', () async {
    final bytes = Uint8List.fromList('1. e4 e5'.codeUnits);
    answer(() async => bytes);
    expect(await const PlatformSharedPgnSource().take(), bytes);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'take');
    // Dart cannot name a file: there is nothing to traverse.
    expect(calls.single.arguments, isNull);
  });

  test('null when nothing waits', () async {
    answer(() async => null);
    expect(await const PlatformSharedPgnSource().take(), isNull);
    expect(records, isEmpty);
  });

  test('null without a native side', () async {
    expect(await const PlatformSharedPgnSource().take(), isNull);
    expect(records, isEmpty);
  });

  test('a native error is null and logs the code only', () async {
    answer(
      () async => throw PlatformException(
        code: 'noContainer',
        message: '/private/var/mobile/Containers/Shared/AppGroup/SECRET',
      ),
    );
    expect(await const PlatformSharedPgnSource().take(), isNull);
    expect(records, hasLength(1));
    expect(records.single.level, LogLevel.warning);
    expect(records.single.message, contains('noContainer'));
    expect(records.single.message, isNot(contains('SECRET')));
  });

  test('the no-op source never has anything', () async {
    expect(await const NoSharedPgnSource().take(), isNull);
  });
}
