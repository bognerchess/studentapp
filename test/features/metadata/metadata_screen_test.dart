// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/features/metadata/ui/metadata_form.dart';
import 'package:bogner_chess/features/metadata/ui/metadata_screen.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

/// Opens the screen the way a flow does and keeps what it pops with.
class Opened {
  GameMetadata? result;
  bool closed = false;
}

Future<Opened> open(WidgetTester tester, [MetadataScreenArgs? args]) async {
  final opened = Opened();
  final future = routerOf(tester)
      .push<GameMetadata>(AppRoutes.newGameMetadata, extra: args);
  // Not awaited: it completes when the screen closes.
  unawaited(
    future.then((result) {
      opened
        ..result = result
        ..closed = true;
    }),
  );
  await tester.pumpAndSettle();
  return opened;
}

FilledButton saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(MetadataScreen.saveKey));

Finder colorSegment(String label) => find.descendant(
  of: find.byKey(MetadataFormKeys.color),
  matching: find.text(label),
);

void main() {
  testWidgets('Save waits for the colour and returns the metadata', (
    tester,
  ) async {
    await pumpApp(tester);
    final opened = await open(
      tester,
      const MetadataScreenArgs(defaultPlayerName: 'Max Muster'),
    );

    expect(find.text('Game details'), findsOneWidget);
    // Full screen: the tab bar is covered.
    expect(find.byType(NavigationBar), findsNothing);
    expect(saveButton(tester).onPressed, isNull);
    expect(find.text('Choose the colour you played.'), findsOneWidget);

    await tester.tap(colorSegment('Black'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0-1'));
    await tester.enterText(
      find.byKey(MetadataFormKeys.opponentName),
      'Anna Schmidt',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(MetadataScreen.saveHintKey), findsNothing);
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(MetadataScreen.saveKey));
    await tester.pumpAndSettle();

    expect(opened.closed, isTrue);
    final result = opened.result!;
    expect(result.playerColor, PlayerColor.black);
    expect(result.whiteName, 'Anna Schmidt');
    expect(result.blackName, 'Max Muster');
    expect(result.result, GameResult.blackWins);
    // The default date made it into the result although nobody touched it.
    expect(result.playedDate, GameDate.today());
    expect(result.validate().isValid, isTrue);
    expect(locationOf(tester), AppRoutes.games);
  });

  testWidgets('an invalid rating blocks Save and says why', (tester) async {
    await pumpApp(tester);
    await open(
      tester,
      const MetadataScreenArgs(
        initial: GameMetadata(playerColor: PlayerColor.white),
      ),
    );
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.enterText(find.byKey(MetadataFormKeys.playerRating), '5000');
    await tester.pumpAndSettle();

    expect(saveButton(tester).onPressed, isNull);
    expect(find.text('Check the marked fields.'), findsOneWidget);
    expect(find.text('100–3500'), findsOneWidget);

    await tester.enterText(find.byKey(MetadataFormKeys.playerRating), '1500');
    await tester.pumpAndSettle();
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('back returns nothing', (tester) async {
    await pumpApp(tester);
    final opened = await open(tester);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(opened.closed, isTrue);
    expect(opened.result, isNull);
  });

  testWidgets('an existing game opens with its facts and no made-up date', (
    tester,
  ) async {
    await pumpApp(tester);
    final initial = GameMetadata.fromPgnHeaders(const {
      'White': 'Beispiel, Bettina',
      'Black': 'Muster, Max',
      'Result': '1-0',
    }, playerName: 'Max Muster');
    final opened = await open(
      tester,
      MetadataScreenArgs.existingGame(initial: initial),
    );

    expect(find.text('You lost.'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(MetadataScreen.saveKey));
    await tester.pumpAndSettle();
    expect(opened.result, initial);
    expect(opened.result!.playedDate, isNull);
  });

  testWidgets('a deep link without arguments shows the empty form', (
    tester,
  ) async {
    await pumpApp(tester);
    routerOf(tester).go(AppRoutes.newGameMetadata);
    await tester.pumpAndSettle();

    expect(find.byType(MetadataScreen), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
    expect(
      routerOf(tester).namedLocation(AppRouteNames.newGameMetadata),
      AppRoutes.newGameMetadata,
    );
  });

  testWidgets('German, dark, text scale 1.3 on the smallest iPhone', (
    tester,
  ) async {
    await pumpApp(
      tester,
      locale: const Locale('de'),
      brightness: Brightness.dark,
      textScale: 1.3,
      screen: kIphoneSe,
    );
    await open(tester);

    expect(find.text('Angaben zur Partie'), findsOneWidget);
    expect(find.text('Speichern'), findsOneWidget);
    expect(find.text('Wähle die Farbe, die du hattest.'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(MetadataForm))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });
}
