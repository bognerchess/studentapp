// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/analysis_api.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:bogner_chess/features/analysis_status/domain/job_tracker_providers.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fixture_link.dart';
import '../../helpers/pump_app.dart';

/// A job that has just finished, for [JobTracker.track], which takes the
/// short way to the same event a poll produces.
JobInfo finished(String gameId, {bool ok = true, String? failureCode}) =>
    JobInfo(
      id: 'job-finished-$gameId',
      gameId: gameId,
      status: ok ? JobStatus.done : JobStatus.failed,
      requestedAt: DateTime.utc(2026, 9, 19, 10),
      finishedAt: DateTime.utc(2026, 9, 19, 10, 3),
      failureCode: failureCode,
    );

void main() {
  late AppDatabase db;
  late FixtureLink api;

  setUp(() {
    db = openWidgetTestDatabase();
    // Nothing is running: the tracker only reports what this test hands it.
    api = FixtureLink({'MyActiveAnalysisJobs': 'empty'});
  });
  tearDown(() => db.close());

  List<Override> overrides() => [
    appDatabaseProvider.overrideWithValue(db),
    ...api.overrides,
  ];

  Future<void> report(WidgetTester tester, JobInfo job) async {
    await containerOf(tester).read(jobTrackerProvider).track(job);
    await tester.pumpAndSettle();
  }

  testWidgets('a finished analysis is announced with the opponent', (
    tester,
  ) async {
    await pumpApp(tester, overrides: overrides());
    await report(tester, finished('game-1'));

    expect(
      find.text('Your game against Jonas Keller has been analysed.'),
      findsOneWidget,
    );
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('the notice goes away by itself', (tester) async {
    await pumpApp(tester, overrides: overrides());
    await report(tester, finished('game-1'));
    expect(find.byType(SnackBar), findsOneWidget);

    // Long enough for the eight seconds the notice asks for, and then some:
    // a notice that stays for ever sits over the tab bar and the last row.
    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failed analysis says the limit is untouched', (tester) async {
    await pumpApp(tester, overrides: overrides());
    await report(tester, finished('game-1', ok: false, failureCode: 'oom'));

    expect(
      find.text("An analysis failed. It doesn't count towards your limit."),
      findsOneWidget,
    );
    expect(find.text('View'), findsOneWidget);
  });

  testWidgets('nothing is said on the screen of that very game', (
    tester,
  ) async {
    await pumpApp(tester, overrides: overrides());
    await tester.tap(find.text('Fake User – Jonas Keller'));
    await tester.pumpAndSettle();
    expect(
      routerOf(tester).routerDelegate.currentConfiguration.last.matchedLocation,
      AppRoutes.game('game-1'),
    );

    // That screen turns into the ready card by itself; a snack bar over it
    // would only cover the button it just grew.
    await report(tester, finished('game-1'));
    expect(find.byType(SnackBar), findsNothing);

    // Another game's analysis is still worth saying.
    await report(tester, finished('game-3'));
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('German', (tester) async {
    await pumpApp(tester, locale: const Locale('de'), overrides: overrides());
    await report(tester, finished('game-1'));

    expect(
      find.text('Deine Partie gegen Jonas Keller ist analysiert.'),
      findsOneWidget,
    );
    expect(find.text('Öffnen'), findsOneWidget);
  });
}
