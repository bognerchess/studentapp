// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:bogner_chess/app.dart';
import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/links/incoming_link.dart';
import 'package:bogner_chess/core/links/incoming_link_notices.dart';
import 'package:bogner_chess/core/links/incoming_link_service.dart';
import 'package:bogner_chess/core/links/link_target.dart';
import 'package:bogner_chess/core/links/shared_pgn_source.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/ui/widgets/not_found_screen.dart';
import 'package:bogner_chess/features/import/domain/pending_import.dart';
import 'package:bogner_chess/features/import/ui/import_screen.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

const _s = kAppLinkScheme;

String fixture(String name) =>
    io.File('test/fixtures/pgn/$name').readAsStringSync();

Uint8List fixtureBytes(String name) =>
    io.File('test/fixtures/pgn/$name').readAsBytesSync();

Finder byKey(String key) => find.byKey(ValueKey(key));

/// Stands in for the native side. Like the real one, it keeps what is added
/// before anybody listens and delivers it first.
class FakeLinkSource implements IncomingLinkSource {
  // Closed by a tear-down in Harness.create.
  // ignore: close_sinks
  final StreamController<IncomingLink> controller =
      StreamController<IncomingLink>();
  int listens = 0;

  @override
  Stream<IncomingLink> get links {
    listens++;
    return controller.stream;
  }
}

class FakeSharedPgnSource implements SharedPgnSource {
  FakeSharedPgnSource(this.waiting);

  Uint8List? waiting;
  int calls = 0;

  @override
  Future<Uint8List?> take() async {
    calls++;
    final bytes = waiting;
    waiting = null;
    return bytes;
  }
}

/// The app as `main.dart` runs it: one container, the link service started
/// before the first frame.
class Harness {
  Harness._(this.source, this.container);

  factory Harness.create({AuthState? auth, SharedPgnSource? sharedPgn}) {
    final source = FakeLinkSource();
    final container = ProviderContainer(
      overrides: [
        envProvider.overrideWithValue(testEnv()),
        appInfoProvider.overrideWith(
          (ref) async => const AppInfo(version: '1.2.3', buildNumber: '45'),
        ),
        authStateProvider.overrideWith(
          () => TestAuthNotifier(auth ?? const SignedIn(kFakeAuthSub)),
        ),
        ...backendOverrides(),
        incomingLinkSourceProvider.overrideWithValue(source),
        if (sharedPgn != null)
          sharedPgnSourceProvider.overrideWithValue(sharedPgn),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(source.controller.close);
    return Harness._(source, container);
  }

  final FakeLinkSource source;
  final ProviderContainer container;

  IncomingLinkService get service =>
      container.read(incomingLinkServiceProvider);
  GoRouter get router => container.read(routerProvider);
  Uri get uri => router.routerDelegate.currentConfiguration.uri;
  String get path => uri.path;
  String? get pending => container.read(pendingImportProvider);

  void signIn() =>
      (container.read(authStateProvider.notifier) as TestAuthNotifier).set(
        const SignedIn(kFakeAuthSub),
      );

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = kIphone17Pro * 3;
    tester.platformDispatcher.localesTestValue = [locale];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BognerChessApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// A running app with the service listening, as after a normal start.
  Future<void> pumpStarted(WidgetTester tester, {Locale? locale}) async {
    service.start();
    await pump(tester, locale: locale ?? const Locale('en'));
  }

  Future<void> send(WidgetTester tester, IncomingLink link) async {
    source.controller.add(link);
    await tester.pumpAndSettle();
  }
}

String importFieldText(WidgetTester tester) =>
    tester.widget<TextField>(byKey('import-field')).controller!.text;

void main() {
  final records = <LogRecord>[];
  setUp(() {
    records.clear();
    Log.sink = records.add;
  });
  tearDown(Log.resetSink);

  group('a document, app running', () {
    testWidgets('lands on the import screen with the text filled in', (
      tester,
    ) async {
      final h = Harness.create();
      await h.pumpStarted(tester);
      expect(h.path, AppRoutes.games);

      await h.send(tester, IncomingFile(fixtureBytes('chesscom_style.pgn')));

      expect(h.path, AppRoutes.newGameImport);
      expect(find.byType(ImportScreen), findsOneWidget);
      expect(importFieldText(tester), fixture('chesscom_style.pgn'));
      expect(byKey('import-preview'), findsOneWidget);
      // Taken once: opening the screen by hand later starts empty.
      expect(h.pending, isNull);
    });

    testWidgets('back from there leads to the New game tab', (tester) async {
      final h = Harness.create();
      await h.pumpStarted(tester);
      await h.send(tester, IncomingFile(fixtureBytes('chesscom_style.pgn')));

      h.router.pop();
      await tester.pumpAndSettle();
      expect(h.path, AppRoutes.newGame);
    });

    testWidgets('a second document replaces the first', (tester) async {
      final h = Harness.create();
      await h.pumpStarted(tester);
      await h.send(tester, IncomingFile(fixtureBytes('chesscom_style.pgn')));
      await h.send(tester, IncomingFile(utf8.encode('1. d4 d5 2. c4')));

      expect(h.path, AppRoutes.newGameImport);
      expect(importFieldText(tester), '1. d4 d5 2. c4');
      expect(find.byType(ImportScreen), findsOneWidget);
    });

    testWidgets('Latin-1 and UTF-16 files are decoded', (tester) async {
      final h = Harness.create();
      await h.pumpStarted(tester);
      await h.send(
        tester,
        IncomingFile(
          Uint8List.fromList(latin1.encode('[White "Müller"]\n\n1. e4 e5')),
        ),
      );
      expect(importFieldText(tester), contains('Müller'));

      const text = '1. c4 e5';
      final utf16 = <int>[0xFF, 0xFE];
      for (final unit in text.codeUnits) {
        utf16
          ..add(unit & 0xFF)
          ..add(unit >> 8);
      }
      await h.send(tester, IncomingFile(Uint8List.fromList(utf16)));
      expect(importFieldText(tester), text);
    });

    testWidgets('text that is no PGN: the import screen explains it', (
      tester,
    ) async {
      final h = Harness.create();
      await h.pumpStarted(tester);
      await h.send(
        tester,
        IncomingFile(utf8.encode('Dear Sir, please find attached my invoice.')),
      );
      expect(h.path, AppRoutes.newGameImport);
      expect(byKey('import-error'), findsOneWidget);
      expect(byKey('import-preview'), findsNothing);
    });
  });

  group('a document, refused', () {
    testWidgets('larger than 2 MiB: a message, nothing imported', (
      tester,
    ) async {
      final h = Harness.create();
      await h.pumpStarted(tester);
      final huge = Uint8List(kIncomingFileMaxBytes + 1)
        ..fillRange(0, kIncomingFileMaxBytes + 1, 0x20);
      await h.send(tester, IncomingFile(huge));

      expect(h.path, AppRoutes.games);
      expect(h.pending, isNull);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('At most 2 MB'), findsOneWidget);
    });

    testWidgets('exactly 2 MiB is accepted', (tester) async {
      final h = Harness.create();
      await h.pumpStarted(tester);
      final bytes = Uint8List(kIncomingFileMaxBytes)
        ..fillRange(0, kIncomingFileMaxBytes, 0x20);
      h.source.controller.add(IncomingFile(bytes));
      // No settle: the screen parses a text of this size in an isolate.
      await tester.pump();
      expect(h.path, AppRoutes.newGameImport);
      expect(find.byType(SnackBar), findsNothing);
    });

    final binaries = <String, List<int>>{
      'a PNG named .pgn': [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0,
        0,
      ],
      'a zip': [0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x00, 0x00],
      'NUL bytes inside text': [
        ...utf8.encode('1. e4'),
        0,
        ...utf8.encode('e5'),
      ],
      'an empty file': [],
    };
    binaries.forEach((name, bytes) {
      testWidgets('$name: could not be read', (tester) async {
        final h = Harness.create();
        await h.pumpStarted(tester);
        await h.send(tester, IncomingFile(Uint8List.fromList(bytes)));

        expect(h.path, AppRoutes.games);
        expect(h.pending, isNull);
        expect(find.text('This file could not be read.'), findsOneWidget);
      });
    });

    testWidgets('failures reported by the native reader', (tester) async {
      final h = Harness.create();
      await h.pumpStarted(tester);
      await h.send(
        tester,
        const IncomingFileFailure(IncomingFileFailureReason.unreadable),
      );
      expect(find.text('This file could not be read.'), findsOneWidget);

      await h.send(
        tester,
        const IncomingFileFailure(IncomingFileFailureReason.tooLarge),
      );
      expect(find.textContaining('At most 2 MB'), findsOneWidget);
      expect(find.text('This file could not be read.'), findsNothing);
      expect(h.path, AppRoutes.games);
    });

    testWidgets('in German', (tester) async {
      final h = Harness.create();
      await h.pumpStarted(tester, locale: const Locale('de'));
      await h.send(
        tester,
        const IncomingFileFailure(IncomingFileFailureReason.unreadable),
      );
      expect(
        find.text('Diese Datei konnte nicht gelesen werden.'),
        findsOneWidget,
      );
    });
  });

  group('cold start', () {
    testWidgets('a document that arrived before the first frame', (
      tester,
    ) async {
      final h = Harness.create();
      // The native side already holds the event when Dart starts listening.
      h.source.controller.add(IncomingFile(fixtureBytes('lichess_style.pgn')));
      h.service.start();
      await tester.idle();
      expect(h.pending, isNotNull);

      await h.pump(tester);

      expect(h.path, AppRoutes.newGameImport);
      expect(importFieldText(tester), fixture('lichess_style.pgn'));
      expect(h.pending, isNull);

      // The stack below is complete: back leads into the app.
      h.router.pop();
      await tester.pumpAndSettle();
      expect(h.path, AppRoutes.newGame);
    });

    testWidgets('an app link that arrived before the first frame', (
      tester,
    ) async {
      final h = Harness.create();
      h.source.controller.add(const IncomingUrl('$_s://games/abc/review'));
      h.service.start();
      await tester.idle();
      await h.pump(tester);

      expect(h.path, AppRoutes.gameReview('abc'));
    });

    testWidgets('a refused document: the message waits for the first frame', (
      tester,
    ) async {
      final h = Harness.create();
      h.source.controller.add(
        const IncomingFileFailure(IncomingFileFailureReason.tooLarge),
      );
      h.service.start();
      await tester.idle();
      await h.pump(tester);

      expect(h.path, AppRoutes.games);
      expect(find.textContaining('At most 2 MB'), findsOneWidget);
      expect(h.container.read(incomingLinkNoticeProvider), isNull);
    });
  });

  group('signed out', () {
    testWidgets('the document waits and arrives after signing in', (
      tester,
    ) async {
      final h = Harness.create(auth: const SignedOut());
      await h.pumpStarted(tester);
      expect(h.path, AppRoutes.signIn);

      await h.send(tester, IncomingFile(fixtureBytes('chesscom_style.pgn')));

      expect(h.path, AppRoutes.signIn);
      expect(h.uri.queryParameters[AppRoutes.fromParam], '/new/import');
      expect(find.byType(ImportScreen), findsNothing);
      expect(h.pending, fixture('chesscom_style.pgn'));

      h.signIn();
      await tester.pumpAndSettle();

      expect(h.path, AppRoutes.newGameImport);
      expect(importFieldText(tester), fixture('chesscom_style.pgn'));
      expect(h.pending, isNull);
    });

    testWidgets('cold start, signed out, then signing in', (tester) async {
      final h = Harness.create(auth: const SignedOut());
      h.source.controller.add(IncomingFile(utf8.encode('1. e4 e5 2. Nf3')));
      h.service.start();
      await tester.idle();
      await h.pump(tester);
      expect(h.path, AppRoutes.signIn);

      h.signIn();
      await tester.pumpAndSettle();
      expect(h.path, AppRoutes.newGameImport);
      expect(importFieldText(tester), '1. e4 e5 2. Nf3');
    });

    testWidgets('an app link arrives after signing in', (tester) async {
      final h = Harness.create(auth: const SignedOut());
      await h.pumpStarted(tester);
      await h.send(tester, const IncomingUrl('$_s://games/abc/review'));
      expect(h.path, AppRoutes.signIn);

      h.signIn();
      await tester.pumpAndSettle();
      expect(h.path, AppRoutes.gameReview('abc'));
    });

    testWidgets('a refused document still says so', (tester) async {
      final h = Harness.create(auth: const SignedOut());
      await h.pumpStarted(tester);
      await h.send(
        tester,
        const IncomingFileFailure(IncomingFileFailureReason.unreadable),
      );
      expect(h.path, AppRoutes.signIn);
      expect(find.text('This file could not be read.'), findsOneWidget);
    });
  });

  group('URLs', () {
    testWidgets('an app link opens its location with the stack below it', (
      tester,
    ) async {
      final h = Harness.create();
      await h.pumpStarted(tester);
      await h.send(tester, const IncomingUrl('$_s://games/abc/review'));
      expect(h.path, AppRoutes.gameReview('abc'));

      h.router.pop();
      await tester.pumpAndSettle();
      expect(h.path, AppRoutes.game('abc'));
    });

    testWidgets('the OIDC redirect changes nothing and is not logged', (
      tester,
    ) async {
      final h = Harness.create();
      await h.pumpStarted(tester);
      h.router.go(AppRoutes.settingsAbout);
      await tester.pumpAndSettle();
      records.clear();

      await h.send(
        tester,
        const IncomingUrl('$_s:/oauthredirect?code=SECRETCODE&state=xyz'),
      );

      expect(h.path, AppRoutes.settingsAbout);
      expect(h.pending, isNull);
      expect(find.byType(SnackBar), findsNothing);
      expect(records, isEmpty);
    });

    testWidgets('signed out, the OIDC redirect leaves the sign-in alone', (
      tester,
    ) async {
      final h = Harness.create(auth: const SignedOut());
      await h.pumpStarted(tester);
      final before = h.uri;
      await h.send(tester, const IncomingUrl('$_s:/oauthredirect?code=abc'));
      expect(h.uri, before);
    });

    for (final url in [
      '$_s://nowhere',
      '$_s://sign-in?from=https://evil.example',
      '$_s://games/..%2F..%2Fsettings/review',
      'https://evil.example/games/abc',
      'file:///etc/passwd',
      'file:///private/var/mobile/Containers/Shared/AppGroup/x/shared.pgn',
      'not a url at all',
      '',
    ]) {
      testWidgets('ignored: "$url"', (tester) async {
        final h = Harness.create();
        await h.pumpStarted(tester);
        h.router.go(AppRoutes.settings);
        await tester.pumpAndSettle();

        await h.send(tester, IncomingUrl(url));

        expect(h.path, AppRoutes.settings);
        expect(h.pending, isNull);
        expect(find.byType(NotFoundScreen), findsNothing);
        // The reason is logged, the URL is not.
        expect(
          records.map((r) => r.message).join('\n'),
          isNot(contains('evil')),
        );
      });
    }

    testWidgets('no URL and no content ever reaches the log', (tester) async {
      final h = Harness.create();
      await h.pumpStarted(tester);
      await h.send(tester, const IncomingUrl('$_s://games/PRIVATEID/review'));
      await h.send(tester, IncomingFile(utf8.encode('1. e4 {PRIVATENOTE} e5')));
      final log = records
          .map((r) => '${r.message} ${r.error ?? ''}')
          .join('\n');
      expect(log, isNot(contains('PRIVATEID')));
      expect(log, isNot(contains('PRIVATENOTE')));
    });
  });

  group('the share extension hand-off', () {
    Future<void> resume(WidgetTester tester) async {
      // What iOS reports when the user comes back to the app.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    testWidgets('without a native side the link does nothing', (tester) async {
      // The default source talks to a method channel nobody answers here.
      final h = Harness.create();
      await h.pumpStarted(tester);
      await h.send(tester, const IncomingUrl('$_s://shared-pgn'));
      await resume(tester);
      expect(h.path, AppRoutes.games);
      expect(h.pending, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing waiting: start, link and resume change nothing', (
      tester,
    ) async {
      final shared = FakeSharedPgnSource(null);
      final h = Harness.create(sharedPgn: shared);
      await h.pumpStarted(tester);
      expect(shared.calls, 1);
      await h.send(tester, const IncomingUrl('$_s://shared-pgn'));
      await resume(tester);
      expect(shared.calls, 3);
      expect(h.path, AppRoutes.games);
      expect(h.pending, isNull);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('warm, through the link: the same way as a document', (
      tester,
    ) async {
      final shared = FakeSharedPgnSource(null);
      final h = Harness.create(sharedPgn: shared);
      await h.pumpStarted(tester);
      expect(shared.calls, 1);

      shared.waiting = fixtureBytes('lichess_style.pgn');
      await h.send(tester, const IncomingUrl('$_s://shared-pgn'));

      expect(shared.calls, 2);
      expect(h.path, AppRoutes.newGameImport);
      expect(importFieldText(tester), fixture('lichess_style.pgn'));
      expect(h.pending, isNull);

      // The same link again: the file is gone, nothing changes.
      await h.send(tester, const IncomingUrl('$_s://shared-pgn'));
      expect(shared.calls, 3);
      expect(importFieldText(tester), fixture('lichess_style.pgn'));

      // Back leads into the app, as for a document.
      h.router.pop();
      await tester.pumpAndSettle();
      expect(h.path, AppRoutes.newGame);
    });

    testWidgets('warm, without the link: found on the way to the foreground', (
      tester,
    ) async {
      final shared = FakeSharedPgnSource(null);
      final h = Harness.create(sharedPgn: shared);
      await h.pumpStarted(tester);

      shared.waiting = fixtureBytes('chesscom_style.pgn');
      await resume(tester);

      expect(h.path, AppRoutes.newGameImport);
      expect(importFieldText(tester), fixture('chesscom_style.pgn'));
    });

    testWidgets('link and foreground together deliver it once', (tester) async {
      final shared = FakeSharedPgnSource(null);
      final h = Harness.create(sharedPgn: shared);
      await h.pumpStarted(tester);

      shared.waiting = fixtureBytes('chesscom_style.pgn');
      h.source.controller.add(const IncomingUrl('$_s://shared-pgn'));
      await resume(tester);

      expect(shared.calls, 3);
      expect(h.path, AppRoutes.newGameImport);
      expect(importFieldText(tester), fixture('chesscom_style.pgn'));
      expect(
        records.where((r) => r.message.startsWith('document received')),
        hasLength(1),
      );
    });

    testWidgets('cold start: waiting before the first frame', (tester) async {
      final shared = FakeSharedPgnSource(fixtureBytes('lichess_style.pgn'));
      final h = Harness.create(sharedPgn: shared);
      h.service.start();
      await tester.idle();
      expect(h.pending, isNotNull);

      await h.pump(tester);

      expect(shared.calls, 1);
      expect(h.path, AppRoutes.newGameImport);
      expect(importFieldText(tester), fixture('lichess_style.pgn'));
      expect(h.pending, isNull);
      h.router.pop();
      await tester.pumpAndSettle();
      expect(h.path, AppRoutes.newGame);
    });

    testWidgets('cold start through the link: still once', (tester) async {
      final shared = FakeSharedPgnSource(fixtureBytes('lichess_style.pgn'));
      final h = Harness.create(sharedPgn: shared);
      h.source.controller.add(const IncomingUrl('$_s://shared-pgn'));
      h.service.start();
      await tester.idle();
      await h.pump(tester);

      expect(shared.calls, 2);
      expect(h.path, AppRoutes.newGameImport);
      expect(importFieldText(tester), fixture('lichess_style.pgn'));
    });

    testWidgets('signed out: it waits and arrives after signing in', (
      tester,
    ) async {
      final shared = FakeSharedPgnSource(null);
      final h = Harness.create(auth: const SignedOut(), sharedPgn: shared);
      await h.pumpStarted(tester);
      expect(h.path, AppRoutes.signIn);

      shared.waiting = fixtureBytes('chesscom_style.pgn');
      await h.send(tester, const IncomingUrl('$_s://shared-pgn'));

      expect(h.path, AppRoutes.signIn);
      expect(h.uri.queryParameters[AppRoutes.fromParam], '/new/import');
      expect(find.byType(ImportScreen), findsNothing);
      expect(h.pending, fixture('chesscom_style.pgn'));

      h.signIn();
      await tester.pumpAndSettle();
      expect(h.path, AppRoutes.newGameImport);
      expect(importFieldText(tester), fixture('chesscom_style.pgn'));
      expect(h.pending, isNull);
    });

    testWidgets('cold start, signed out, then signing in', (tester) async {
      final shared = FakeSharedPgnSource(utf8.encode('1. d4 d5 2. c4'));
      final h = Harness.create(auth: const SignedOut(), sharedPgn: shared);
      h.service.start();
      await tester.idle();
      await h.pump(tester);
      expect(h.path, AppRoutes.signIn);
      expect(h.uri.queryParameters[AppRoutes.fromParam], '/new/import');

      h.signIn();
      await tester.pumpAndSettle();
      expect(h.path, AppRoutes.newGameImport);
      expect(importFieldText(tester), '1. d4 d5 2. c4');
    });

    testWidgets('an empty file: a message, nothing imported', (tester) async {
      final shared = FakeSharedPgnSource(null);
      final h = Harness.create(sharedPgn: shared);
      await h.pumpStarted(tester);
      shared.waiting = Uint8List(0);
      await resume(tester);
      expect(h.path, AppRoutes.games);
      expect(h.pending, isNull);
      expect(find.text('This file could not be read.'), findsOneWidget);
    });

    testWidgets('the size limit applies to it as well', (tester) async {
      // What the native reader hands over for a file that is too large: one
      // byte more than allowed.
      final shared = FakeSharedPgnSource(null);
      final h = Harness.create(sharedPgn: shared);
      await h.pumpStarted(tester);
      shared.waiting = Uint8List(kIncomingFileMaxBytes + 1)
        ..fillRange(0, kIncomingFileMaxBytes + 1, 0x20);
      await h.send(tester, const IncomingUrl('$_s://shared-pgn'));
      expect(h.path, AppRoutes.games);
      expect(h.pending, isNull);
      expect(find.textContaining('At most 2 MB'), findsOneWidget);
    });

    testWidgets('too large on a cold start, in German', (tester) async {
      final shared = FakeSharedPgnSource(
        Uint8List(kIncomingFileMaxBytes + 1)
          ..fillRange(0, kIncomingFileMaxBytes + 1, 0x20),
      );
      final h = Harness.create(sharedPgn: shared);
      h.service.start();
      await tester.idle();
      await h.pump(tester, locale: const Locale('de'));
      expect(h.path, AppRoutes.games);
      expect(find.textContaining('höchstens 2 MB'), findsOneWidget);
    });

    testWidgets('exactly the limit is accepted', (tester) async {
      final pgn = utf8.encode('1. e4 e5 *\n');
      final bytes = Uint8List(kIncomingFileMaxBytes)
        ..fillRange(0, kIncomingFileMaxBytes, 0x20)
        ..setRange(0, pgn.length, pgn);
      final shared = FakeSharedPgnSource(null);
      final h = Harness.create(sharedPgn: shared);
      await h.pumpStarted(tester);
      shared.waiting = bytes;
      h.source.controller.add(const IncomingUrl('$_s://shared-pgn'));
      // No settle: the screen parses a text of this size in an isolate.
      await tester.pump();
      expect(h.path, AppRoutes.newGameImport);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('binary content is refused', (tester) async {
      final shared = FakeSharedPgnSource(null);
      final h = Harness.create(sharedPgn: shared);
      await h.pumpStarted(tester);
      shared.waiting = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0, 1]);
      await resume(tester);
      expect(h.path, AppRoutes.games);
      expect(find.text('This file could not be read.'), findsOneWidget);
    });

    testWidgets('no content reaches the log', (tester) async {
      final shared = FakeSharedPgnSource(
        utf8.encode('[White "PRIVATENAME"]\n\n1. e4 *'),
      );
      final h = Harness.create(sharedPgn: shared);
      await h.pumpStarted(tester);
      expect(h.path, AppRoutes.newGameImport);
      final log = records.map((r) => '${r.message} ${r.error}').join('\n');
      expect(log, isNot(contains('PRIVATENAME')));
    });

    testWidgets('after dispose the foreground check is off', (tester) async {
      final shared = FakeSharedPgnSource(null);
      final h = Harness.create(sharedPgn: shared);
      await h.pumpStarted(tester);
      h.service.dispose();
      shared.waiting = fixtureBytes('lichess_style.pgn');
      await resume(tester);
      expect(shared.calls, 1);
      expect(h.path, AppRoutes.games);
    });
  });

  group('openLocation (for callers inside the app, WP-32)', () {
    testWidgets('goes through the same table', (tester) async {
      final h = Harness.create();
      await h.pumpStarted(tester);

      expect(h.service.openLocation('/games/abc/review'), isTrue);
      await tester.pumpAndSettle();
      expect(h.path, AppRoutes.gameReview('abc'));

      for (final refused in [
        '/sign-in?from=https://evil.example',
        '/consent/ai',
        'https://evil.example',
        '$_s:/oauthredirect?code=abc',
        '$_s://shared-pgn',
        '/games/../../etc/passwd',
      ]) {
        expect(h.service.openLocation(refused), isFalse, reason: refused);
      }
      await tester.pumpAndSettle();
      expect(h.path, AppRoutes.gameReview('abc'));
    });
  });

  group('robustness', () {
    testWidgets('start twice listens once; dispose stops listening', (
      tester,
    ) async {
      final h = Harness.create();
      h.service
        ..start()
        ..start();
      expect(h.source.listens, 1);
      expect(h.source.controller.hasListener, isTrue);
      h.service.dispose();
      expect(h.source.controller.hasListener, isFalse);
    });

    testWidgets('an error on the stream does not end the service', (
      tester,
    ) async {
      final h = Harness.create();
      await h.pumpStarted(tester);
      h.source.controller.addError(StateError('no native side'));
      await tester.pumpAndSettle();
      expect(records.where((r) => r.level == LogLevel.warning), hasLength(1));

      await h.send(tester, const IncomingUrl('$_s://settings'));
      expect(h.path, AppRoutes.settings);
    });

    testWidgets('a failing shared-pgn source is contained', (tester) async {
      final h = Harness.create(sharedPgn: _ThrowingSharedPgnSource());
      await h.pumpStarted(tester);
      // Once at the start, once for the link, once for the foreground.
      await h.send(tester, const IncomingUrl('$_s://shared-pgn'));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(h.path, AppRoutes.games);
      expect(records.where((r) => r.level == LogLevel.error), hasLength(3));
      expect(tester.takeException(), isNull);
    });
  });
}

class _ThrowingSharedPgnSource implements SharedPgnSource {
  @override
  Future<Uint8List?> take() => Future.error(StateError('container missing'));
}
