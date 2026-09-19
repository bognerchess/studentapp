// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:io' as io;
import 'dart:isolate';

import 'package:bogner_chess/core/chess/board_thumbnail.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/pgn/pgn_import.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/features/import/data/pgn_file_picker.dart';
import 'package:bogner_chess/features/import/domain/import_result.dart';
import 'package:bogner_chess/features/import/domain/pending_import.dart';
import 'package:bogner_chess/features/import/ui/import_screen.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

String fixture(String name) =>
    io.File('test/fixtures/pgn/$name').readAsStringSync();

class FakePgnFilePicker implements PgnFilePicker {
  FakePgnFilePicker(this.next);

  PgnFilePick next;
  int calls = 0;

  @override
  Future<PgnFilePick> pick() async {
    calls++;
    return next;
  }
}

/// Answers `Clipboard.getData` with [text] (null: an empty clipboard).
void mockClipboard(WidgetTester tester, String? text) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => call.method == 'Clipboard.getData' && text != null
        ? <String, Object?>{'text': text}
        : null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

/// Pumps the screen on its own, the way the demo entry point does.
Future<List<ImportResult>> pumpImport(
  WidgetTester tester, {
  String? initialText,
  PgnFilePicker? picker,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Size screen = kIphone17Pro,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = screen * 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  final results = <ImportResult>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (picker != null) pgnFilePickerProvider.overrideWithValue(picker),
      ],
      child: MaterialApp(
        locale: locale,
        theme: brightness == Brightness.light
            ? AppTheme.light()
            : AppTheme.dark(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: ImportScreen(initialText: initialText, onContinue: results.add),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return results;
}

Finder byKey(String key) => find.byKey(ValueKey(key));

FilledButton continueButton(WidgetTester tester) =>
    tester.widget<FilledButton>(byKey('import-continue'));

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(byKey(key)).data!;

void main() {
  group('paste', () {
    testWidgets('paste, preview, continue', (tester) async {
      mockClipboard(tester, fixture('lichess_style.pgn'));
      final results = await pumpImport(tester);

      expect(byKey('import-hint'), findsOneWidget);
      expect(continueButton(tester).onPressed, isNull);

      await tester.tap(byKey('import-paste'));
      await tester.pumpAndSettle();

      expect(byKey('import-hint'), findsNothing);
      expect(byKey('import-preview'), findsOneWidget);
      expect(find.text('Ready to import'), findsOneWidget);
      expect(
        textOf(tester, 'import-preview-players'),
        'anna_example (1652) – bruno_beispiel (1618)',
      );
      expect(find.text('Rated Rapid game'), findsOneWidget);
      expect(
        textOf(tester, 'import-preview-facts'),
        'Sep 12, 2026 · 1-0 · 17 moves',
      );
      final board = tester.widget<BoardThumbnail>(find.byType(BoardThumbnail));
      expect(board.fen, startsWith('1n1Rkb1r/p4ppp/4q3/'));
      expect(board.semanticLabel, 'Final position');
      expect(byKey('import-warning-variationsRemoved'), findsNothing);
      expect(byKey('import-warning-commentsRemoved'), findsNothing);
      expect(
        tester.widget<TextField>(byKey('import-field')).controller!.text,
        startsWith('[Event "Rated Rapid game"]'),
      );

      await tester.tap(byKey('import-continue'));
      await tester.pump();

      final result = results.single;
      expect(result.movetext, startsWith('1. e4 e5 2. Nf3 d6 3. d4 Bg4'));
      expect(result.movetext, endsWith('16. Qb8+ Nxb8 17. Rd8#'));
      expect(result.movetext, isNot(contains('{')));
      expect(result.headers['White'], 'anna_example');
      expect(result.headers['TimeControl'], '600+5');
      expect(result.warnings, isEmpty);
      expect(result.result, '1-0');
      expect(result.plyCount, 33);
      expect(result.finalFen, startsWith('1n1Rkb1r/'));
    });

    testWidgets('an empty clipboard says so and changes nothing', (
      tester,
    ) async {
      mockClipboard(tester, null);
      await pumpImport(tester, initialText: '1. e4 e5');
      await tester.tap(byKey('import-paste'));
      await tester.pump();
      expect(find.text('There is no text on the clipboard.'), findsOneWidget);
      expect(byKey('import-preview'), findsOneWidget);
    });
  });

  group('typing', () {
    testWidgets('the text is checked after a pause, not per keystroke', (
      tester,
    ) async {
      await pumpImport(tester);
      await tester.enterText(byKey('import-field'), '1. e4 e5 2. Nf3');
      await tester.pump(const Duration(milliseconds: 100));
      expect(byKey('import-preview'), findsNothing);
      await tester.pump(kImportDebounce);
      expect(byKey('import-preview'), findsOneWidget);
      expect(textOf(tester, 'import-preview-players'), 'White – Black');
      expect(textOf(tester, 'import-preview-facts'), 'No result · 2 moves');
    });

    testWidgets('the error panel says what is wrong and where', (tester) async {
      await pumpImport(tester);
      await tester.enterText(byKey('import-field'), fixture('broken.pgn'));
      await tester.pump(kImportDebounce);

      expect(byKey('import-error'), findsOneWidget);
      expect(find.text("This game can't be imported"), findsOneWidget);
      expect(find.text('Gregor Fehler – Hanna Richtig'), findsOneWidget);
      expect(
        textOf(tester, 'import-error-message'),
        '13. Rh5 is not a legal move in this position.',
      );
      expect(textOf(tester, 'import-error-where'), 'Line 12');
      expect(byKey('import-preview'), findsNothing);
      expect(continueButton(tester).onPressed, isNull);

      // Fixing the move clears the error.
      await tester.enterText(
        byKey('import-field'),
        fixture('broken.pgn').replaceAll('13. Rh5', '13. Re1'),
      );
      await tester.pump(kImportDebounce);
      expect(byKey('import-error'), findsNothing);
      expect(byKey('import-preview'), findsOneWidget);
      expect(continueButton(tester).onPressed, isNotNull);
    });

    testWidgets('every kind of error has its own words', (tester) async {
      await pumpImport(tester);
      const cases = {
        'hello there': 'No chess game was found in this text.',
        '1. e4 e5 2. Nf3 Nf9': '“Nf9” is not a chess move. Moves need',
        '1. Nf3 Nf6 2. Nc3 Nc6 3. Nd4 d6 4. Nb5': 'is ambiguous',
        '[FEN "8/8/8/4k3/8/8/4P3/4K3 w - - 0 1"]\n\n1. Kd2': 'set-up position',
        '[Variant "Atomic"]\n\n1. e4': 'This is a game of Atomic.',
        '[White "A"]\n\n*': 'This game has no moves.',
        '1. e4 {oops': 'curly bracket',
        '1. e4 (1. d4': 'round bracket',
      };
      for (final MapEntry(key: text, value: message) in cases.entries) {
        await tester.enterText(byKey('import-field'), text);
        await tester.pump(kImportDebounce);
        expect(
          textOf(tester, 'import-error-message'),
          contains(message),
          reason: text,
        );
      }
      await tester.enterText(byKey('import-field'), '1. e4 e5\n2. Nf3 Nf9');
      await tester.pump(kImportDebounce);
      expect(textOf(tester, 'import-error-where'), 'Line 2, at move 2');
      expect(find.text("This game can't be imported"), findsOneWidget);

      await tester.enterText(byKey('import-field'), 'hello');
      await tester.pump(kImportDebounce);
      expect(find.text("This text can't be imported"), findsOneWidget);
      expect(byKey('import-error-where'), findsNothing);
    });

    testWidgets('the clear button empties the field and the result', (
      tester,
    ) async {
      await pumpImport(tester, initialText: '1. e4 e5');
      expect(byKey('import-preview'), findsOneWidget);
      await tester.tap(byKey('import-clear'));
      await tester.pump();
      expect(byKey('import-preview'), findsNothing);
      expect(byKey('import-hint'), findsOneWidget);
      expect(byKey('import-clear'), findsNothing);
    });
  });

  group('initial text', () {
    testWidgets('is checked in the first frame, warnings are shown', (
      tester,
    ) async {
      final results = await pumpImport(
        tester,
        initialText: fixture('otb_annotated.pgn'),
      );
      expect(
        textOf(tester, 'import-preview-players'),
        'Muster, Anna (1874) – Beispiel, Bruno (1902)',
      );
      expect(
        textOf(tester, 'import-preview-facts'),
        'Mar 14, 2026 · ½–½ · 14 moves',
      );
      expect(
        find.text('Variations were removed. Only the main line is imported.'),
        findsOneWidget,
      );
      expect(
        find.text('Comments and annotation symbols were removed.'),
        findsOneWidget,
      );

      await tester.tap(byKey('import-continue'));
      expect(results.single.warnings, {
        PgnImportWarning.variationsRemoved,
        PgnImportWarning.commentsRemoved,
      });
      expect(results.single.movetext, contains('5. O-O Be7'));
      expect(results.single.result, '1/2-1/2');
    });
  });

  group('several games', () {
    testWidgets('chooser, preview, back to the chooser', (tester) async {
      final results = await pumpImport(
        tester,
        initialText: '${fixture('multi_game.pgn')}\n${fixture('broken.pgn')}',
      );

      expect(textOf(tester, 'import-games-found'), '4 games found');
      expect(find.text('Choose the game you want to import.'), findsOneWidget);
      expect(byKey('import-preview'), findsNothing);
      expect(continueButton(tester).onPressed, isNull);
      expect(find.text('Carla Probe – David Test'), findsOneWidget);
      expect(find.text('May 2, 2026 · 1-0 · 4 moves'), findsOneWidget);
      expect(find.text('May 2, 2026 · No result · 7 moves'), findsOneWidget);
      expect(find.byType(BoardThumbnail), findsNWidgets(3));

      await tester.tap(byKey('import-game-1'));
      await tester.pumpAndSettle();
      expect(byKey('import-game-0'), findsNothing);
      expect(
        textOf(tester, 'import-preview-players'),
        'Emil Exempel – Carla Probe',
      );
      expect(continueButton(tester).onPressed, isNotNull);

      await tester.tap(byKey('import-choose-another'));
      await tester.pumpAndSettle();
      expect(byKey('import-preview'), findsNothing);
      expect(continueButton(tester).onPressed, isNull);

      // The broken game is listed, and tapping it explains why.
      await tester.scrollUntilVisible(
        byKey('import-game-3'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text("Can't be imported"), findsOneWidget);
      await tester.tap(byKey('import-game-3'));
      await tester.pumpAndSettle();
      expect(byKey('import-error'), findsOneWidget);
      expect(find.text('Gregor Fehler – Hanna Richtig'), findsOneWidget);
      expect(continueButton(tester).onPressed, isNull);

      await tester.tap(byKey('import-choose-another'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('import-game-2'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('import-continue'));
      expect(results.single.headers['Round'], '3');
      expect(results.single.movetext, endsWith('7. Bh4 b6'));
      expect(results.single.result, '*');
    });

    testWidgets('a long file builds only the rows on screen', (tester) async {
      await pumpImport(
        tester,
        initialText: '[Event "x"]\n\n1. e4 e5 1-0\n\n' * 300,
      );
      expect(textOf(tester, 'import-games-found'), '300 games found');
      expect(find.byType(BoardThumbnail).evaluate().length, lessThan(30));
    });
  });

  group('file', () {
    testWidgets('a picked file lands in the field and is checked', (
      tester,
    ) async {
      final picker = FakePgnFilePicker(
        PgnFilePicked(name: 'club.pgn', text: fixture('chesscom_style.pgn')),
      );
      await pumpImport(tester, picker: picker);
      await tester.tap(byKey('import-open-file'));
      await tester.pumpAndSettle();
      expect(picker.calls, 1);
      expect(
        textOf(tester, 'import-preview-players'),
        'pawnstorm_anna (612) – quiet_knight77 (640)',
      );
      expect(
        tester.widget<TextField>(byKey('import-field')).controller!.text,
        contains('[Site "Chess.com"]'),
      );
    });

    testWidgets('cancelled, too large, unreadable', (tester) async {
      final picker = FakePgnFilePicker(const PgnFileCancelled());
      await pumpImport(tester, picker: picker, initialText: '1. e4');
      await tester.tap(byKey('import-open-file'));
      await tester.pumpAndSettle();
      expect(byKey('import-preview'), findsOneWidget);

      picker.next = const PgnFileUnreadable();
      await tester.tap(byKey('import-open-file'));
      await tester.pump();
      expect(find.text('This file could not be read.'), findsOneWidget);
      expect(byKey('import-preview'), findsOneWidget);

      picker.next = const PgnFileTooLarge();
      await tester.tap(byKey('import-open-file'));
      await tester.pumpAndSettle();
      expect(
        textOf(tester, 'import-error-message'),
        'The text is too large. At most 2 MB can be imported at once.',
      );
      expect(byKey('import-preview'), findsNothing);
    });
  });

  group('inside the app', () {
    testWidgets('pending text is taken once; Continue pops with the result', (
      tester,
    ) async {
      await pumpApp(tester);
      final container = containerOf(tester);
      container
          .read(pendingImportProvider.notifier)
          .offer(fixture('chesscom_style.pgn'));
      final popped = routerOf(tester)
          .push<ImportResult>(AppRoutes.newGameImport);
      await tester.pumpAndSettle();

      expect(byKey('import-preview'), findsOneWidget);
      expect(container.read(pendingImportProvider), isNull);

      // A second text while the screen is open replaces the first.
      container.read(pendingImportProvider.notifier).offer('1. d4 d5 2. c4');
      await tester.pumpAndSettle();
      expect(textOf(tester, 'import-preview-facts'), 'No result · 2 moves');
      expect(container.read(pendingImportProvider), isNull);

      await tester.tap(byKey('import-continue'));
      await tester.pumpAndSettle();
      final result = await popped;
      expect(result?.movetext, '1. d4 d5 2. c4');
      expect(find.byType(ImportScreen), findsNothing);
    });

    testWidgets('opened by hand it starts empty', (tester) async {
      await pumpApp(tester);
      routerOf(tester).go(AppRoutes.newGameImport);
      await tester.pumpAndSettle();
      expect(byKey('import-hint'), findsOneWidget);
      expect(find.text('Import PGN'), findsOneWidget);
    });
  });

  group('German, large text, small screen, dark', () {
    final states = <String, String?>{
      'empty': null,
      'preview with warnings': fixture('otb_annotated.pgn'),
      'chooser': '${fixture('multi_game.pgn')}\n${fixture('broken.pgn')}',
      'error': fixture('broken.pgn'),
      'text error': 'x' * 40,
    };
    for (final locale in const [Locale('de'), Locale('en')]) {
      for (final brightness in Brightness.values) {
        for (final MapEntry(key: name, value: text) in states.entries) {
          testWidgets('$locale ${brightness.name}: $name', (tester) async {
            await pumpImport(
              tester,
              initialText: text,
              locale: locale,
              brightness: brightness,
              textScale: 1.3,
              screen: kIphoneSe,
            );
            // An overflow would have failed the test by now. Scroll through
            // the whole page so that everything has been laid out once.
            await tester.drag(
              find.byType(CustomScrollView),
              const Offset(0, -600),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    testWidgets('German strings and date format', (tester) async {
      await pumpImport(
        tester,
        initialText: fixture('otb_annotated.pgn'),
        locale: const Locale('de'),
      );
      expect(find.text('Aus Zwischenablage einfügen'), findsOneWidget);
      expect(find.text('Datei öffnen …'), findsOneWidget);
      expect(find.text('Bereit zum Import'), findsOneWidget);
      expect(
        textOf(tester, 'import-preview-facts'),
        '14. März 2026 · ½–½ · 14 Züge',
      );
      expect(
        find.text(
          'Varianten wurden entfernt. Nur die Hauptvariante wird importiert.',
        ),
        findsOneWidget,
      );
      expect(find.text('Weiter'), findsOneWidget);
      expect(
        tester
            .widget<BoardThumbnail>(find.byType(BoardThumbnail))
            .semanticLabel,
        'Schlussstellung',
      );
    });

    testWidgets('German error panel and chooser', (tester) async {
      await pumpImport(
        tester,
        initialText: fixture('broken.pgn'),
        locale: const Locale('de'),
      );
      expect(
        find.text('Diese Partie kann nicht importiert werden'),
        findsOneWidget,
      );
      expect(
        textOf(tester, 'import-error-message'),
        '13. Rh5 ist in dieser Stellung kein erlaubter Zug.',
      );
      expect(textOf(tester, 'import-error-where'), 'Zeile 12');

      await tester.enterText(byKey('import-field'), fixture('multi_game.pgn'));
      await tester.pump(kImportDebounce);
      expect(textOf(tester, 'import-games-found'), '3 Partien gefunden');
      expect(find.text('2. Mai 2026 · 1-0 · 4 Züge'), findsOneWidget);
      expect(find.text('2. Mai 2026 · Ohne Ergebnis · 7 Züge'), findsOneWidget);
    });

    testWidgets('dark theme: the error panel uses the dark error colours', (
      tester,
    ) async {
      await pumpImport(
        tester,
        initialText: fixture('broken.pgn'),
        brightness: Brightness.dark,
      );
      final card = tester.widget<Card>(byKey('import-error'));
      expect(card.color, AppTheme.dark().colorScheme.errorContainer);
    });
  });

  test('a parse result can cross an isolate boundary', () async {
    final text = '${fixture('multi_game.pgn')}\n${fixture('broken.pgn')}';
    final result = await Isolate.run(() => parsePgnText(text));
    expect(result.importable, hasLength(3));
    expect(result.games.last, isA<PgnRejectedGame>());
  });
}
