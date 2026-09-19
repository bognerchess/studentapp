// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/links/incoming_link.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => Log.sink = (_) {});
  tearDown(Log.resetSink);

  group('decode', () {
    test('a URL', () {
      final link = PlatformIncomingLinkSource.decode({
        'kind': 'url',
        'url': 'com.bognerchess.mobile://games/abc/review',
      });
      expect(link, isA<IncomingUrl>());
      expect(
        (link! as IncomingUrl).url,
        'com.bognerchess.mobile://games/abc/review',
      );
    });

    test('a file', () {
      final link = PlatformIncomingLinkSource.decode({
        'kind': 'file',
        'bytes': Uint8List.fromList([0x31, 0x2E]),
      });
      expect((link! as IncomingFile).bytes, [0x31, 0x2E]);
    });

    test('file errors; an unknown reason counts as unreadable', () {
      IncomingFileFailureReason reasonOf(Object? reason) =>
          (PlatformIncomingLinkSource.decode({
                    'kind': 'fileError',
                    'reason': reason,
                  })!
                  as IncomingFileFailure)
              .reason;
      expect(reasonOf('tooLarge'), IncomingFileFailureReason.tooLarge);
      expect(reasonOf('unreadable'), IncomingFileFailureReason.unreadable);
      expect(reasonOf('somethingNew'), IncomingFileFailureReason.unreadable);
      expect(reasonOf(null), IncomingFileFailureReason.unreadable);
    });

    test('anything else is dropped, never thrown', () {
      for (final event in <Object?>[
        null,
        'com.bognerchess.mobile://games/abc',
        42,
        <Object?>[],
        <Object?, Object?>{},
        {'kind': 'url'},
        {'kind': 'url', 'url': 42},
        {'kind': 'file'},
        {'kind': 'file', 'bytes': 'text'},
        {
          'kind': 'file',
          'bytes': [1, 2, 3],
        },
        {'kind': 'path', 'path': '/etc/passwd'},
        {'url': 'x'},
      ]) {
        expect(PlatformIncomingLinkSource.decode(event), isNull);
      }
    });

    test('toString never shows a URL or content', () {
      expect(
        const IncomingUrl('com.bognerchess.mobile://games/SECRET').toString(),
        isNot(contains('SECRET')),
      );
      expect(
        IncomingFile(Uint8List.fromList('SECRET'.codeUnits)).toString(),
        'IncomingFile(6 bytes)',
      );
    });
  });

  group('the event channel', () {
    const channel = EventChannel(PlatformIncomingLinkSource.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockStreamHandler(channel, null));

    test('the default source is the platform one', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(incomingLinkSourceProvider),
        isA<PlatformIncomingLinkSource>(),
      );
    });

    test('delivers what the native side sends, in order, and skips what it '
        'does not understand', () async {
      messenger.setMockStreamHandler(
        channel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            // What was kept for a cold start comes first.
            events
              ..success({
                'kind': 'file',
                'bytes': Uint8List.fromList('1. e4'.codeUnits),
              })
              ..success({'kind': 'mystery'})
              ..success({'kind': 'url', 'url': 'com.bognerchess.mobile://new'})
              ..success({'kind': 'fileError', 'reason': 'tooLarge'})
              ..endOfStream();
          },
        ),
      );

      final links = await const PlatformIncomingLinkSource().links.toList();
      expect(links, hasLength(3));
      expect(links[0], isA<IncomingFile>());
      expect((links[1] as IncomingUrl).url, 'com.bognerchess.mobile://new');
      expect(
        (links[2] as IncomingFileFailure).reason,
        IncomingFileFailureReason.tooLarge,
      );
    });
  });
}
