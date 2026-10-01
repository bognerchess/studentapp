// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/api/stage_api.dart'
    show AnalysisTargetReason, AnalysisWorkflowState;
import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/storage/app_database.dart' show DraftState;
import 'package:bogner_chess/features/library/domain/game_summary_codec.dart';
import 'package:bogner_chess/features/library/domain/library_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// A pipeline summary with [states] set and everything else not run.
GameWorkflowSummary flow(
  Map<AnalysisStage, AnalysisStageState> states, {
  bool isComplete = false,
  AnalysisWorkflowState state = AnalysisWorkflowState.unknown,
  AnalysisTargetReason? targetReason,
}) => GameWorkflowSummary(
  states: states,
  isComplete: isComplete,
  state: state,
  targetReason: targetReason,
);

const _engineReady = {
  AnalysisStage.baseEvaluation: AnalysisStageState.ready,
  AnalysisStage.baseClassification: AnalysisStageState.ready,
  AnalysisStage.deepEvaluation: AnalysisStageState.ready,
  AnalysisStage.coaching: AnalysisStageState.notRun,
};

void main() {
  group('GameSummaryCodec', () {
    final full = GameSummary(
      id: 'game-1',
      clientGameId: 'c-1',
      whiteName: 'Anna "Ann" Müller',
      blackName: 'Jonas Keller',
      opponentName: 'Jonas Keller',
      whiteRating: 1650,
      blackRating: 1712,
      playerColor: PlayerColor.black,
      result: GameResult.draw,
      playedDate: GameDate(2026, 9, 12),
      eventName: 'Club Championship',
      timeControlTag: '5400+30',
      createdAt: DateTime.utc(2026, 9, 12, 18, 30),
      hasAnalysis: true,
      workflow: flow(_engineReady),
    );

    test('round trip keeps every field', () {
      final back = GameSummaryCodec.decode(GameSummaryCodec.encode(full))!;
      expect(back.id, full.id);
      expect(back.clientGameId, full.clientGameId);
      expect(back.whiteName, full.whiteName);
      expect(back.blackName, full.blackName);
      expect(back.opponentName, full.opponentName);
      expect(back.whiteRating, 1650);
      expect(back.blackRating, 1712);
      expect(back.playerColor, PlayerColor.black);
      expect(back.result, GameResult.draw);
      expect(back.playedDate, GameDate(2026, 9, 12));
      expect(back.eventName, full.eventName);
      expect(back.timeControlTag, '5400+30');
      expect(back.createdAt, full.createdAt);
      expect(back.hasAnalysis, isTrue);
      expect(back.workflow, full.workflow);
    });

    test('version 3 is what is written', () {
      expect(GameSummaryCodec.version, 3);
      expect(GameSummaryCodec.toJson(full)['v'], 3);
    });

    test('a version-2 row has no one-state view and reads its stages', () {
      // What a build before WP-61 wrote: `workflow` without `state`. The stage
      // states are what that row meant, so nothing is lost.
      final back = GameSummaryCodec.decode(
        '{"v":2,"id":"g","playerColor":"white","result":"1-0",'
        '"workflow":{"states":{"BASE_EVALUATION":"READY",'
        '"BASE_CLASSIFICATION":"RUNNING"},"isComplete":false}}',
      )!;
      expect(back.workflow!.state, AnalysisWorkflowState.unknown);
      expect(
        back.workflow!.workflowState,
        AnalysisWorkflowState.analysing,
      );
      expect(back.workflow!.targetReason, isNull);
    });

    test('the one-state view and the reason survive the round trip', () {
      final summary = flow(
        _engineReady,
        state: AnalysisWorkflowState.ready,
        targetReason: AnalysisTargetReason.limitReached,
      );
      final json = GameSummaryCodec.encode(
        gameSummaryWith(full, hasAnalysis: false, workflow: summary),
      );
      final back = GameSummaryCodec.decode(json)!;
      expect(back.workflow!.state, AnalysisWorkflowState.ready);
      expect(
        back.workflow!.targetReason,
        AnalysisTargetReason.limitReached,
      );
    });

    test('a state and a reason of the future read as unknown', () {
      final back = GameSummaryCodec.decode(
        '{"v":3,"id":"g","playerColor":"white","result":"1-0",'
        '"workflow":{"states":{"BASE_EVALUATION":"READY"},'
        '"isComplete":false,"state":"PAUSING",'
        '"targetReason":"COACH_ON_HOLIDAY"}}',
      )!;
      expect(back.workflow!.state, AnalysisWorkflowState.unknown);
      // Read off the stages instead, so the card is never blank.
      expect(back.workflow!.workflowState, AnalysisWorkflowState.ready);
      expect(back.workflow!.targetReason, AnalysisTargetReason.unknown);
    });

    test('a version-1 row reads as a game with no pipeline known, and its '
        'job is dropped', () {
      // What a build before WP-60 wrote: no `workflow` key, and a `job` one
      // for the whole-game path this app no longer drives. The row still
      // shows, the job is read past, and the tracker fills the pipeline in on
      // the next poll.
      final back = GameSummaryCodec.decode(
        '{"v":1,"id":"g","playerColor":"white","result":"1-0",'
        '"hasAnalysis":true,'
        '"job":{"id":"j","gameId":"g","status":"DONE",'
        '"requestedAt":"2026-09-19T10:00:00Z"}}',
      )!;
      expect(back.workflow, isNull);
      expect(back.hasAnalysis, isTrue);
      expect(GameSummaryCodec.toJson(back).containsKey('job'), isFalse);
      expect(
        statusOfGame(hasAnalysis: back.hasAnalysis, workflow: back.workflow),
        LibraryStatus.analysisReady,
      );
    });

    test('a damaged workflow reads as nothing known', () {
      final back = GameSummaryCodec.decode(
        '{"v":2,"id":"g","playerColor":"white","result":"1-0",'
        '"workflow":"nonsense"}',
      )!;
      expect(back.workflow, isNull);
    });

    test('a workflow with a stage this build does not know', () {
      final back = GameSummaryCodec.decode(
        '{"v":2,"id":"g","playerColor":"white","result":"1-0",'
        '"workflow":{"states":{"BASE_EVALUATION":"READY","TAROT":"READY"},'
        '"isComplete":false}}',
      )!;
      expect(
        back.workflow!.stateOf(AnalysisStage.baseEvaluation),
        AnalysisStageState.ready,
      );
      expect(back.workflow!.states, hasLength(1));
    });

    test('a bare game round-trips with nulls', () {
      const bare = GameSummary(
        id: 'g',
        playerColor: PlayerColor.white,
        result: GameResult.unknown,
        hasAnalysis: false,
      );
      final back = GameSummaryCodec.decode(GameSummaryCodec.encode(bare))!;
      expect(back.whiteName, isNull);
      expect(back.playedDate, isNull);
      expect(back.result, GameResult.unknown);
      expect(back.hasAnalysis, isFalse);
    });

    test('unreadable rows are null, not an exception', () {
      expect(GameSummaryCodec.decode('not json'), isNull);
      expect(GameSummaryCodec.decode('[1]'), isNull);
      expect(GameSummaryCodec.decode('{"v":1}'), isNull);
    });

    test('unknown values read tolerantly', () {
      final back = GameSummaryCodec.decode(
        '{"v":9,"id":"g","playerColor":"green","result":"?","extra":1,'
        '"job":{"id":"j","gameId":"g","status":"PAUSED",'
        '"requestedAt":"2026-09-19T10:00:00Z"}}',
      )!;
      expect(back.playerColor, PlayerColor.white);
      expect(back.result, GameResult.unknown);
    });

    test('gameSummaryWith changes the flag only', () {
      final changed = gameSummaryWith(full, hasAnalysis: false);
      expect(changed.hasAnalysis, isFalse);
      expect(changed.whiteName, full.whiteName);
      expect(changed.playedDate, full.playedDate);
      expect(changed.workflow, full.workflow, reason: 'left alone');
    });

    test('gameSummaryWith replaces the pipeline when given one', () {
      final changed = gameSummaryWith(
        full,
        hasAnalysis: true,
        workflow: flow({AnalysisStage.coaching: AnalysisStageState.running}),
      );
      expect(
        changed.workflow!.stateOf(AnalysisStage.coaching),
        AnalysisStageState.running,
      );
    });
  });

  group('status', () {
    test('of a game nothing on this device has analysed', () {
      expect(statusOfGame(hasAnalysis: false), LibraryStatus.notAnalysed);
      expect(statusOfGame(hasAnalysis: true), LibraryStatus.analysisReady);
    });

    test('of a game whose pipeline this device knows', () {
      expect(
        statusOfGame(hasAnalysis: false, workflow: flow(_engineReady)),
        LibraryStatus.engineReady,
        reason: 'kept apart in the enum, the same words on the badge',
      );
      expect(
        statusOfGame(
          hasAnalysis: false,
          workflow: flow({
            ..._engineReady,
            AnalysisStage.coaching: AnalysisStageState.ready,
          }, isComplete: true),
        ),
        LibraryStatus.analysisReady,
      );
      expect(
        statusOfGame(
          hasAnalysis: false,
          workflow: flow({
            AnalysisStage.baseEvaluation: AnalysisStageState.running,
          }),
        ),
        LibraryStatus.analysing,
      );
      expect(
        statusOfGame(
          hasAnalysis: false,
          workflow: flow({
            AnalysisStage.baseEvaluation: AnalysisStageState.queued,
          }),
        ),
        LibraryStatus.analysing,
      );
      expect(
        statusOfGame(
          hasAnalysis: false,
          workflow: flow({
            AnalysisStage.baseEvaluation: AnalysisStageState.ready,
            AnalysisStage.baseClassification: AnalysisStageState.failed,
          }),
        ),
        LibraryStatus.analysisFailed,
      );
      // A coaching step that failed after the engine was done: the failure
      // is what needs the user, as on the game screen.
      expect(
        statusOfGame(
          hasAnalysis: false,
          workflow: flow({
            ..._engineReady,
            AnalysisStage.coaching: AnalysisStageState.failed,
          }),
        ),
        LibraryStatus.analysisFailed,
      );
      // Stage 1 alone is not enough for the badge: there are no variations
      // and no accuracy yet.
      expect(
        statusOfGame(
          hasAnalysis: false,
          workflow: flow({
            AnalysisStage.baseEvaluation: AnalysisStageState.ready,
          }),
        ),
        LibraryStatus.notAnalysed,
      );
      // The coach's document wins, whatever the engine stages say.
      expect(
        statusOfGame(hasAnalysis: true, workflow: flow(_engineReady)),
        LibraryStatus.analysisReady,
      );
      // A pipeline running again over a stored analysis reads as running.
      expect(
        statusOfGame(
          hasAnalysis: true,
          workflow: flow({
            AnalysisStage.baseEvaluation: AnalysisStageState.running,
          }),
        ),
        LibraryStatus.analysing,
      );
    });

    test('the row prefers the tracker to the cached summary', () {
      const game = GameSummary(
        id: 'g',
        playerColor: PlayerColor.white,
        result: GameResult.whiteWins,
        hasAnalysis: false,
        workflow: GameWorkflowSummary(states: {}, isComplete: false),
      );
      expect(LibraryGameRow(game).status, LibraryStatus.notAnalysed);
      expect(
        LibraryGameRow(game, workflow: flow(_engineReady)).status,
        LibraryStatus.engineReady,
      );
    });

    test('of a draft', () {
      expect(statusOfDraft(DraftState.editing), LibraryStatus.draft);
      expect(statusOfDraft(DraftState.ready), LibraryStatus.waitingToUpload);
      expect(
        statusOfDraft(DraftState.submitting),
        LibraryStatus.waitingToUpload,
      );
      expect(statusOfDraft(DraftState.failed), LibraryStatus.uploadFailed);
    });
  });

  group('LibraryFilter', () {
    test('text: case-insensitive contains on any field, trimmed', () {
      const filter = LibraryFilter(text: '  KELL ');
      expect(filter.isActive, isTrue);
      expect(filter.matchesText(['Anna', 'Jonas Keller']), isTrue);
      expect(filter.matchesText([null, 'Anna']), isFalse);
      expect(
        const LibraryFilter(text: 'ØST').matchesText(['Mira Østergård']),
        isTrue,
      );
      expect(const LibraryFilter().matchesText([null]), isTrue);
    });

    test('dates: inclusive, undated games are out', () {
      final filter = LibraryFilter(
        from: GameDate(2026, 9, 5),
        to: GameDate(2026, 9, 12),
      );
      expect(filter.matchesDate(GameDate(2026, 9, 5)), isTrue);
      expect(filter.matchesDate(GameDate(2026, 9, 12)), isTrue);
      expect(filter.matchesDate(GameDate(2026, 9, 13)), isFalse);
      expect(filter.matchesDate(null), isFalse);
      expect(const LibraryFilter().matchesDate(null), isTrue);
    });

    test('equality ignores case and outer spaces', () {
      expect(
        const LibraryFilter(text: ' Kell'),
        const LibraryFilter(text: 'kell '),
      );
      expect(const LibraryFilter(text: ' ').isActive, isFalse);
    });
  });
}
