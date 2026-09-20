// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';
import 'dart:io';

import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/api/analysis_api.dart' as api;
import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/features/library/data/cached_games_repository.dart';
import 'package:bogner_chess/features/review/data/api_review_repository.dart';
import 'package:bogner_chess/features/review/data/local_feedback_store.dart';
import 'package:bogner_chess/features/review/domain/review_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/api/api_test_support.dart';
import '../../core/storage/test_database.dart';
import '../../helpers/fixture_link.dart';

/// Rated up, down and with an unknown value in `GameAnalysis/default.json`.
const _up = '322b7d97-32b5-4bc3-9f81-475368d0ef1c';
const _down = '0e60df92-f823-4d99-a5e3-82cbad3c3ba1';

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late FixtureLink link;
  late CachedGamesRepository games;
  late ApiReviewRepository repository;
  String? owner;

  setUp(() {
    clock = FakeClock();
    db = openTestDatabase(clock);
    link = FixtureLink();
    final executor = linkExecutor(link);
    games = CachedGamesRepository(api: GamesApi(executor), db: db);
    owner = alice;
    repository = ApiReviewRepository(
      analysisApi: api.AnalysisApi(executor),
      games: games,
      db: db,
      owner: () => owner,
    );
  });
  tearDown(() => db.close());

  int fetches() => link.requestsOf('GameAnalysis').length;

  test('cache miss: fetched, stored with its schema version, header from the '
      'library, feedback from the server', () async {
    await games.fetchPage(alice, fetchedAt: games.now());

    final data = await repository.load('game-1');
    expect(data.result, isA<AnalysisSupported>());
    expect(fetches(), 1);
    expect(link.requestsOf('GameAnalysis').single.variables, {
      'gameId': 'game-1',
      'maxSchemaVersion': kMaxSupportedAnalysisSchema,
    });
    expect(data.header.white, 'Fake User');
    expect(data.header.black, 'Jonas Keller');
    expect(data.header.result, '1-0');
    expect(data.header.date, DateTime(2026, 9, 12));
    expect(data.myFeedback[_up], CommentRating.up);
    expect(data.myFeedback[_down], CommentRating.down);
    expect(data.myFeedback, hasLength(2), reason: 'the unknown rating is none');

    final cached = (await db.analysisCacheDao.get(alice, 'game-1'))!;
    expect(cached.schemaVersion, 1);
    expect(cached.schemaMinor, 0);
    expect(
      AnalysisParser.parseString(cached.payload),
      isA<AnalysisSupported>(),
    );
  });

  test('cache hit: no request, works offline, thumbs remembered', () async {
    await games.fetchPage(alice, fetchedAt: games.now());
    await repository.load('game-1');
    link
      ..fail('GameAnalysis', const SocketException('offline'))
      ..fail('GameById', const SocketException('offline'));

    final data = await repository.load('game-1');
    expect(fetches(), 1);
    expect(data.result, isA<AnalysisSupported>());
    expect(data.myFeedback[_up], CommentRating.up);
    expect(data.header.black, 'Jonas Keller');
  });

  test('a newer finished job makes the cached copy stale', () async {
    await games.fetchPage(alice, fetchedAt: games.now());
    await repository.load('game-1');
    expect(fetches(), 1);

    // The game is analysed again, later.
    clock.advance(const Duration(hours: 1));
    await games.applyJob(
      alice,
      JobInfo(
        id: 'job-again',
        gameId: 'game-1',
        status: JobStatus.done,
        requestedAt: clock().subtract(const Duration(minutes: 3)),
        finishedAt: clock(),
      ),
      hasAnalysis: true,
    );
    await repository.load('game-1');
    expect(fetches(), 2);

    // Now the copy is as new as the job.
    await repository.load('game-1');
    expect(fetches(), 2);
  });

  test('stale but offline: the cached copy is shown', () async {
    await games.fetchPage(alice, fetchedAt: games.now());
    await repository.load('game-1');
    clock.advance(const Duration(hours: 1));
    await games.applyJob(
      alice,
      JobInfo(
        id: 'job-again',
        gameId: 'game-1',
        status: JobStatus.done,
        requestedAt: clock(),
        finishedAt: clock(),
      ),
    );
    link.fail('GameAnalysis', const SocketException('offline'));
    expect((await repository.load('game-1')).result, isA<AnalysisSupported>());
  });

  test('nothing cached and offline: the error is thrown', () async {
    link.fail('GameAnalysis', const SocketException('offline'));
    await expectLater(
      repository.load('game-1'),
      throwsA(isA<api.ApiNetworkError>()),
    );
  });

  test('the server has no analysis: AnalysisNotAvailable', () async {
    link.use('GameAnalysis', 'none');
    await expectLater(
      repository.load('game-1'),
      throwsA(isA<AnalysisNotAvailable>()),
    );
  });

  test('a newer major version is handed over and cached as such', () async {
    link.use('GameAnalysis', 'newer_major');
    final data = await repository.load('game-1');
    expect(data.result, isA<AnalysisNewerMajor>());
    expect(data.myFeedback, isEmpty);
    expect((await db.analysisCacheDao.get(alice, 'game-1'))!.schemaVersion, 2);

    // From the cache it is the same.
    expect((await repository.load('game-1')).result, isA<AnalysisNewerMajor>());
    expect(fetches(), 1);
  });

  test('an invalid document is handed over, and asked for again', () async {
    link.use('GameAnalysis', 'invalid_document');
    expect((await repository.load('game-1')).result, isA<AnalysisInvalid>());

    link.use('GameAnalysis', 'default');
    expect((await repository.load('game-1')).result, isA<AnalysisSupported>());
    expect(fetches(), 2);
  });

  test('a game the library never listed: header from GameById', () async {
    final data = await repository.load('game-1');
    expect(link.requestsOf('GameById'), hasLength(1));
    expect(data.header.white, 'Fake User');

    // And without a connection the header is simply empty.
    await db.gamesCacheDao.remove(alice, 'game-1');
    await db.analysisCacheDao.put(
      alice,
      'game-1',
      schemaVersion: 1,
      schemaMinor: 0,
      payload: jsonEncode(link.store.json('analysis/v1/short-game.json')),
    );
    link.fail('GameById', const SocketException('offline'));
    final offline = await repository.load('game-1');
    expect(offline.header.white, isNull);
    expect(offline.result, isA<AnalysisSupported>());
  });

  test('a thumb waiting in the outbox beats the server', () async {
    await db.feedbackOutboxDao.put(alice, _up, FeedbackRating.down);
    await LocalFeedbackStore(db).write(alice, _up, CommentRating.down);

    final data = await repository.load('game-1');
    expect(data.myFeedback[_up], CommentRating.down);
    expect(data.myFeedback[_down], CommentRating.down);
  });

  test(
    'signed out: unauthenticated; another account has its own cache',
    () async {
      await repository.load('game-1');
      owner = null;
      await expectLater(
        repository.load('game-1'),
        throwsA(isA<api.ApiUnauthenticated>()),
      );
      owner = bob;
      await repository.load('game-1');
      expect(fetches(), 2);
    },
  );
}
