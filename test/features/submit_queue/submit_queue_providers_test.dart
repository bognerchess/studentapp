// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analysis/analysis_job_sink.dart';
import 'package:bogner_chess/core/api/analysis_api.dart';
import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/connectivity/connectivity.dart';
import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/game/library_refresh.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:bogner_chess/features/submit_queue/domain/draft_meta.dart';
import 'package:bogner_chess/features/submit_queue/domain/submit_models.dart';
import 'package:bogner_chess/features/submit_queue/domain/submit_queue_providers.dart';
import 'package:bogner_chess/features/submit_queue/ui/submit_queue_banner.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/storage/test_database.dart';
import '../../helpers/pump_app.dart';
import 'fakes.dart';

const _metadata = GameMetadata(playerColor: PlayerColor.white);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late AppDatabase db;
  late FakeGamesApi games;
  late FakeAnalysisApi analysis;
  late FakeConnectivity connectivity;

  ProviderContainer container({AuthState auth = const SignedOut()}) {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        gamesApiProvider.overrideWithValue(games),
        analysisApiProvider.overrideWithValue(analysis),
        connectivityProvider.overrideWithValue(connectivity),
        apiLanguageTagProvider.overrideWithValue(() => 'de-CH'),
        authStateProvider.overrideWith(() => TestAuthNotifier(auth)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    db = openTestDatabase(FakeClock());
    games = FakeGamesApi();
    analysis = FakeAnalysisApi();
    connectivity = FakeConnectivity();
  });

  tearDown(() => db.close());

  test('signing in is a trigger; the library is told, the job is recorded, '
      'the coach speaks the system language', () async {
    await db.draftsDao.create(
      alice,
      pgn: '1. e4',
      metaJson: const DraftMeta(metadata: _metadata).encode(),
      ready: true,
    );
    final c = container();
    final statuses = <SubmitQueueStatus>[];
    c.listen(submitQueueStatusProvider, (_, next) => statuses.add(next));
    final events = <SubmitEvent>[];
    c.listen(submitQueueEventsProvider, (_, next) {
      if (next.value case final event?) events.add(event);
    });
    c.read(submitQueueProvider).start(observeLifecycle: false);
    await _settle();
    expect(games.calls, isEmpty, reason: 'nobody is signed in');

    (c.read(authStateProvider.notifier) as TestAuthNotifier).set(
      const SignedIn(alice),
    );
    await _settle();

    expect(games.calls, hasLength(1));
    expect(analysis.calls.single.language, 'de');
    expect(c.read(libraryRefreshProvider), 1);
    expect((await db.pendingJobsDao.getActive(alice)).single.gameId, 'game-1');
    expect(events.single, isA<GameUploaded>());
    expect(statuses.any((s) => s.uploading), isTrue);
    expect(statuses.last, SubmitQueueStatus.idle);
    expect(c.read(submitQueueStatusProvider), SubmitQueueStatus.idle);
  });

  test('signing out empties the status; the drafts stay', () async {
    connectivity.online = false;
    final c = container(auth: const SignedIn(alice));
    await c
        .read(submitQueueProvider)
        .enqueueImport(
          movetext: '1. e4',
          metadata: _metadata,
          source: DraftSource.pgn,
          analyse: false,
        );
    await _settle();
    expect(c.read(submitQueueStatusProvider).waiting, 1);
    expect(c.read(submitQueueStatusProvider).offline, isTrue);

    (c.read(authStateProvider.notifier) as TestAuthNotifier).set(
      const SignedOut(),
    );
    await _settle();
    expect(c.read(submitQueueStatusProvider).waiting, 0);
    expect(await db.draftsDao.getAll(alice), hasLength(1));
  });

  test('analysisHoldProvider: the reason by server game id', () async {
    analysis.outcomes.add(const AnalysisQueueFull(2));
    final c = container(auth: const SignedIn(alice));
    await c
        .read(submitQueueProvider)
        .enqueueImport(
          movetext: '1. e4',
          metadata: _metadata,
          source: DraftSource.pgn,
          analyse: true,
        );
    await _settle();

    final holds = <AnalysisHold?>[];
    c.listen(
      analysisHoldProvider('game-1'),
      (_, next) => holds.add(next.value),
      fireImmediately: true,
    );
    await _settle();
    expect(holds.last, AnalysisHold.queueFull);
    final other = c.listen(analysisHoldProvider('game-2'), (_, _) {});
    await _settle();
    expect(other.read().value, isNull);
  });

  test('the default job sink ignores a job when nobody is signed in', () async {
    final c = container();
    c
        .read(analysisJobSinkProvider)
        .track(
          JobInfo(
            id: 'job-1',
            gameId: 'game-1',
            status: JobStatus.running,
            requestedAt: DateTime.utc(2026),
          ),
        );
    await _settle();
    expect(await db.pendingJobsDao.getActive(alice), isEmpty);
  });

  test('coachLanguageOf', () {
    expect(coachLanguageOf('de-CH'), 'de');
    expect(coachLanguageOf('de'), 'de');
    expect(coachLanguageOf('en_US'), 'en');
    expect(coachLanguageOf('fr-CH'), 'en');
    expect(coachLanguageOf(''), 'en');
  });

  test('the banner sentence for every state, in both languages', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final de = await AppLocalizations.delegate.load(const Locale('de'));
    String text(AppLocalizations l10n, SubmitQueueStatus status) =>
        SubmitQueueBanner.textOf(l10n, status);

    expect(
      text(en, const SubmitQueueStatus(waiting: 2, uploading: true)),
      'Uploading 2 games…',
    );
    expect(
      text(en, const SubmitQueueStatus(waiting: 1, offline: true)),
      '1 game waiting to upload · offline',
    );
    expect(
      text(en, const SubmitQueueStatus(waiting: 3)),
      '3 games waiting to upload',
    );
    expect(
      text(en, const SubmitQueueStatus(failed: 2)),
      '2 games could not be uploaded',
    );
    expect(
      text(
        de,
        SubmitQueueStatus(waiting: 2, nextAttemptAt: DateTime.utc(2026)),
      ),
      '2 Partien warten auf den Upload · neuer Versuch folgt automatisch',
    );
    expect(
      text(de, const SubmitQueueStatus(waiting: 1, offline: true)),
      '1 Partie wartet auf den Upload · offline',
    );
    expect(
      text(de, const SubmitQueueStatus(failed: 1)),
      '1 Partie konnte nicht hochgeladen werden',
    );
    // Waiting games win over failed ones; the sheet lists both.
    expect(
      text(en, const SubmitQueueStatus(waiting: 1, failed: 1)),
      '1 game waiting to upload',
    );
  });
}
