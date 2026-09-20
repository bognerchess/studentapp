// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';
import 'dart:io';

import 'package:bogner_chess/core/analysis/analysis_parser.dart'
    show AnalysisParser;
import 'package:bogner_chess/core/api/account_api.dart';
import 'package:bogner_chess/core/api/analysis_api.dart';
import 'package:bogner_chess/core/api/config_api.dart';
import 'package:bogner_chess/core/api/devices_api.dart';
import 'package:bogner_chess/core/api/events_api.dart';
import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/api/legal_api.dart';
import 'package:bogner_chess/core/api/mappers/game_mapper.dart';
import 'package:bogner_chess/core/api/scalars.dart';
import 'package:bogner_chess/core/api/usage_api.dart';
import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixture_link.dart';
import 'api_test_support.dart';

void main() {
  late FixtureLink link;

  setUp(() => link = FixtureLink());

  GamesApi games() => GamesApi(linkExecutor(link));
  AnalysisApi analysis() => AnalysisApi(linkExecutor(link));
  LegalApi legal() => LegalApi(linkExecutor(link));

  group('scalars', () {
    test('DateTime is UTC whatever offset the server used', () {
      expect(
        dateTimeFromJson('2026-09-20T00:00:00+02:00'),
        DateTime.utc(2026, 9, 19, 22),
      );
      expect(dateTimeFromJson('2026-09-19T22:00:00.000Z').isUtc, isTrue);
      expect(
        dateTimeToJson(DateTime.utc(2026, 9, 19, 22, 0, 0, 5)),
        '2026-09-19T22:00:00.005Z',
      );
      expect(() => dateTimeFromJson(12), throwsFormatException);
      expect(() => dateTimeFromJson('yesterday'), throwsFormatException);
    });

    test('LocalDate is a calendar date, and nothing when malformed', () {
      expect(localDateFromJson('2026-09-19'), GameDate(2026, 9, 19));
      expect(localDateFromJson('2026-02-30'), isNull);
      expect(localDateFromJson('not-a-date'), isNull);
      expect(localDateFromJson(null), isNull);
      expect(localDateToJson(GameDate(2026, 1, 5)), '2026-01-05');
    });
  });

  group('GamesApi.list', () {
    test('maps a page', () async {
      final page = await games().list();

      expect(page.totalCount, 3);
      expect(page.hasNextPage, isFalse);
      expect(page.endCursor, 'c3');
      expect(page.games.map((g) => g.id), ['game-1', 'game-2', 'game-3']);

      final first = page.games.first;
      expect(first.clientGameId, '3f0e1c52-7b1d-4a53-9c55-0d8a1b2c3d41');
      expect(first.playerColor, PlayerColor.white);
      expect(first.result, GameResult.whiteWins);
      expect(first.whiteName, 'Fake User');
      expect(first.blackName, 'Jonas Keller');
      expect(first.opponentName, 'Jonas Keller');
      expect(first.whiteRating, 1650);
      expect(first.blackRating, 1712);
      expect(first.playedDate, GameDate(2026, 9, 12));
      expect(first.eventName, 'Club Championship');
      expect(first.timeControlTag, '5400+30');
      expect(first.timeControl?.detail, '90+30');
      expect(first.plyCount, isNull);
      expect(first.createdAt, DateTime.utc(2026, 9, 12, 18, 30));
      expect(first.hasAnalysis, isTrue);
      expect(first.latestJob?.status, JobStatus.done);
      expect(
        first.latestJob?.finishedAt,
        DateTime.utc(2026, 9, 12, 18, 34, 10),
      );

      final second = page.games[1];
      expect(second.playerColor, PlayerColor.black);
      expect(second.result, GameResult.draw);
      expect(second.latestJob?.status, JobStatus.running);
      expect(second.latestJob?.stage, 'engine');
      expect(second.hasAnalysis, isFalse);

      final third = page.games[2];
      expect(third.playedDate, isNull);
      expect(third.eventName, isNull);
      expect(third.whiteName, isNull);
      expect(third.displayOpponentName, 'Anonymous');
      expect(third.latestJob, isNull);
      expect(third.toString(), isNot(contains('Anonymous')));
    });

    test('sends filter and paging, trims the search, caps the page', () async {
      await games().list(
        search: '  keller ',
        playedFrom: GameDate(2026, 9, 1),
        playedTo: GameDate(2026, 9, 30),
        first: 500,
        after: 'c2',
      );
      expect(link.requests.single.variables, {
        'search': 'keller',
        'playedFrom': '2026-09-01',
        'playedTo': '2026-09-30',
        'first': 50,
        'after': 'c2',
      });

      await games().list(search: '   ');
      expect(link.requests.last.variables, {'first': 20});
    });

    test('pages, the empty library and a null connection', () async {
      link.use('MyMobileGames', 'first_page');
      final first = await games().list(first: 2);
      expect(first.hasNextPage, isTrue);
      expect(first.endCursor, 'c2');

      link.use('MyMobileGames', 'empty');
      final empty = await games().list();
      expect(empty.games, isEmpty);
      expect(empty.endCursor, isNull);

      link.use('MyMobileGames', 'null_connection');
      final none = await games().list();
      expect(none.games, isEmpty);
      expect(none.totalCount, 0);
    });

    test(
      'enum values and dates this build does not know do not crash',
      () async {
        link.use('MyMobileGames', 'unknown_enums');
        final game = (await games().list()).games.single;
        expect(game.playerColor, PlayerColor.white);
        expect(game.result, GameResult.unknown);
        expect(game.playedDate, isNull);
        expect(game.latestJob?.status, JobStatus.unknown);
        expect(game.latestJob?.status.isActive, isTrue);
        expect(game.latestJob?.queuePosition, isNull);
      },
    );

    test('a transport failure is thrown as an ApiError', () async {
      link.fail('MyMobileGames', const SocketException('offline'));
      await expectLater(games().list(), throwsA(const ApiNetworkError()));
    });
  });

  group('GamesApi.get', () {
    test('maps the detail and counts the plies', () async {
      final game = (await games().get('game-1'))!;
      expect(link.requests.single.variables, {'id': 'game-1'});
      expect(game.id, 'game-1');
      expect(game.pgn, contains('7. Qf3+ Ke6'));
      expect(game.plyCount, 15);
      expect(game.startingFen, isNull);
      expect(game.hasAnalysis, isTrue);
      expect(game.latestJob?.id, 'job-1');
    });

    test('null when the game does not exist', () async {
      link.use('GameById', 'not_found');
      expect(await games().get('nope'), isNull);
    });

    test('a PGN that cannot be read has no ply count', () async {
      link.use('GameById', 'unreadable_pgn');
      final game = (await games().get('game-3'))!;
      expect(game.plyCount, anyOf(isNull, lessThan(4)));
      expect(game.site, isNull, reason: 'blank text reads as null');
    });
  });

  group('GamesApi.import', () {
    final metadata = GameMetadata.forPlayer(
      playerColor: PlayerColor.black,
      playerName: 'Roman "the Rook" Weis',
      opponentName: r'Back\slash',
      playerRating: 1650,
      opponentRating: 1712,
      result: GameResult.blackWins,
      playedDate: GameDate(2026, 9, 19),
      eventName: 'Club night',
      timeControl: const TimeControl(TimeControlKind.rapid, detail: '10+5'),
    );

    test('sends the PGN, the metadata and the idempotency key', () async {
      final outcome = await games().import(
        metadata: metadata,
        movetext: '1. e4 e5 2. Nf3',
        clientGameId: 'client-1',
        source: ImportSource.share,
      );

      expect(outcome, isA<GameImported>());
      expect((outcome as GameImported).game.id, 'game-10');
      final input =
          link.requests.single.variables['input'] as Map<String, dynamic>;
      expect(input['clientGameId'], 'client-1');
      expect(input['source'], 'MOBILE_SHARE');
      expect(input['playerColor'], 'BLACK');
      expect(input['result'], 'BLACK_WINS');
      expect(input['playedDate'], '2026-09-19');
      expect(input['eventName'], 'Club night');
      expect(input['timeControl'], '600+5');
      expect(input['whitePlayerName'], r'Back\slash');
      expect(input['blackPlayerName'], 'Roman "the Rook" Weis');
      expect(input['opponentName'], r'Back\slash');
      expect(input['playerElo'], 1650);
      expect(input['opponentElo'], 1712);
      final pgn = input['pgn'] as String;
      expect(pgn, contains(r'[Black "Roman \"the Rook\" Weis"]'));
      expect(pgn, contains(r'[White "Back\\slash"]'));
      expect(pgn, contains('[Date "2026.09.19"]'));
      expect(pgn, endsWith('\n\n1. e4 e5 2. Nf3 0-1\n'));
    });

    test('the sources', () async {
      for (final (source, wire) in [
        (ImportSource.board, 'MOBILE_BOARD'),
        (ImportSource.pgn, 'MOBILE_PGN'),
      ]) {
        await games().import(
          metadata: metadata,
          movetext: '1. e4',
          clientGameId: 'c',
          source: source,
        );
        expect((link.requests.last.variables['input'] as Map)['source'], wire);
      }
    });

    test(
      'an unknown result is left to the PGN; unknown values are left out',
      () async {
        await games().import(
          metadata: const GameMetadata(playerColor: PlayerColor.white),
          movetext: '1. d4 *',
          clientGameId: 'c',
          source: ImportSource.board,
        );
        final input = link.requests.single.variables['input'] as Map;
        expect(input.keys, {'clientGameId', 'pgn', 'playerColor', 'source'});
        expect(input['pgn'], endsWith('\n\n1. d4 *\n'));
      },
    );

    test('buildImportPgn does not double a result token', () {
      const meta = GameMetadata(result: GameResult.draw);
      expect(
        buildImportPgn(meta, '1. e4 e5 1/2-1/2'),
        endsWith('1. e4 e5 1/2-1/2\n'),
      );
      expect(
        buildImportPgn(meta, ' 1. e4 e5 \n'),
        endsWith('1. e4 e5 1/2-1/2\n'),
      );
      expect(buildImportPgn(meta, ''), endsWith('\n\n1/2-1/2\n'));
    });

    test('without the player colour nothing is sent', () async {
      final outcome = await games().import(
        metadata: const GameMetadata(),
        movetext: '1. e4',
        clientGameId: 'c',
        source: ImportSource.pgn,
      );
      expect(
        (outcome as ImportFailed).error,
        isA<ApiRejected>().having(
          (e) => e.propertyName,
          'property',
          'playerColor',
        ),
      );
      expect(link.requests, isEmpty);
    });

    Future<ImportOutcome> importWith(String scenario) {
      link.use('ImportMobileGame', scenario);
      return games().import(
        metadata: metadata,
        movetext: '1. e4',
        clientGameId: 'c',
        source: ImportSource.pgn,
      );
    }

    test('typed errors are outcomes', () async {
      final invalid = await importWith('pgn_invalid') as ImportPgnInvalid;
      expect(invalid.moveNumber, 7);
      expect(invalid.san, 'Qxf9');

      final vague =
          await importWith('pgn_invalid_without_move') as ImportPgnInvalid;
      expect(vague.moveNumber, isNull);
      expect(vague.san, isNull);

      final limited = await importWith('rate_limited') as ImportRateLimited;
      expect(limited.retryAfter, const Duration(seconds: 42));
    });

    test('everything else is a failure, never an exception', () async {
      expect(
        (await importWith('input_invalid') as ImportFailed).error,
        const ApiRejected(
          typename: 'InputValidationError',
          messageKey: 'web_api_errors.pgn_too_long',
          propertyName: 'Pgn',
        ),
      );
      expect(
        ((await importWith(
          'technical_error',
        ) as ImportFailed).error).isRetryable,
        isTrue,
      );
      expect(
        (await importWith('business_error') as ImportFailed).error.isRetryable,
        isFalse,
      );
      expect(
        (await importWith('unknown_error') as ImportFailed).error,
        const ApiRejected(typename: 'SomethingNewError'),
      );
      expect(
        (await importWith('empty_payload') as ImportFailed).error,
        isA<ApiServerError>(),
      );

      link.fail('ImportMobileGame', const SocketException('offline'));
      final offline = await games().import(
        metadata: metadata,
        movetext: '1. e4',
        clientGameId: 'c',
        source: ImportSource.pgn,
      );
      expect((offline as ImportFailed).error, const ApiNetworkError());
    });
  });

  group('GamesApi.delete', () {
    test('deleted', () async {
      expect(await games().delete('game-1'), isA<GameDeleted>());
      expect(link.requests.single.variables, {
        'input': {'chessGameId': 'game-1'},
      });
    });

    test('failures', () async {
      link.use('DeleteChessGame', 'business_error');
      final failed = await games().delete('game-1') as DeleteGameFailed;
      expect(
        failed.error,
        const ApiRejected(
          typename: 'BusinessError',
          messageKey: 'web_api_errors.entity_not_found',
        ),
      );
      link.fail('DeleteChessGame', const SocketException('offline'));
      expect(
        (await games().delete('game-1') as DeleteGameFailed).error,
        const ApiNetworkError(),
      );
    });
  });

  group('AnalysisApi.request', () {
    Future<RequestAnalysisOutcome> requestWith(String scenario) {
      link.use('RequestGameAnalysis', scenario);
      return analysis().request(
        gameId: 'game-10',
        language: 'DE',
        deviceId: 'd-1',
      );
    }

    test('accepted', () async {
      final outcome = await requestWith('default') as AnalysisAccepted;
      expect(outcome.job.id, 'job-10');
      expect(outcome.job.gameId, 'game-10');
      expect(outcome.job.status, JobStatus.queued);
      expect(outcome.job.queuePosition, 0);
      expect(outcome.job.requestedAt, DateTime.utc(2026, 9, 19, 10));
      expect(link.requests.single.variables, {
        'input': {
          'chessGameId': 'game-10',
          'deviceId': 'd-1',
          'language': 'de',
        },
      });
    });

    test(
      'limit reached, by day, by month and by a window of the future',
      () async {
        final day = await requestWith('limit_reached') as AnalysisLimitReached;
        expect(day.window, LimitWindow.day);
        expect(day.limit, 3);
        expect(day.used, 3);
        expect(day.resetAt, DateTime.utc(2026, 9, 19, 22));

        final month =
            await requestWith('limit_reached_month') as AnalysisLimitReached;
        expect(month.window, LimitWindow.month);
        expect(month.limit, 30);

        final week = await requestWith(
          'limit_reached_unknown_window',
        ) as AnalysisLimitReached;
        expect(week.window, LimitWindow.unknown);
        expect(
          week.resetAt,
          DateTime.utc(2026, 9, 20, 22),
          reason: 'offset to UTC',
        );
      },
    );

    test('the other typed outcomes', () async {
      expect(
        (await requestWith('queue_full') as AnalysisQueueFull).maxQueuedJobs,
        2,
      );
      expect(
        (await requestWith('rate_limited') as AnalysisRateLimited).retryAfter,
        const Duration(seconds: 42),
      );
      expect(
        await requestWith('email_not_verified'),
        isA<AnalysisEmailNotVerified>(),
      );
      expect(
        (await requestWith(
          'ai_consent_required',
        ) as AnalysisAiConsentRequired).requiredVersion,
        1,
      );
    });

    test('generic and unknown errors are failures', () async {
      expect(
        (await requestWith('business_error') as AnalysisRequestFailed).error,
        const ApiRejected(
          typename: 'BusinessError',
          messageKey: 'web_api_errors.analysis_already_in_progress',
        ),
      );
      expect(
        (await requestWith('input_invalid') as AnalysisRequestFailed).error,
        isA<ApiRejected>().having(
          (e) => e.propertyName,
          'property',
          'Language',
        ),
      );
      expect(
        (await requestWith('unknown_error') as AnalysisRequestFailed).error,
        const ApiRejected(typename: 'SomethingNewError'),
      );
      link.fail('RequestGameAnalysis', const SocketException('offline'));
      final offline = await analysis().request(gameId: 'g');
      expect((offline as AnalysisRequestFailed).error.isRetryable, isTrue);
    });

    test('a typed error without its fields degrades to a failure', () async {
      link.respond(
        'RequestGameAnalysis',
        (_) => {
          'data': {
            'requestGameAnalysis': {
              'analysisJob': null,
              'errors': [
                {'__typename': 'AnalysisLimitReachedError'},
              ],
            },
          },
        },
      );
      // The generated fromJson insists on the fields the schema promises, so
      // this is a malformed response rather than a limit.
      final outcome = await analysis().request(gameId: 'g');
      expect((outcome as AnalysisRequestFailed).error, isA<ApiServerError>());
    });
  });

  group('AnalysisApi jobs', () {
    test('every status', () async {
      for (final (scenario, status) in [
        ('default', JobStatus.queued),
        ('running', JobStatus.running),
        ('done', JobStatus.done),
        ('failed', JobStatus.failed),
        ('unknown_status', JobStatus.unknown),
      ]) {
        link.use('AnalysisJob', scenario);
        expect((await analysis().job('job-1'))?.status, status);
      }
    });

    test('details', () async {
      link.use('AnalysisJob', 'default');
      expect((await analysis().job('job-1'))?.queuePosition, 2);

      link.use('AnalysisJob', 'running');
      final running = (await analysis().job('job-1'))!;
      expect(running.stage, 'coach');
      expect(running.queuePosition, isNull, reason: 'only while queued');
      expect(running.status.isActive, isTrue);

      link.use('AnalysisJob', 'failed');
      final failed = (await analysis().job('job-1'))!;
      expect(failed.failureCode, 'engine_timeout');
      expect(failed.status.isTerminal, isTrue);
      expect(failed.finishedAt, DateTime.utc(2026, 9, 19, 10, 3, 30));

      link.use('AnalysisJob', 'not_found');
      expect(await analysis().job('nope'), isNull);
    });

    test('active jobs', () async {
      final jobs = await analysis().activeJobs();
      expect(jobs.map((j) => (j.id, j.status)), [
        ('job-2', JobStatus.running),
        ('job-3', JobStatus.queued),
      ]);
      link.use('MyActiveAnalysisJobs', 'empty');
      expect(await analysis().activeJobs(), isEmpty);
    });
  });

  group('AnalysisApi.analysis', () {
    test(
      'raw JSON for the cache, the parsed document and the feedback',
      () async {
        final fetched = (await analysis().analysis('game-1'))!;

        expect(link.requests.single.variables, {
          'gameId': 'game-1',
          'maxSchemaVersion': 1,
        });
        expect(fetched.id, 'analysis-1');
        expect(fetched.gameId, 'game-1');
        expect(fetched.schemaVersion, 1);
        expect(fetched.createdAt, DateTime.utc(2026, 9, 19, 9, 20, 7));

        final document = (fetched.parsed as AnalysisSupported).document;
        expect(document.plyCount, 80);
        expect(document.comments, hasLength(8));

        // What the cache stores parses to the same document after a restart.
        final vendored = jsonDecode(
          File('test/fixtures/analysis/v1/forty-move-game.json')
              .readAsStringSync(),
        );
        expect(jsonDecode(fetched.rawJson), vendored);
        final again = AnalysisParser.parseString(fetched.rawJson);
        expect(
          (again as AnalysisSupported).document.analysisId,
          document.analysisId,
        );

        // The rating this build does not know is dropped.
        expect(fetched.feedback, {
          '322b7d97-32b5-4bc3-9f81-475368d0ef1c': CommentRating.up,
          '0e60df92-f823-4d99-a5e3-82cbad3c3ba1': CommentRating.down,
        });
      },
    );

    test('the other vendored documents', () async {
      for (final (scenario, plies) in [
        ('short_game', 21),
        ('fallback_case', 33),
      ]) {
        link.use('GameAnalysis', scenario);
        final fetched = (await analysis().analysis('game-1'))!;
        expect((fetched.parsed as AnalysisSupported).document.plyCount, plies);
        expect(fetched.feedback, isEmpty);
      }
      link.use('GameAnalysis', 'with_unknowns');
      final unknowns = (await analysis().analysis('game-1'))!;
      expect(unknowns.schemaMinor, 7);
      expect(unknowns.parsed, isA<AnalysisSupported>());
    });

    test('a newer major version is served and recognised', () async {
      link.use('GameAnalysis', 'newer_major');
      final fetched = (await analysis().analysis('game-1'))!;
      expect(fetched.schemaVersion, 2);
      final partial = (fetched.parsed as AnalysisNewerMajor).partial;
      expect(partial.moves, hasLength(21));
    });

    test('a document that is not one is invalid, not a crash', () async {
      link.use('GameAnalysis', 'invalid_document');
      final fetched = (await analysis().analysis('game-1'))!;
      expect(fetched.parsed, isA<AnalysisInvalid>());
    });

    test('none yet', () async {
      link.use('GameAnalysis', 'none');
      expect(await analysis().analysis('game-1'), isNull);
    });
  });

  group('AnalysisApi.submitFeedback', () {
    test('up, down and clear', () async {
      expect(
        await analysis().submitFeedback(
          commentId: 'c',
          rating: CommentRating.up,
        ),
        CommentRating.up,
      );
      expect(link.requests.last.variables, {
        'input': {'commentId': 'c', 'rating': 'UP'},
      });

      link.use('SubmitCoachCommentFeedback', 'down');
      expect(
        await analysis().submitFeedback(
          commentId: 'c',
          rating: CommentRating.down,
        ),
        CommentRating.down,
      );

      link.use('SubmitCoachCommentFeedback', 'cleared');
      expect(
        await analysis().submitFeedback(commentId: 'c', rating: null),
        isNull,
      );
      expect(link.requests.last.variables, {
        'input': {'commentId': 'c'},
      });
    });

    test('errors are thrown', () async {
      link.use('SubmitCoachCommentFeedback', 'business_error');
      await expectLater(
        analysis().submitFeedback(commentId: 'c', rating: CommentRating.up),
        throwsA(
          const ApiRejected(
            typename: 'BusinessError',
            messageKey: 'web_api_errors.comment_not_found',
          ),
        ),
      );
    });
  });

  group('UsageApi', () {
    UsageApi usage() => UsageApi(linkExecutor(link));

    test('default', () async {
      final u = await usage().usage();
      expect(u.policy, UsagePolicy.standard);
      expect(u.dailyLimit, 3);
      expect(u.dailyUsed, 1);
      expect(u.dailyRemaining, 2);
      expect(u.dailyResetAt, DateTime.utc(2026, 9, 19, 22));
      expect(u.monthlyRemaining, 18);
      expect(u.queuedJobs, 1);
      expect(u.maxQueuedJobs, 2);
      expect(u.canRequest, isTrue);
    });

    test('limit reached, unlimited and an unknown policy', () async {
      link.use('MyAnalysisUsage', 'limit_reached');
      final reached = await usage().usage();
      expect(reached.dailyRemaining, 0);
      expect(reached.canRequest, isFalse);

      link.use('MyAnalysisUsage', 'unlimited');
      final unlimited = await usage().usage();
      expect(unlimited.policy, UsagePolicy.unlimited);
      expect(unlimited.dailyLimit, isNull);
      expect(unlimited.dailyRemaining, isNull);
      expect(unlimited.canRequest, isTrue);

      link.use('MyAnalysisUsage', 'unknown_policy');
      final unknown = await usage().usage();
      expect(unknown.policy, UsagePolicy.unknown);
      expect(unknown.dailyResetAt, DateTime.utc(2026, 9, 19, 22));
    });
  });

  group('ConfigApi', () {
    test('default', () async {
      final config = await ConfigApi(linkExecutor(link)).mobileConfig();
      expect(config.minSupportedAppVersion, '0.1.0');
      expect(config.maxAnalysisSchemaVersion, 1);
      expect(config.supportedCoachLanguages, ['en', 'de']);
      expect(config.jobPollInterval, const Duration(seconds: 3));
      expect(config.isEnabled('eval_graph'), isTrue);
      expect(config.isEnabled('push'), isFalse);
      expect(config.isEnabled('never heard of'), isFalse);
      expect(config.currentAiConsentVersion, 1);
      expect(config.coachLanguageFor('DE'), 'de');
      expect(config.coachLanguageFor('fr'), 'en');
    });

    test('a nonsensical poll interval is clamped', () async {
      link.use('MobileConfig', 'update_required');
      final config = await ConfigApi(linkExecutor(link)).mobileConfig();
      expect(config.jobPollInterval, const Duration(seconds: 1));
      expect(config.minSupportedAppVersion, '9.0.0');
    });
  });

  group('DevicesApi and EventsApi', () {
    DevicesApi devices() => DevicesApi(linkExecutor(link));
    EventsApi events() => EventsApi(linkExecutor(link));

    test('register', () async {
      final device = await devices().register(
        deviceId: 'installation-1',
        environment: ApnsEnvironment.production,
        apnsToken: 'abcdef',
        appVersion: '0.1.0+1',
        locale: 'de-CH',
      );
      expect(device.id, 'device-1');
      expect(device.lastSeenAt, DateTime.utc(2026, 9, 19, 10));
      expect(device.revokedAt, isNull);
      expect(link.requests.single.variables, {
        'input': {
          'deviceId': 'installation-1',
          'apnsToken': 'abcdef',
          'environment': 'PRODUCTION',
          'appVersion': '0.1.0+1',
          'locale': 'de-CH',
        },
      });
    });

    test('a rate limit carries its delay', () async {
      link.use('RegisterMobileDevice', 'rate_limited');
      await expectLater(
        devices().register(deviceId: 'd', environment: ApnsEnvironment.sandbox),
        throwsA(
          isA<ApiRejected>()
              .having((e) => e.typename, 'typename', 'RateLimitedError')
              .having(
                (e) => e.retryAfter,
                'retryAfter',
                const Duration(seconds: 42),
              )
              .having((e) => e.isRetryable, 'isRetryable', isTrue),
        ),
      );
    });

    test('unregister', () async {
      final device = await devices().unregister('installation-1');
      expect(device?.revokedAt, DateTime.utc(2026, 9, 19, 11));

      link.use('UnregisterMobileDevice', 'unknown_device');
      expect(await devices().unregister('installation-1'), isNull);
    });

    test('track sends a batch', () async {
      link.use('TrackMobileEvents', 'partially_rejected');
      final result = await events().track(
        deviceId: 'd-1',
        sessionId: 's-1',
        appVersion: '0.1.0+1',
        events: [
          AnalyticsEvent(
            name: 'analysis_requested',
            occurredAt: DateTime.utc(2026, 9, 19, 10),
            props: const {'source': 'board', 'plies': 80},
          ),
          AnalyticsEvent(
            name: 'app_opened',
            occurredAt: DateTime.utc(2026, 9, 19, 9),
          ),
        ],
      );
      expect(result.accepted, 2);
      expect(result.rejected, 1);
      expect(link.requests.single.variables, {
        'input': {
          'deviceId': 'd-1',
          'sessionId': 's-1',
          'appVersion': '0.1.0+1',
          'events': [
            {
              'name': 'analysis_requested',
              'occurredAt': '2026-09-19T10:00:00.000Z',
              'props': {'source': 'board', 'plies': 80},
            },
            {'name': 'app_opened', 'occurredAt': '2026-09-19T09:00:00.000Z'},
          ],
        },
      });
    });

    test(
      'track: an empty batch needs no request, a big one is a bug',
      () async {
        final none = await events().track(
          deviceId: 'd',
          sessionId: 's',
          events: [],
        );
        expect(none.accepted, 0);
        expect(link.requests, isEmpty);

        final tooMany = List.generate(
          51,
          (i) => AnalyticsEvent(name: 'e$i', occurredAt: DateTime.utc(2026)),
        );
        expect(
          () => events().track(deviceId: 'd', sessionId: 's', events: tooMany),
          throwsArgumentError,
        );
      },
    );
  });

  group('LegalApi', () {
    test('document', () async {
      link.use('LegalDocument', 'ai_consent_de');
      final document = (await legal().document(
        LegalDocumentKey.aiConsent,
        language: 'DE',
      ))!;
      expect(link.requests.single.variables, {
        'key': 'AI_CONSENT',
        'language': 'de',
      });
      expect(document.key, LegalDocumentKey.aiConsent);
      expect(document.version, 1);
      expect(document.language, 'de');
      expect(document.title, 'KI-Analyse deiner Partien');
      expect(document.bodyMarkdown, contains('Sprachmodell'));
      expect(document.providerName, 'Example AI Provider');
      expect(document.isDraft, isTrue);
      expect(document.publishedAt, DateTime.utc(2026, 9));
    });

    test('nothing published, and a key of the future', () async {
      link.use('LegalDocument', 'not_found');
      expect(await legal().document(LegalDocumentKey.terms), isNull);

      link.use('LegalDocument', 'unknown_key');
      expect(
        (await legal().document(LegalDocumentKey.terms))?.key,
        LegalDocumentKey.unknown,
      );
      expect(
        () => legal().document(LegalDocumentKey.unknown),
        throwsArgumentError,
      );
    });

    test('AI consent status', () async {
      link.use('MyAiConsent', 'required');
      final required = await legal().aiConsent();
      expect(required.key, LegalDocumentKey.aiConsent);
      expect(required.required, isTrue);
      expect(required.acceptedVersion, isNull);

      link.use('MyAiConsent', 'new_version');
      final renewed = await legal().aiConsent();
      expect(renewed.currentVersion, 2);
      expect(renewed.acceptedVersion, 1);
      expect(renewed.required, isTrue);

      link.use('MyAiConsent', 'default');
      expect((await legal().aiConsent()).required, isFalse);
    });

    test('consent status of another key', () async {
      link.use('MyConsent', 'withdrawn');
      final status = await legal().consent(LegalDocumentKey.analyticsConsent);
      expect(link.requests.single.variables, {'key': 'ANALYTICS_CONSENT'});
      expect(status.key, LegalDocumentKey.analyticsConsent);
      expect(status.required, isTrue);
      expect(status.withdrawnAt, DateTime.utc(2026, 9, 18, 8));
    });

    test('record', () async {
      final ai = await legal().recordAiConsent(version: 1, deviceId: 'd-1');
      expect(ai.required, isFalse);
      expect(link.requests.last.variables, {
        'input': {'version': 1, 'deviceId': 'd-1'},
      });

      link.use('RecordConsent', 'withdrawn');
      final withdrawn = await legal().recordConsent(
        key: LegalDocumentKey.analyticsConsent,
        version: 1,
        accepted: false,
      );
      expect(withdrawn.acceptedVersion, isNull);
      expect(withdrawn.withdrawnAt, isNotNull);
      expect(link.requests.last.variables, {
        'input': {'key': 'ANALYTICS_CONSENT', 'version': 1, 'accepted': false},
      });
    });

    test('a version that is not published', () async {
      link.use('RecordAiConsent', 'input_invalid');
      await expectLater(
        legal().recordAiConsent(version: 9),
        throwsA(
          isA<ApiRejected>().having(
            (e) => e.propertyName,
            'property',
            'Version',
          ),
        ),
      );
    });
  });

  group('AccountApi', () {
    AccountApi account() => AccountApi(linkExecutor(link));

    test('sends the confirmation phrase', () async {
      final outcome =
          await account().deleteMyAccount() as AccountDeletionRequested;
      expect(outcome.deletion.status, AccountDeletionStatus.pending);
      expect(outcome.deletion.completedAt, isNull);
      expect(link.requests.single.variables, {
        'input': {'confirmation': 'DELETE'},
      });
    });

    test('completed, blocked, unknown status, failures', () async {
      link.use('DeleteMyAccount', 'completed');
      final done =
          await account().deleteMyAccount() as AccountDeletionRequested;
      expect(done.deletion.status, AccountDeletionStatus.completed);
      expect(done.deletion.completedAt, DateTime.utc(2026, 9, 19, 10, 0, 2));

      link.use('DeleteMyAccount', 'blocked');
      final blocked =
          await account().deleteMyAccount() as AccountDeletionBlocked;
      expect(blocked.reason, 'owns_club');

      link.use('DeleteMyAccount', 'unknown_status');
      final odd = await account().deleteMyAccount() as AccountDeletionRequested;
      expect(odd.deletion.status, AccountDeletionStatus.unknown);

      link.use('DeleteMyAccount', 'technical_error');
      final failed = await account().deleteMyAccount() as AccountDeletionFailed;
      expect(failed.error.isRetryable, isTrue);

      link.fail('DeleteMyAccount', const SocketException('offline'));
      expect(
        (await account().deleteMyAccount() as AccountDeletionFailed).error,
        const ApiNetworkError(),
      );
    });
  });

  group('FixtureLink', () {
    test('names the scenarios when one does not exist', () async {
      link.use('MobileConfig', 'nope');
      await expectLater(
        ConfigApi(linkExecutor(link)).mobileConfig(),
        throwsA(isA<ApiServerError>()),
      );
      expect(
        () => link.store.response('MobileConfig', 'nope'),
        throwsA(
          isA<FixtureNotFound>().having(
            (e) => e.toString(),
            'message',
            contains('default, update_required'),
          ),
        ),
      );
    });
  });
}
