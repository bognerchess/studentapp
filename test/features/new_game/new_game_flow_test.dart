// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:io' show SocketException;

import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/features/consent/ui/ai_consent_screen.dart';
import 'package:bogner_chess/features/entry/ui/entry_identified.dart';
import 'package:bogner_chess/features/entry/ui/entry_screen.dart';
import 'package:bogner_chess/features/import/domain/pending_import.dart';
import 'package:bogner_chess/features/import/ui/import_screen.dart';
import 'package:bogner_chess/features/metadata/ui/metadata_form.dart';
import 'package:bogner_chess/features/metadata/ui/metadata_screen.dart';
import 'package:bogner_chess/features/new_game/ui/new_game_screen.dart';

import 'package:bogner_chess/features/submit_queue/domain/draft_meta.dart';
import 'package:bogner_chess/features/submit_queue/domain/submit_queue_providers.dart';
import 'package:bogner_chess/features/submit_queue/ui/submit_queue_banner.dart';
import 'package:bogner_chess/router.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/board_tester.dart';
import '../../helpers/fixture_link.dart';
import '../../helpers/pump_app.dart';
import '../entry/pump_entry.dart' show EntryTester;
import 'pump_flow.dart';

const _foolsMate = ['f2f3', 'e7e5', 'g2g4', 'd8h4'];
const _foolsMatePgn = '1. f3 e5 2. g4 Qh4#';

const _pgnOfUser = '''
[Event "Club Championship"]
[Site "?"]
[Date "2026.09.12"]
[Round "3"]
[White "Fake User"]
[Black "Jonas Keller"]
[Result "1-0"]
[WhiteElo "1650"]

1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 1-0
''';

const _pgnOfStrangers = '''
[White "Anna Muster"]
[Black "Jonas Keller"]
[Result "0-1"]

1. d4 d5 2. c4 e6 0-1
''';

Finder colorSegment(String label) => find.descendant(
  of: find.byKey(MetadataFormKeys.color),
  matching: find.text(label),
);

FilledButton saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(MetadataScreen.saveKey));

Future<void> openEntry(WidgetTester tester) async {
  routerOf(tester).go(AppRoutes.newGame);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('new-game-entry')));
  await tester.pumpAndSettle();
  expect(find.byType(EntryScreen), findsOneWidget);
}

Future<void> enterFoolsMate(WidgetTester tester) async {
  for (final move in _foolsMate) {
    await tester.playMove(move);
  }
}

Future<void> openImport(WidgetTester tester, String pgn) async {
  routerOf(tester).go(AppRoutes.newGameImport);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('import-field')), pgn);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('import-continue')));
  await tester.pumpAndSettle();
  expect(find.byType(MetadataScreen), findsOneWidget);
}

Future<void> tapSave(WidgetTester tester, {bool analyse = true}) async {
  final key = analyse ? MetadataScreen.saveKey : MetadataScreen.secondaryKey;
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

/// The snack bar lies over the queue banner for its four seconds. A user
/// waits or swipes; the test removes it.
Future<void> dismissSnackBar(WidgetTester tester) async {
  ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
      .removeCurrentSnackBar();
  await tester.pumpAndSettle();
}

/// Lets the snack bar's timer run out before the test ends.
Future<void> finish(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// What the flow itself sent, without what the app shell asks for on its own.
/// `MobileConfig` is the shell's own poll (the "update the app" gate, WP-30);
/// it says nothing about whether a game was submitted, so a test that means
/// "nothing was uploaded" must not trip over it.
List<FixtureRequest> flowRequests(FixtureLink api) => [
  for (final request in api.requests)
    if (request.operationName != 'MobileConfig') request,
];

void main() {
  setUp(() {
    // Haptics of the board.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
  });

  group('board path', () {
    testWidgets('enter → Done → details → Save & analyse → library; the game '
        'and the analysis request reach the server', (tester) async {
      final h = await pumpFlow(tester);
      await openEntry(tester);
      await enterFoolsMate(tester);
      await tester.pump(const Duration(milliseconds: 300));

      // A draft from the first move on.
      final editing = (await h.drafts()).single;
      expect(editing.state, DraftState.editing);
      expect(editing.pgn, _foolsMatePgn);

      await tester.tapEntryControl(EntryIds.done);
      await tester.pumpAndSettle();

      // Prefilled: the result the position implies, today, the account name.
      expect(find.byType(MetadataScreen), findsOneWidget);
      expect(find.text('Save & analyse'), findsOneWidget);
      expect(find.text('Save only'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(MetadataFormKeys.result(GameResult.blackWins)),
            )
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(MetadataFormKeys.playerName))
            .controller!
            .text,
        'Fake User',
      );
      // The board was not turned, so the colour is the user's to say.
      expect(saveButton(tester).onPressed, isNull);

      await tester.tap(colorSegment('Black'));
      await tester.pump();
      await tester.enterText(
        find.byKey(MetadataFormKeys.opponentName),
        'Jonas Keller',
      );
      await tester.pump();
      await tapSave(tester);

      expect(locationOf(tester), AppRoutes.games);
      expect(find.byType(MetadataScreen), findsNothing);
      expect(find.byType(EntryScreen), findsNothing);

      final draft = (await h.drafts()).single;
      expect(draft.id, editing.id);
      expect(draft.state, DraftState.submitted);
      expect(draft.serverGameId, 'game-10');
      expect(draft.wantsAnalysis, isTrue);
      final meta = DraftMeta.decode(draft.metaJson);
      expect(meta.source, DraftSource.board);
      expect(meta.metadata.playerColor, PlayerColor.black);
      expect(meta.metadata.blackName, 'Fake User');
      expect(meta.metadata.whiteName, 'Jonas Keller');
      expect(meta.metadata.result, GameResult.blackWins);
      expect(meta.metadata.playedDate, GameDate.today());

      final input = h.importInput();
      expect(input['clientGameId'], draft.clientGameId);
      expect(input['source'], 'MOBILE_BOARD');
      expect(input['playerColor'], 'BLACK');
      expect(input['pgn'], contains(_foolsMatePgn));
      expect(input['pgn'], contains('[Black "Fake User"]'));
      expect(
        (h.api.requestsOf('RequestGameAnalysis').single.variables['input']
            as Map)['chessGameId'],
        'game-10',
      );
      // The default job sink: the poller finds the job in the database.
      final jobs = await h.db.pendingJobsDao.getActive(kFlowUser.sub);
      expect(jobs.single.jobId, 'job-10');

      // Uploaded: the banner has nothing to say, the snack bar does.
      expect(find.byKey(SubmitQueueBanner.bannerKey), findsNothing);
      expect(
        find.text('Game uploaded. The analysis has started.'),
        findsOneWidget,
      );

      // The New game tab is back at its root, not inside the old flow.
      await dismissSnackBar(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('New game'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NewGameScreen), findsOneWidget);
      expect(find.byType(MetadataScreen), findsNothing);
      expect(find.byType(EntryScreen), findsNothing);
      await finish(tester);
    });

    testWidgets('a turned board says "I played Black"; Save only asks for no '
        'analysis', (tester) async {
      final h = await pumpFlow(tester);
      await openEntry(tester);
      await tester.tapEntryControl(EntryIds.flip);
      await enterFoolsMate(tester);
      await tester.tapEntryControl(EntryIds.done);
      await tester.pumpAndSettle();

      expect(saveButton(tester).onPressed, isNotNull);
      await tapSave(tester, analyse: false);

      expect(locationOf(tester), AppRoutes.games);
      final draft = (await h.drafts()).single;
      expect(draft.state, DraftState.submitted);
      expect(draft.wantsAnalysis, isFalse);
      final meta = DraftMeta.decode(draft.metaJson);
      expect(meta.metadata.playerColor, PlayerColor.black);
      expect(meta.orientation, Side.black);
      expect(h.api.requestsOf('ImportMobileGame'), hasLength(1));
      expect(h.api.requestsOf('RequestGameAnalysis'), isEmpty);
      expect(h.api.requestsOf('MyAiConsent'), isEmpty);
      expect(find.text('Game uploaded.'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('back from the details keeps entering; nothing is queued', (
      tester,
    ) async {
      final h = await pumpFlow(tester);
      await openEntry(tester);
      await enterFoolsMate(tester);
      await tester.tapEntryControl(EntryIds.done);
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(EntryScreen), findsOneWidget);
      expect(tester.entryPgn, _foolsMatePgn);
      expect((await h.drafts()).single.state, DraftState.editing);
      expect(flowRequests(h.api), isEmpty);
    });
  });

  group('import path', () {
    testWidgets('the colour is inferred from the account name; the draft is '
        'created ready and uploaded', (tester) async {
      final h = await pumpFlow(tester);
      await openImport(tester, _pgnOfUser);

      // Facts from the PGN, nothing to choose.
      expect(saveButton(tester).onPressed, isNotNull);
      expect(find.text('Jonas Keller'), findsOneWidget);
      await tapSave(tester);

      expect(locationOf(tester), AppRoutes.games);
      final draft = (await h.drafts()).single;
      expect(draft.state, DraftState.submitted);
      expect(draft.pgn, '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6');
      final meta = DraftMeta.decode(draft.metaJson);
      expect(meta.source, DraftSource.pgn);
      expect(meta.metadata.playerColor, PlayerColor.white);
      expect(meta.metadata.result, GameResult.whiteWins);
      expect(meta.metadata.playedDate, GameDate(2026, 9, 12));
      expect(meta.metadata.eventName, 'Club Championship');
      expect(meta.metadata.whiteRating, 1650);

      final input = h.importInput();
      expect(input['source'], 'MOBILE_PGN');
      expect(input['playerColor'], 'WHITE');
      expect(input['clientGameId'], draft.clientGameId);
      expect(h.api.requestsOf('RequestGameAnalysis'), hasLength(1));
      await finish(tester);
    });

    testWidgets("somebody else's game: the user has to say which side "
        'they were', (tester) async {
      final h = await pumpFlow(tester);
      await openImport(tester, _pgnOfStrangers);

      expect(saveButton(tester).onPressed, isNull);
      expect(find.text('Choose the colour you played.'), findsOneWidget);
      await tester.tap(colorSegment('Black'));
      await tester.pump();
      expect(saveButton(tester).onPressed, isNotNull);
      await tapSave(tester, analyse: false);

      final meta = DraftMeta.decode((await h.drafts()).single.metaJson);
      expect(meta.metadata.playerColor, PlayerColor.black);
      // White and Black are facts of the PGN; choosing a side moves nothing.
      expect(meta.metadata.whiteName, 'Anna Muster');
      expect(meta.metadata.blackName, 'Jonas Keller');
      expect(meta.metadata.playedDate, isNull);
      expect(meta.metadata.result, GameResult.blackWins);
      expect(h.api.requestsOf('RequestGameAnalysis'), isEmpty);
      await finish(tester);
    });

    testWidgets('text from outside the app is sent as a share', (tester) async {
      final h = await pumpFlow(tester);
      containerOf(tester)
          .read(pendingImportProvider.notifier)
          .offer(_pgnOfUser);
      routerOf(tester).go(AppRoutes.newGameImport);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('import-continue')));
      await tester.pumpAndSettle();
      await tapSave(tester, analyse: false);

      expect(h.importInput()['source'], 'MOBILE_SHARE');
      expect(
        DraftMeta.decode((await h.drafts()).single.metaJson).source,
        DraftSource.share,
      );
      await finish(tester);
    });
  });

  group('AI consent', () {
    testWidgets('on record: nobody is asked', (tester) async {
      final h = await pumpFlow(tester);
      await openImport(tester, _pgnOfUser);
      await tapSave(tester);

      expect(h.api.requestsOf('MyAiConsent'), hasLength(1));
      expect(locationOf(tester), AppRoutes.games);
      await finish(tester);
    });

    testWidgets('missing and given: the consent screen opens, then the '
        'analysis is requested', (tester) async {
      final h = await pumpFlow(
        tester,
        api: FixtureLink({'MyAiConsent': 'required'}),
      );
      await openImport(tester, _pgnOfUser);
      await tester.tap(find.byKey(MetadataScreen.saveKey));
      await tester.pumpAndSettle();

      expect(find.byType(AiConsentScreen), findsOneWidget);
      expect(await h.drafts(), isEmpty, reason: 'not saved before the answer');
      // What the consent screen does when the user accepts.
      rootNavigatorKey.currentState!.pop(true);
      await tester.pumpAndSettle();

      expect(locationOf(tester), AppRoutes.games);
      expect((await h.drafts()).single.wantsAnalysis, isTrue);
      expect(h.api.requestsOf('RequestGameAnalysis'), hasLength(1));
      await finish(tester);
    });

    testWidgets('missing and not given: saved without analysis, and said so', (
      tester,
    ) async {
      final h = await pumpFlow(
        tester,
        api: FixtureLink({'MyAiConsent': 'required'}),
      );
      await openImport(tester, _pgnOfUser);
      await tester.tap(find.byKey(MetadataScreen.saveKey));
      await tester.pumpAndSettle();
      rootNavigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      expect(locationOf(tester), AppRoutes.games);
      final draft = (await h.drafts()).single;
      expect(draft.wantsAnalysis, isFalse);
      expect(draft.state, DraftState.submitted);
      expect(h.api.requestsOf('RequestGameAnalysis'), isEmpty);
      await finish(tester);
    });

    testWidgets('the server cannot be asked: the game is saved anyway and the '
        'queue finds out', (tester) async {
      final api = FixtureLink({'RequestGameAnalysis': 'ai_consent_required'})
        ..fail('MyAiConsent', const SocketException('offline'));
      final h = await pumpFlow(tester, api: api);
      await openImport(tester, _pgnOfUser);
      await tapSave(tester);

      final draft = (await h.drafts()).single;
      expect(draft.state, DraftState.submitted);
      expect(
        DraftMeta.decode(draft.metaJson).analysisHold,
        AnalysisHold.aiConsentRequired,
      );
      expect(
        find.text(
          'Game saved. Analysis not started: Your consent to the AI analysis '
          'is missing.',
        ),
        findsOneWidget,
      );
      await finish(tester);
    });
  });

  group('offline and failures', () {
    testWidgets('offline: saved at once, the banner says it waits; back '
        'online it uploads and offers to open the game', (tester) async {
      final h = await pumpFlow(tester, online: false);
      await openImport(tester, _pgnOfUser);
      await tapSave(tester);

      expect(locationOf(tester), AppRoutes.games);
      expect(
        find.text('Game saved. It will be uploaded as soon as you are online.'),
        findsOneWidget,
      );
      expect(find.text('1 game waiting to upload · offline'), findsOneWidget);
      expect(
        flowRequests(h.api),
        isEmpty,
        reason: 'not even the consent question',
      );
      expect((await h.drafts()).single.state, DraftState.ready);

      // The queue was never started in this test; the app does that in
      // main.dart. Start it, so that it listens to the network.
      containerOf(tester)
          .read(submitQueueProvider)
          .start(observeLifecycle: false);
      h.connectivity.set(online: true);
      await tester.pumpAndSettle();

      expect((await h.drafts()).single.state, DraftState.submitted);
      expect(find.byKey(SubmitQueueBanner.bannerKey), findsNothing);
      expect(
        find.text('Game uploaded. The analysis has started.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(locationOf(tester), AppRoutes.game('game-10'));
      await finish(tester);
    });

    testWidgets('the analysis limit is reached: the game is saved and the '
        'reason is said', (tester) async {
      final h = await pumpFlow(
        tester,
        api: FixtureLink({'RequestGameAnalysis': 'limit_reached'}),
      );
      await openImport(tester, _pgnOfUser);
      await tapSave(tester);

      final draft = (await h.drafts()).single;
      expect(draft.state, DraftState.submitted);
      expect(
        DraftMeta.decode(draft.metaJson).analysisHold,
        AnalysisHold.limitReached,
      );
      expect(
        find.text(
          'Game saved. Analysis not started: Your analysis limit is used up.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(SubmitQueueBanner.bannerKey), findsNothing);
      await finish(tester);
    });

    testWidgets('the server is down: the banner offers Retry, and Retry '
        'uploads', (tester) async {
      final api = FixtureLink()
        ..fail('ImportMobileGame', const SocketException('down'));
      final h = await pumpFlow(tester, api: api);
      await openImport(tester, _pgnOfUser);
      await tapSave(tester, analyse: false);

      expect(
        find.text('1 game waiting to upload · will retry automatically'),
        findsOneWidget,
      );
      final waiting = (await h.drafts()).single;
      expect(waiting.state, DraftState.ready);
      expect(waiting.attempts, 1);

      api.use('ImportMobileGame', 'default');
      await dismissSnackBar(tester);
      await tester.tap(find.byKey(SubmitQueueBanner.retryKey));
      await tester.pumpAndSettle();

      expect((await h.drafts()).single.state, DraftState.submitted);
      expect(find.byKey(SubmitQueueBanner.bannerKey), findsNothing);
      await finish(tester);
    });

    testWidgets('a game the server cannot read: failed with the reason, '
        'Retry and Delete in the sheet', (tester) async {
      final h = await pumpFlow(
        tester,
        api: FixtureLink({'ImportMobileGame': 'pgn_invalid'}),
      );
      await openImport(tester, _pgnOfUser);
      await tapSave(tester, analyse: false);

      expect(find.text('1 game could not be uploaded'), findsOneWidget);
      final failed = (await h.drafts()).single;
      expect(failed.state, DraftState.failed);

      await dismissSnackBar(tester);
      await tester.tap(find.byKey(SubmitQueueBanner.bannerKey));
      await tester.pumpAndSettle();
      expect(find.text('Uploads'), findsOneWidget);
      expect(find.text('Fake User – Jonas Keller'), findsOneWidget);
      expect(
        find.textContaining(
          'Not uploaded: The server could not read the moves',
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsWidgets);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this game?'), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(await h.drafts(), isEmpty);
      expect(find.text('All games are uploaded.'), findsOneWidget);
      await finish(tester);
    });
  });

  group('interrupt safety', () {
    testWidgets('a document that arrives while a game is being entered takes '
        'the screen, not the moves', (tester) async {
      final h = await pumpFlow(tester);
      await openEntry(tester);
      await tester.playMove('e2e4');
      await tester.playMove('e7e5');
      await tester.playMoveWithoutSettling('g1f3');
      // No time for the autosave debounce: the document arrives right now.

      // What IncomingLinkService does for "Open in Bogner Chess".
      containerOf(tester)
          .read(pendingImportProvider.notifier)
          .offer(_pgnOfStrangers);
      routerOf(tester).go(AppRoutes.newGameImport);
      await tester.pumpAndSettle();
      expect(find.byType(ImportScreen), findsOneWidget);
      expect(find.byType(EntryScreen), findsNothing);

      final draft = (await h.drafts()).single;
      expect(draft.state, DraftState.editing);
      expect(draft.pgn, '1. e4 e5 2. Nf3');

      // The library resumes it like this.
      routerOf(tester).go(AppRoutes.newGameEntryResume(draft.id));
      await tester.pumpAndSettle();
      expect(tester.entryPgn, '1. e4 e5 2. Nf3');

      // And the resumed draft goes through the rest of the flow.
      await tester.tapEntryControl(EntryIds.done);
      await tester.pumpAndSettle();
      await tester.tap(colorSegment('White'));
      await tester.pump();
      await tapSave(tester, analyse: false);
      final sent = (await h.drafts()).single;
      expect(sent.id, draft.id);
      expect(sent.state, DraftState.submitted);
      expect(h.importInput()['pgn'], contains('1. e4 e5 2. Nf3'));
      await finish(tester);
    });

    testWidgets('a draft that failed to upload can be reopened, corrected and '
        'sent again with its details', (tester) async {
      final api = FixtureLink({'ImportMobileGame': 'pgn_invalid'});
      final h = await pumpFlow(tester, api: api);
      await openEntry(tester);
      await enterFoolsMate(tester);
      await tester.tapEntryControl(EntryIds.done);
      await tester.pumpAndSettle();
      await tester.tap(colorSegment('Black'));
      await tester.pump();
      await tester.enterText(
        find.byKey(MetadataFormKeys.opponentName),
        'Jonas Keller',
      );
      await tester.pump();
      await tapSave(tester, analyse: false);
      final failed = (await h.drafts()).single;
      expect(failed.state, DraftState.failed);

      api.use('ImportMobileGame', 'default');
      routerOf(tester).go(AppRoutes.newGameEntryResume(failed.id));
      await tester.pumpAndSettle();
      expect(tester.entryPgn, _foolsMatePgn);
      expect((await h.drafts()).single.state, DraftState.editing);

      await tester.tapEntryControl(EntryIds.done);
      await tester.pumpAndSettle();
      // The details from the first time are still there.
      expect(find.text('Jonas Keller'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNotNull);
      await tapSave(tester, analyse: false);

      final sent = (await h.drafts()).single;
      expect(sent.state, DraftState.submitted);
      expect(sent.clientGameId, failed.clientGameId);
      await finish(tester);
    });
  });

  group('German and English, large type on a small screen, dark', () {
    for (final locale in const [Locale('en'), Locale('de', 'CH')]) {
      for (final brightness in Brightness.values) {
        testWidgets('$locale ${brightness.name}: the save step and the queue '
            'surface fit', (tester) async {
          final api = FixtureLink()
            ..fail('ImportMobileGame', const SocketException('down'));
          final h = await pumpFlow(
            tester,
            api: api,
            locale: locale,
            brightness: brightness,
            textScale: 1.3,
            screen: kIphoneSe,
          );
          final german = locale.languageCode == 'de';
          await openImport(tester, _pgnOfStrangers);

          expect(
            find.text(german ? 'Speichern & analysieren' : 'Save & analyse'),
            findsOneWidget,
          );
          expect(
            find.text(german ? 'Nur speichern' : 'Save only'),
            findsOneWidget,
          );
          final context = tester.element(find.byType(MetadataScreen));
          expect(MediaQuery.textScalerOf(context).scale(10), 13);
          expect(Theme.of(context).brightness, brightness);
          expect(tester.takeException(), isNull);

          await tester.tap(colorSegment(german ? 'Schwarz' : 'Black'));
          await tester.pump();
          await tapSave(tester, analyse: false);
          expect(tester.takeException(), isNull);
          // The sentence keeps its width; Retry sits underneath it.
          expect(
            tester.getSize(find.byKey(SubmitQueueBanner.bannerKey)).height,
            lessThan(200),
          );

          expect(
            find.text(
              german
                  ? '1 Partie wartet auf den Upload · neuer Versuch folgt '
                        'automatisch'
                  : '1 game waiting to upload · will retry automatically',
            ),
            findsOneWidget,
          );
          expect(
            find.text(german ? 'Erneut versuchen' : 'Retry'),
            findsOneWidget,
          );

          await dismissSnackBar(tester);
          await tester.tap(find.byKey(SubmitQueueBanner.bannerKey));
          await tester.pumpAndSettle();
          expect(find.text('Anna Muster – Jonas Keller'), findsOneWidget);
          expect(
            find.text(
              german
                  ? 'Letzter Versuch fehlgeschlagen: Keine Verbindung zum '
                        'Server. Neuer Versuch folgt automatisch.'
                  : 'Last attempt failed: No connection to the server. Will '
                        'retry automatically.',
            ),
            findsOneWidget,
          );
          expect(find.text(german ? 'Löschen' : 'Delete'), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect((await h.drafts()).single.state, DraftState.ready);
          await finish(tester);
        });
      }
    }
  });
}
