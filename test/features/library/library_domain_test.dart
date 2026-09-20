// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/storage/app_database.dart' show DraftState;
import 'package:bogner_chess/features/analysis_status/domain/job_tracker_providers.dart'
    show newestJob;
import 'package:bogner_chess/features/library/domain/game_summary_codec.dart';
import 'package:bogner_chess/features/library/domain/library_models.dart';
import 'package:flutter_test/flutter_test.dart';

JobInfo job(
  String id,
  JobStatus status, {
  DateTime? requestedAt,
  String? stage,
  int? queuePosition,
}) => JobInfo(
  id: id,
  gameId: 'g',
  status: status,
  stage: stage,
  queuePosition: queuePosition,
  requestedAt: requestedAt ?? DateTime.utc(2026, 9, 19, 10),
  finishedAt: status.isTerminal ? DateTime.utc(2026, 9, 19, 10, 5) : null,
  failureCode: status == JobStatus.failed ? 'engine_timeout' : null,
);

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
      latestJob: job('j1', JobStatus.running, stage: 'coach'),
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
      expect(back.latestJob, full.latestJob);
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
      expect(back.latestJob, isNull);
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
      expect(back.latestJob!.status, JobStatus.unknown);
    });

    test('gameSummaryWith changes job and flag only', () {
      final changed = gameSummaryWith(
        full,
        latestJob: job('j2', JobStatus.done),
        hasAnalysis: false,
      );
      expect(changed.latestJob!.id, 'j2');
      expect(changed.hasAnalysis, isFalse);
      expect(changed.whiteName, full.whiteName);
      expect(changed.playedDate, full.playedDate);
    });
  });

  group('status', () {
    test('of a game', () {
      expect(statusOfGame(hasAnalysis: false), LibraryStatus.notAnalysed);
      expect(statusOfGame(hasAnalysis: true), LibraryStatus.analysisReady);
      expect(
        statusOfGame(hasAnalysis: false, job: job('j', JobStatus.queued)),
        LibraryStatus.analysing,
      );
      expect(
        statusOfGame(hasAnalysis: false, job: job('j', JobStatus.unknown)),
        LibraryStatus.analysing,
      );
      expect(
        statusOfGame(hasAnalysis: false, job: job('j', JobStatus.done)),
        LibraryStatus.analysisReady,
      );
      expect(
        statusOfGame(hasAnalysis: false, job: job('j', JobStatus.failed)),
        LibraryStatus.analysisFailed,
      );
      // A failed re-analysis leaves the old analysis usable.
      expect(
        statusOfGame(hasAnalysis: true, job: job('j', JobStatus.failed)),
        LibraryStatus.analysisReady,
      );
      // A running re-analysis shows as running.
      expect(
        statusOfGame(hasAnalysis: true, job: job('j', JobStatus.running)),
        LibraryStatus.analysing,
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

  group('newestJob', () {
    test('one side missing', () {
      final a = job('a', JobStatus.running);
      expect(newestJob(null, null), isNull);
      expect(newestJob(a, null), a);
      expect(newestJob(null, a), a);
    });

    test(
      'same job: the tracker knows more, unless the server says it ended',
      () {
        final tracked = job('a', JobStatus.running, stage: 'coach');
        expect(newestJob(tracked, job('a', JobStatus.queued)), tracked);
        final done = job('a', JobStatus.done);
        expect(newestJob(tracked, done), done);
        expect(newestJob(done, job('a', JobStatus.running)), done);
      },
    );

    test('different jobs: the later request wins', () {
      final old = job('a', JobStatus.failed);
      final newer = job(
        'b',
        JobStatus.queued,
        requestedAt: DateTime.utc(2026, 9, 20),
      );
      expect(newestJob(old, newer), newer);
      expect(newestJob(newer, old), newer);
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
