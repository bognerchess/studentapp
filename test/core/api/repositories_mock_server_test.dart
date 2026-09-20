// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/account_api.dart';
import 'package:bogner_chess/core/api/analysis_api.dart';
import 'package:bogner_chess/core/api/api_client.dart';
import 'package:bogner_chess/core/api/config_api.dart';
import 'package:bogner_chess/core/api/devices_api.dart';
import 'package:bogner_chess/core/api/events_api.dart';
import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/api/generated/operations/config.graphql.dart';
import 'package:bogner_chess/core/api/legal_api.dart';
import 'package:bogner_chess/core/api/usage_api.dart';
import 'package:bogner_chess/core/auth/fake_auth_repository.dart';
import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/mock_server/mock_server.dart';
import 'api_test_support.dart';

/// The repositories over the real link chain and real HTTP, against the mock
/// server in this process: what the app does with `config/fake.json`.
void main() {
  late MockServer server;
  late FakeAuthRepository auth;
  late ApiExecutor executor;

  Future<void> start([MockOptions? options]) async {
    server = await MockServer.start(
      backend: MockBackend(options: options ?? MockOptions()),
    );
    auth = FakeAuthRepository();
    executor = chainExecutor(auth: auth, apiUrl: server.graphqlUri);
  }

  setUp(start);

  tearDown(() async {
    await server.close();
    await auth.dispose();
  });

  final metadata = GameMetadata.forPlayer(
    playerColor: PlayerColor.white,
    playerName: 'Fake User',
    opponentName: 'Ada Lovelace',
    result: GameResult.whiteWins,
    playedDate: GameDate(2026, 9, 18),
    eventName: 'Club night',
    timeControl: const TimeControl(TimeControlKind.rapid, detail: '15+10'),
  );

  Future<GameSummary> importGame(String clientGameId) async {
    final outcome = await GamesApi(executor).import(
      metadata: metadata,
      movetext: '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6',
      clientGameId: clientGameId,
      source: ImportSource.board,
    );
    return (outcome as GameImported).game;
  }

  test('the whole loop: consent, import, analysis, poll, review, feedback, '
      'limit, delete', () async {
    final games = GamesApi(executor);
    final analysis = AnalysisApi(executor);
    final legal = LegalApi(executor);
    final usage = UsageApi(executor);

    // The fake token and the headers reach the server.
    final config = await ConfigApi(executor).mobileConfig();
    expect(config.supportedCoachLanguages, ['en', 'de']);
    final seen = server.requests.single;
    expect(seen.headers['authorization'], 'Bearer $kFakeAccessToken');
    expect(seen.headers['x-tenant-slug'], 'test-tenant');
    expect(seen.headers['graphql-preflight'], '1');
    expect(seen.headers['accept-language'], 'de-CH');
    expect(seen.headers['user-agent'], 'BognerChess-iOS/0.1.0+1');

    // Import, idempotent per clientGameId.
    final game = await importGame('client-1');
    expect((await importGame('client-1')).id, game.id);
    expect(game.clientGameId, 'client-1');
    expect(game.opponentName, 'Ada Lovelace');
    expect(game.playedDate, GameDate(2026, 9, 18));
    expect(game.timeControl?.detail, '15+10');
    expect(game.result, GameResult.whiteWins);

    final page = await games.list(search: 'lovelace');
    expect(page.games.single.id, game.id);
    expect((await games.list()).totalCount, 4);
    final detail = (await games.get(game.id))!;
    expect(detail.plyCount, 6);
    expect(detail.pgn, contains('[Event "Club night"]'));

    // Consent first.
    final refused = await analysis.request(gameId: game.id, language: 'de');
    expect((refused as AnalysisAiConsentRequired).requiredVersion, 1);
    final consent = await legal.aiConsent();
    expect(consent.required, isTrue);
    final text = (await legal.document(
      LegalDocumentKey.aiConsent,
      language: 'de',
    ))!;
    expect(text.language, 'de');
    expect(text.version, consent.currentVersion);
    expect(
      (await legal.recordAiConsent(version: text.version)).required,
      isFalse,
    );

    // Request, poll until done.
    final accepted = await analysis.request(gameId: game.id, language: 'de');
    var job = (accepted as AnalysisAccepted).job;
    expect(job.status, JobStatus.queued);
    expect((await games.get(game.id))?.latestJob?.id, job.id);
    expect((await analysis.activeJobs()).map((j) => j.id), contains(job.id));
    expect(await analysis.analysis(game.id), isNull);

    final statuses = <JobStatus>[];
    for (var i = 0; i < 10 && !job.status.isTerminal; i++) {
      job = (await analysis.job(job.id))!;
      statuses.add(job.status);
    }
    expect(statuses, containsAllInOrder([JobStatus.running, JobStatus.done]));
    expect(job.finishedAt, isNotNull);
    expect((await games.get(game.id))?.hasAnalysis, isTrue);

    // Review and feedback.
    final fetched = (await analysis.analysis(game.id))!;
    final document = (fetched.parsed as AnalysisSupported).document;
    expect(document.plyCount, 80);
    expect(document.language, 'de');
    expect(fetched.feedback, isEmpty);
    final comment = document.comments.first;
    expect(
      await analysis.submitFeedback(
        commentId: comment.id,
        rating: CommentRating.down,
      ),
      CommentRating.down,
    );
    expect((await analysis.analysis(game.id))?.feedback, {
      comment.id: CommentRating.down,
    });
    expect(
      await analysis.submitFeedback(commentId: comment.id, rating: null),
      isNull,
    );
    expect((await analysis.analysis(game.id))?.feedback, isEmpty);
    await expectLater(
      analysis.submitFeedback(commentId: 'nope', rating: CommentRating.up),
      throwsA(isA<ApiRejected>()),
    );

    // The accepted request counts against the quota.
    expect((await usage.usage()).dailyUsed, 1);
  });

  test('the fourth analysis of the day reaches the limit', () async {
    await server.close();
    await start(MockOptions(queuedPolls: 0, runningPolls: 0));
    final analysis = AnalysisApi(executor);
    await LegalApi(executor).recordAiConsent(version: 1);

    for (var i = 1; i <= 3; i++) {
      final game = await importGame('client-$i');
      final job =
          ((await analysis.request(gameId: game.id)) as AnalysisAccepted).job;
      expect((await analysis.job(job.id))?.status, JobStatus.done);
    }
    final usage = await UsageApi(executor).usage();
    expect(usage.dailyUsed, 3);
    expect(usage.dailyRemaining, 0);
    expect(usage.canRequest, isFalse);

    final game = await importGame('client-4');
    final outcome = await analysis.request(gameId: game.id);
    final limit = outcome as AnalysisLimitReached;
    expect(limit.window, LimitWindow.day);
    expect(limit.limit, 3);
    expect(limit.used, 3);
    expect(limit.resetAt.isUtc, isTrue);
    expect(limit.resetAt.isAfter(DateTime.now()), isTrue);
    expect(limit.resetAt, usage.dailyResetAt);
  });

  test('scenarios: e-mail not verified, failing job, invalid PGN', () async {
    final analysis = AnalysisApi(executor);
    server.backend.applyScenario('consent_accepted', const {});
    final game = await importGame('client-1');

    server.backend.applyScenario('email_not_verified', const {});
    expect(
      await analysis.request(gameId: game.id),
      isA<AnalysisEmailNotVerified>(),
    );

    server.backend.applyScenario('default', const {});
    server.backend.applyScenario('job_fails', const {});
    var job =
        ((await analysis.request(gameId: game.id)) as AnalysisAccepted).job;
    while (!job.status.isTerminal) {
      job = (await analysis.job(job.id))!;
    }
    expect(job.status, JobStatus.failed);
    expect(job.failureCode, 'engine_timeout');

    final invalid = await GamesApi(executor).import(
      metadata: metadata,
      movetext: '1. e4 e5 2. Zz9',
      clientGameId: 'client-2',
      source: ImportSource.pgn,
    );
    expect((invalid as ImportPgnInvalid).san, 'Zz9');
    expect(invalid.moveNumber, 2);
  });

  test('unauthenticated_once: one refresh, one retry, the caller notices '
      'nothing', () async {
    server.backend.applyScenario('unauthenticated_once', const {});

    final page = await GamesApi(executor).list();

    expect(page.totalCount, 3);
    expect(server.requests.map((r) => r.status), [401, 200]);
  });

  test('signed out: no request reaches the server', () async {
    await auth.signOut();
    await expectLater(
      GamesApi(executor).list(),
      throwsA(const ApiUnauthenticated()),
    );
    expect(server.requests, isEmpty);
  });

  test('slow: the time limit of the call applies', () async {
    server.backend.applyScenario('slow', const {'delayMs': 400});
    await expectLater(
      executor.query(
        document: documentNodeQueryMobileConfig,
        operationName: 'MobileConfig',
        parse: Query$MobileConfig.fromJson,
        timeout: const Duration(milliseconds: 50),
      ),
      throwsA(const ApiNetworkError(ApiNetworkCause.timeout)),
    );
  });

  test('a server that is not there is a network error', () async {
    final uri = server.graphqlUri;
    await server.close();
    final offline = chainExecutor(auth: auth, apiUrl: uri);
    await expectLater(
      ConfigApi(offline).mobileConfig(),
      throwsA(const ApiNetworkError()),
    );
  });

  test('devices, events, consents and account deletion', () async {
    final devices = DevicesApi(executor);
    final registered = await devices.register(
      deviceId: 'installation-1',
      environment: ApnsEnvironment.sandbox,
      appVersion: '0.1.0+1',
      locale: 'de-CH',
    );
    expect(registered.deviceId, 'installation-1');
    expect((await devices.unregister('installation-1'))?.revokedAt, isNotNull);
    expect(await devices.unregister('never-seen'), isNull);

    final events = EventsApi(executor);
    final event = AnalyticsEvent(
      name: 'app_opened',
      occurredAt: DateTime.utc(2026, 9, 19, 10),
      props: const {'cold': true},
    );
    expect(
      (await events.track(
        deviceId: 'd',
        sessionId: 's',
        events: [event],
      )).accepted,
      1,
    );

    final legal = LegalApi(executor);
    expect(
      (await legal.consent(LegalDocumentKey.analyticsConsent)).required,
      isTrue,
    );
    final withdrawn = await legal.recordConsent(
      key: LegalDocumentKey.analyticsConsent,
      version: 1,
      accepted: false,
    );
    expect(withdrawn.withdrawnAt, isNotNull);
    expect(
      (await events.track(
        deviceId: 'd',
        sessionId: 's',
        events: [event],
      )).rejected,
      1,
    );
    final accepted = await legal.recordConsent(
      key: LegalDocumentKey.analyticsConsent,
      version: 1,
      accepted: true,
    );
    expect(accepted.required, isFalse);
    await expectLater(
      legal.recordAiConsent(version: 99),
      throwsA(
        isA<ApiRejected>().having((e) => e.propertyName, 'property', 'Version'),
      ),
    );

    final games = GamesApi(executor);
    expect(await games.delete('game-3'), isA<GameDeleted>());
    expect(await games.delete('game-3'), isA<DeleteGameFailed>());

    final account = AccountApi(executor);
    server.backend.applyScenario('deletion_blocked', const {});
    expect(await account.deleteMyAccount(), isA<AccountDeletionBlocked>());
    server.backend.applyScenario('default', const {});
    final deleted = await account.deleteMyAccount() as AccountDeletionRequested;
    expect(deleted.deletion.status, AccountDeletionStatus.pending);
    expect((await games.list()).games, isEmpty);
  });
}
