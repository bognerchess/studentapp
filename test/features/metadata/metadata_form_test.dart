// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/features/metadata/ui/metadata_form.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

final GameDate today = GameDate(2026, 9, 19);

/// Everything the form reported, oldest first.
class Reported {
  final List<GameMetadata> all = [];
  GameMetadata get last => all.last;
}

/// Pumps the form the way a screen hosts it: themed, localised, scrollable.
Future<Reported> pumpForm(
  WidgetTester tester, {
  GameMetadata initial = const GameMetadata(),
  String? defaultPlayerName,
  bool autofocus = false,
  bool swapSidesOnColorChange = true,
  bool defaultDateToToday = true,
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

  final reported = Reported();
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: MetadataForm(
              initial: initial,
              defaultPlayerName: defaultPlayerName,
              autofocus: autofocus,
              swapSidesOnColorChange: swapSidesOnColorChange,
              defaultDateToToday: defaultDateToToday,
              today: today,
              onChanged: reported.all.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return reported;
}

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, Key field, String text) async {
  await tester.ensureVisible(find.byKey(field));
  await tester.enterText(find.byKey(field), text);
  await tester.pumpAndSettle();
}

/// A segment of the colour control ("White" is also a field label while an
/// imported game has no colour yet).
Finder colorSegment(String label) => find.descendant(
  of: find.byKey(MetadataFormKeys.color),
  matching: find.text(label),
);

String textOf(WidgetTester tester, Key field) =>
    tester.widget<TextField>(find.byKey(field)).controller!.text;

bool hasFocus(WidgetTester tester, Key field) =>
    tester.widget<TextField>(find.byKey(field)).focusNode!.hasFocus;

bool isSelected(WidgetTester tester, Key chip) =>
    tester.widget<ChoiceChip>(find.byKey(chip)).selected;

final GameMetadata imported = GameMetadata.fromPgnHeaders(const {
  'Event': 'Club championship',
  'Date': '2026.09.12',
  'White': 'Beispiel, Bettina',
  'Black': 'Muster, Max',
  'Result': '0-1',
  'WhiteElo': '1840',
  'BlackElo': '1712',
  'TimeControl': '5400+30',
});

void main() {
  group('what the form starts with', () {
    testWidgets('the date defaults to today and that is reported once', (
      tester,
    ) async {
      final reported = await pumpForm(tester);

      expect(find.text('Sep 19, 2026'), findsOneWidget);
      expect(reported.all, [GameMetadata(playedDate: today)]);
    });

    testWidgets('a date that is already there is kept', (tester) async {
      final reported = await pumpForm(
        tester,
        initial: GameMetadata(playedDate: GameDate(2026, 9, 12)),
      );

      expect(find.text('Sep 12, 2026'), findsOneWidget);
      expect(reported.all, isEmpty);
    });

    testWidgets('without the default an unknown date stays unknown', (
      tester,
    ) async {
      final reported = await pumpForm(tester, defaultDateToToday: false);

      final dateField = find.byKey(MetadataFormKeys.date);
      expect(
        find.descendant(of: dateField, matching: find.text('Unknown')),
        findsOneWidget,
      );
      expect(find.byKey(MetadataFormKeys.dateClear), findsNothing);
      expect(reported.all, isEmpty);
    });

    testWidgets('the date can be cleared', (tester) async {
      final reported = await pumpForm(tester);

      await tapOn(tester, find.byKey(MetadataFormKeys.dateClear));

      expect(reported.last.playedDate, isNull);
      expect(find.byKey(MetadataFormKeys.dateClear), findsNothing);
    });

    testWidgets('the date picker sets another day and offers no future', (
      tester,
    ) async {
      final reported = await pumpForm(tester);

      await tapOn(tester, find.byKey(MetadataFormKeys.date));
      expect(find.byType(DatePickerDialog), findsOneWidget);
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.lastDate, DateTime(2026, 9, 19));

      await tester.tap(find.text('12'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(reported.last.playedDate, GameDate(2026, 9, 12));
      expect(find.text('Sep 12, 2026'), findsOneWidget);
    });

    testWidgets('the user\'s own name is filled in', (tester) async {
      final reported = await pumpForm(tester, defaultPlayerName: 'Max Muster');

      expect(textOf(tester, MetadataFormKeys.playerName), 'Max Muster');
      expect(textOf(tester, MetadataFormKeys.opponentName), isEmpty);

      await tapOn(tester, colorSegment('Black'));
      expect(reported.last.blackName, 'Max Muster');
      expect(reported.last.playerName, 'Max Muster');
    });

    testWidgets('a name that is already there wins over the default', (
      tester,
    ) async {
      await pumpForm(
        tester,
        initial: const GameMetadata(
          whiteName: 'M. Muster',
          playerColor: PlayerColor.white,
        ),
        defaultPlayerName: 'Max Muster',
      );

      expect(textOf(tester, MetadataFormKeys.playerName), 'M. Muster');
    });

    testWidgets('existing metadata is shown from the user\'s side', (
      tester,
    ) async {
      final reported = await pumpForm(
        tester,
        initial: imported.copyWith(playerColor: PlayerColor.black),
      );

      expect(textOf(tester, MetadataFormKeys.playerName), 'Muster, Max');
      expect(textOf(tester, MetadataFormKeys.playerRating), '1712');
      expect(
        textOf(tester, MetadataFormKeys.opponentName),
        'Beispiel, Bettina',
      );
      expect(textOf(tester, MetadataFormKeys.opponentRating), '1840');
      expect(textOf(tester, MetadataFormKeys.event), 'Club championship');
      expect(textOf(tester, MetadataFormKeys.timeControlDetail), '90+30');
      expect(
        isSelected(
          tester,
          MetadataFormKeys.timeControl(TimeControlKind.classical),
        ),
        isTrue,
      );
      expect(
        isSelected(tester, MetadataFormKeys.result(GameResult.blackWins)),
        isTrue,
      );
      expect(find.text('You won.'), findsOneWidget);
      // Nothing was filled in, so nothing is reported.
      expect(reported.all, isEmpty);
    });
  });

  group('colour played', () {
    testWidgets('nothing is selected at first and the choice is reported', (
      tester,
    ) async {
      final reported = await pumpForm(tester);
      final control = tester.widget<SegmentedButton<PlayerColor>>(
        find.byKey(MetadataFormKeys.color),
      );
      expect(control.selected, isEmpty);

      await tapOn(tester, colorSegment('White'));
      expect(reported.last.playerColor, PlayerColor.white);

      // Tapping it again does not take the colour away.
      await tapOn(tester, colorSegment('White'));
      expect(reported.last.playerColor, PlayerColor.white);
    });

    testWidgets('flipping it moves me and my opponent across the board', (
      tester,
    ) async {
      final reported = await pumpForm(tester, defaultPlayerName: 'Max Muster');
      await tapOn(tester, colorSegment('White'));
      await type(tester, MetadataFormKeys.opponentName, 'Anna Schmidt');
      await type(tester, MetadataFormKeys.opponentRating, '1650');
      await type(tester, MetadataFormKeys.playerRating, '1500');

      expect(reported.last.whiteName, 'Max Muster');
      expect(reported.last.blackName, 'Anna Schmidt');
      expect(reported.last.whiteRating, 1500);
      expect(reported.last.blackRating, 1650);

      await tapOn(tester, colorSegment('Black'));

      expect(reported.last.playerColor, PlayerColor.black);
      expect(reported.last.whiteName, 'Anna Schmidt');
      expect(reported.last.blackName, 'Max Muster');
      expect(reported.last.whiteRating, 1650);
      expect(reported.last.blackRating, 1500);
      // The fields themselves did not move.
      expect(textOf(tester, MetadataFormKeys.opponentName), 'Anna Schmidt');
      expect(textOf(tester, MetadataFormKeys.playerRating), '1500');

      await tapOn(tester, colorSegment('White'));
      expect(reported.last.whiteName, 'Max Muster');
      expect(reported.last.blackRating, 1650);
    });

    testWidgets('an imported game keeps White and Black where they are', (
      tester,
    ) async {
      final reported = await pumpForm(
        tester,
        initial: imported,
        defaultPlayerName: 'Somebody Else',
        swapSidesOnColorChange: false,
        defaultDateToToday: false,
      );

      // Nobody knows yet who "you" is: the fields are named by colour,
      // White first, and the account name is not forced onto White.
      expect(find.text('Your name'), findsNothing);
      expect(find.text('Opponent'), findsNothing);
      expect(textOf(tester, MetadataFormKeys.playerName), 'Beispiel, Bettina');
      expect(
        tester.getTopLeft(find.byKey(MetadataFormKeys.playerName)).dy,
        lessThan(
          tester.getTopLeft(find.byKey(MetadataFormKeys.opponentName)).dy,
        ),
      );
      expect(find.byKey(MetadataFormKeys.ratingHint), findsNothing);

      await tapOn(tester, colorSegment('Black'));

      expect(reported.last, imported.copyWith(playerColor: PlayerColor.black));
      expect(find.text('Your name'), findsOneWidget);
      expect(find.text('Opponent'), findsOneWidget);
      expect(textOf(tester, MetadataFormKeys.playerName), 'Muster, Max');
      expect(textOf(tester, MetadataFormKeys.playerRating), '1712');
      expect(
        textOf(tester, MetadataFormKeys.opponentName),
        'Beispiel, Bettina',
      );
      expect(find.text('You won.'), findsOneWidget);

      await tapOn(tester, colorSegment('White'));

      expect(reported.last, imported.copyWith(playerColor: PlayerColor.white));
      expect(textOf(tester, MetadataFormKeys.playerName), 'Beispiel, Bettina');
      expect(find.text('You lost.'), findsOneWidget);
    });
  });

  group('result chips', () {
    testWidgets('1-0, ½-½, 0-1 and unknown', (tester) async {
      final reported = await pumpForm(tester);
      for (final label in ['1-0', '½-½', '0-1', 'Unknown']) {
        expect(
          find.descendant(
            of: find.byType(ChoiceChip),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: label,
        );
      }
      expect(
        isSelected(tester, MetadataFormKeys.result(GameResult.unknown)),
        isTrue,
      );

      await tapOn(tester, find.text('1-0'));
      expect(reported.last.result, GameResult.whiteWins);
      await tapOn(tester, find.text('½-½'));
      expect(reported.last.result, GameResult.draw);
      await tapOn(tester, find.text('0-1'));
      expect(reported.last.result, GameResult.blackWins);
      expect(
        isSelected(tester, MetadataFormKeys.result(GameResult.blackWins)),
        isTrue,
      );
      expect(
        isSelected(tester, MetadataFormKeys.result(GameResult.draw)),
        isFalse,
      );

      // Tapping the selected chip takes the result back.
      await tapOn(tester, find.text('0-1'));
      expect(reported.last.result, GameResult.unknown);
    });

    testWidgets('the form says what the result means for the user', (
      tester,
    ) async {
      await pumpForm(tester);
      await tapOn(tester, find.text('0-1'));
      // No colour yet, so no verdict.
      expect(find.byKey(MetadataFormKeys.outcome), findsNothing);

      await tapOn(tester, colorSegment('White'));
      expect(find.text('You lost.'), findsOneWidget);
      await tapOn(tester, colorSegment('Black'));
      expect(find.text('You won.'), findsOneWidget);
      await tapOn(tester, find.text('½-½'));
      expect(find.text('A draw.'), findsOneWidget);
    });

    testWidgets('chips have spoken labels', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpForm(tester);

      expect(find.bySemanticsLabel('White won, 1-0'), findsOneWidget);
      expect(find.bySemanticsLabel('Black won, 0-1'), findsOneWidget);
      expect(find.bySemanticsLabel('Draw, one half each'), findsOneWidget);
      handle.dispose();
    });
  });

  group('ratings', () {
    testWidgets('only digits, four at most', (tester) async {
      final reported = await pumpForm(tester);

      await type(tester, MetadataFormKeys.playerRating, '15a0-0');
      expect(textOf(tester, MetadataFormKeys.playerRating), '1500');
      await type(tester, MetadataFormKeys.playerRating, '123456');
      expect(textOf(tester, MetadataFormKeys.playerRating).length, 4);
      expect(reported.last.whiteRating, isNotNull);
    });

    testWidgets('too low is an error once the field is left', (tester) async {
      final reported = await pumpForm(tester);
      await tapOn(tester, colorSegment('White'));

      await tapOn(tester, find.byKey(MetadataFormKeys.playerRating));
      await type(tester, MetadataFormKeys.playerRating, '99');
      expect(reported.last.whiteRating, 99);
      expect(reported.last.validate(today: today).invalid, {
        MetadataField.whiteRating,
      });
      // Still typing: "99" may be on its way to "990".
      expect(find.text('100–3500'), findsNothing);

      await tapOn(tester, find.byKey(MetadataFormKeys.event));
      expect(find.text('100–3500'), findsOneWidget);

      await type(tester, MetadataFormKeys.playerRating, '100');
      expect(find.text('100–3500'), findsNothing);
      expect(reported.last.validate(today: today).isValid, isTrue);
    });

    testWidgets('too high is an error at once', (tester) async {
      final reported = await pumpForm(tester);
      await tapOn(tester, colorSegment('White'));

      await tapOn(tester, find.byKey(MetadataFormKeys.opponentRating));
      await type(tester, MetadataFormKeys.opponentRating, '3501');
      expect(find.text('100–3500'), findsOneWidget);
      expect(reported.last.validate(today: today).invalid, {
        MetadataField.blackRating,
      });

      await type(tester, MetadataFormKeys.opponentRating, '3500');
      expect(find.text('100–3500'), findsNothing);
      expect(reported.last.validate(today: today).isValid, isTrue);
    });

    testWidgets('the form asks for the own rating until it is there', (
      tester,
    ) async {
      await pumpForm(tester);
      expect(find.byKey(MetadataFormKeys.ratingHint), findsOneWidget);
      expect(find.textContaining('the coach explains'), findsOneWidget);

      await type(tester, MetadataFormKeys.playerRating, '1500');
      expect(find.byKey(MetadataFormKeys.ratingHint), findsNothing);
    });

    testWidgets('rating fields have spoken labels', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpForm(tester);

      expect(find.bySemanticsLabel(RegExp('Your rating')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp("Opponent's rating")),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('time control', () {
    testWidgets('a chip alone is enough', (tester) async {
      final reported = await pumpForm(tester);

      await tapOn(tester, find.text('Rapid'));
      expect(
        reported.last.timeControl,
        const TimeControl(TimeControlKind.rapid),
      );

      await tapOn(tester, find.text('Rapid'));
      expect(reported.last.timeControl, isNull);
    });

    testWidgets('typing the numbers picks the chip', (tester) async {
      final reported = await pumpForm(tester);

      await type(tester, MetadataFormKeys.timeControlDetail, '15+10');
      expect(
        reported.last.timeControl,
        const TimeControl(TimeControlKind.rapid, detail: '15+10'),
      );
      expect(
        isSelected(tester, MetadataFormKeys.timeControl(TimeControlKind.rapid)),
        isTrue,
      );

      await type(tester, MetadataFormKeys.timeControlDetail, '3+2');
      expect(reported.last.timeControl!.kind, TimeControlKind.blitz);
    });

    testWidgets('a chip the user chose is not overruled by the numbers', (
      tester,
    ) async {
      final reported = await pumpForm(tester);

      await tapOn(tester, find.text('Classical'));
      await type(tester, MetadataFormKeys.timeControlDetail, '30+0');
      expect(
        reported.last.timeControl,
        const TimeControl(TimeControlKind.classical, detail: '30+0'),
      );
    });

    testWidgets('free text without a chip is "other"', (tester) async {
      final reported = await pumpForm(tester);

      await type(tester, MetadataFormKeys.timeControlDetail, 'no clock');
      expect(
        reported.last.timeControl,
        const TimeControl(TimeControlKind.other, detail: 'no clock'),
      );
    });
  });

  group('keyboard', () {
    testWidgets('"next" walks down the form and skips a name that is there', (
      tester,
    ) async {
      await pumpForm(tester, defaultPlayerName: 'Max Muster', autofocus: true);
      expect(hasFocus(tester, MetadataFormKeys.opponentName), isTrue);

      Future<void> next() async {
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pumpAndSettle();
      }

      await next();
      expect(hasFocus(tester, MetadataFormKeys.opponentRating), isTrue);
      await next();
      expect(hasFocus(tester, MetadataFormKeys.playerRating), isTrue);
      await next();
      expect(hasFocus(tester, MetadataFormKeys.event), isTrue);
      await next();
      expect(hasFocus(tester, MetadataFormKeys.timeControlDetail), isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(hasFocus(tester, MetadataFormKeys.timeControlDetail), isFalse);
    });

    testWidgets('an empty own name is not skipped', (tester) async {
      await pumpForm(tester);
      await tapOn(tester, find.byKey(MetadataFormKeys.opponentRating));

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(hasFocus(tester, MetadataFormKeys.playerName), isTrue);
    });

    testWidgets('every text field offers "next", the last one "done"', (
      tester,
    ) async {
      await pumpForm(tester);
      final actions = {
        for (final field in tester.widgetList<TextField>(
          find.byType(TextField),
        ))
          field.key: field.textInputAction,
      };
      expect(actions.length, 6);
      expect(
        actions.remove(MetadataFormKeys.timeControlDetail),
        TextInputAction.done,
      );
      expect(actions.values.toSet(), {TextInputAction.next});
    });
  });

  group('German', () {
    testWidgets('every label is German', (tester) async {
      final reported = await pumpForm(
        tester,
        locale: const Locale('de'),
        defaultPlayerName: 'Max Muster',
      );

      for (final text in [
        'Ich hatte',
        'Weiß',
        'Schwarz',
        'Ergebnis',
        'Unbekannt',
        'Spieler',
        'Gegner',
        'Dein Name',
        'Datum',
        '19. Sept. 2026',
        'Turnier oder Anlass',
        'Bedenkzeit',
        'Klassisch',
        'Schnellschach',
        'Blitz',
        'Bullet',
        'Andere',
        'Minuten + Inkrement',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('Elo'), findsNWidgets(2));
      expect(find.textContaining('erklärt der Coach'), findsOneWidget);

      await tapOn(tester, colorSegment('Schwarz'));
      await tapOn(tester, find.text('0-1'));
      expect(find.text('Du hast gewonnen.'), findsOneWidget);
      expect(reported.last.playerOutcome, PlayerOutcome.win);
    });
  });

  group('text scale 1.3 on the smallest iPhone does not overflow', () {
    for (final locale in const [Locale('en'), Locale('de')]) {
      for (final brightness in Brightness.values) {
        testWidgets('$locale, ${brightness.name}', (tester) async {
          await pumpForm(
            tester,
            locale: locale,
            brightness: brightness,
            textScale: 1.3,
            screen: kIphoneSe,
            defaultPlayerName: 'Maximilian Mustermann-Beispielhuber',
          );
          expect(tester.takeException(), isNull);

          // The tallest state: a verdict under the chips, both rating
          // errors, and long text everywhere.
          await tapOn(tester, find.byKey(MetadataFormKeys.color));
          await tapOn(
            tester,
            find.byKey(MetadataFormKeys.result(GameResult.whiteWins)),
          );
          await type(
            tester,
            MetadataFormKeys.opponentName,
            'Alexandra Konstantinopolskaya-Wolkenstein',
          );
          await type(tester, MetadataFormKeys.opponentRating, '9999');
          await type(tester, MetadataFormKeys.playerRating, '9999');
          await type(
            tester,
            MetadataFormKeys.event,
            'Schweizerische Mannschaftsmeisterschaft, 2. Bundesliga',
          );
          await type(tester, MetadataFormKeys.timeControlDetail, '90+30');
          expect(tester.takeException(), isNull);

          // Walk the whole form through the viewport.
          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -2000),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final scale = MediaQuery.textScalerOf(
            tester.element(find.byType(MetadataForm)),
          );
          expect(scale.scale(10), 13);
          expect(
            Theme.of(tester.element(find.byType(MetadataForm))).brightness,
            brightness,
          );
        });
      }
    }
  });
}
