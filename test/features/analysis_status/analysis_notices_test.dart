// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:bogner_chess/features/analysis_status/domain/workflow_tracker_providers.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fixture_link.dart';
import '../../helpers/pump_app.dart';

/// The state of every stage of every watched game, which the scripted
/// `GameAnalysisWorkflow` answers from. A test moves one stage on and polls
/// again; the tracker turns the change into the event this widget shows.
final Map<String, Map<AnalysisStage, String>> _states = {};

void _script(String gameId, Map<AnalysisStage, String> states) =>
    _states[gameId] = {...states};

Map<String, dynamic> _workflowOf(String gameId) {
  final states = _states[gameId] ?? const {};
  final ready = [
    for (final stage in AnalysisStage.pipeline) states[stage] == 'READY',
  ];
  final values = [
    for (final stage in AnalysisStage.pipeline) states[stage] ?? 'NOT_RUN',
  ];
  return {
    'chessGameId': gameId,
    'state': _oneState(values),
    'progress': null,
    'targetStage': states.isEmpty ? null : 'COACHING',
    'targetReason': null,
    'stages': [
      for (final (index, stage) in AnalysisStage.pipeline.indexed)
        {
          'stage': stage.wire,
          'state': states[stage] ?? 'NOT_RUN',
          // Nothing in these tests is runnable: the point is what the tracker
          // *says*, and a chain that fires mutations would need a server.
          'runnable': false,
          'blockedBy': index == 0 || ready[index - 1]
              ? null
              : AnalysisStage.pipeline[index - 1].wire,
          'usesModel': stage.usesModel,
          'run': states[stage] == null
              ? null
              : {
                  'id': 'run-${stage.wire}-$gameId',
                  'status': switch (states[stage]) {
                    'QUEUED' => 'QUEUED',
                    'RUNNING' => 'RUNNING',
                    'FAILED' => 'FAILED',
                    _ => 'DONE',
                  },
                  'hasArtifact': states[stage] == 'READY',
                  'progressStage': null,
                  'progressDone': null,
                  'progressTotal': null,
                  'persona': null,
                  'language': stage.usesModel ? 'en' : null,
                  'requestedAt': '2026-09-19T10:00:00.000Z',
                  'startedAt': null,
                  'finishedAt': null,
                  'failureCode': states[stage] == 'FAILED' ? 'timeout' : null,
                  'failureMessage': null,
                },
        },
    ],
    'nextRunnableStage': null,
    'isComplete': ready.every((value) => value),
  };
}

/// The one state, derived the way the backend derives it.
String _oneState(List<String> values) {
  if (values.any((s) => s == 'QUEUED' || s == 'RUNNING')) return 'ANALYSING';
  if (values.contains('STALE')) return 'STALE';
  if (values.contains('FAILED')) return 'FAILED';
  return values.contains('READY') ? 'READY' : 'IDLE';
}

void main() {
  late AppDatabase db;
  late FixtureLink api;

  setUp(() {
    db = openWidgetTestDatabase();
    _states.clear();
    api = FixtureLink()
      ..respond('GameAnalysisWorkflow', (variables) {
        final gameId = variables['gameId'] as String;
        return {
          'data': {'gameAnalysisWorkflow': _workflowOf(gameId)},
        };
      })
      // The artifacts are not what this widget is about, and one of them is a
      // hundred kilobytes.
      ..respond(
        'EngineStageRun',
        (_) => {
          'data': {'engineStageRun': null},
        },
      );
  });
  tearDown(() => db.close());

  List<Override> overrides() => [
    appDatabaseProvider.overrideWithValue(db),
    ...api.overrides,
  ];

  /// Watches [gameId] and takes the first poll, which the tracker compares
  /// every later one against.
  Future<void> watch(WidgetTester tester, String gameId) async {
    await containerOf(tester).read(workflowTrackerProvider).track(gameId);
    await tester.pumpAndSettle();
  }

  /// Moves [gameId] on and polls again.
  Future<void> report(
    WidgetTester tester,
    String gameId,
    Map<AnalysisStage, String> states,
  ) async {
    _script(gameId, states);
    await containerOf(tester).read(workflowTrackerProvider).refreshNow();
    await tester.pumpAndSettle();
  }

  testWidgets('a finished analysis is announced with the opponent', (
    tester,
  ) async {
    _script('game-1', {
      AnalysisStage.baseEvaluation: 'READY',
      AnalysisStage.baseClassification: 'READY',
      AnalysisStage.deepEvaluation: 'READY',
      AnalysisStage.coaching: 'RUNNING',
    });
    await pumpApp(tester, polling: true, overrides: overrides());
    await watch(tester, 'game-1');
    await report(tester, 'game-1', {
      AnalysisStage.baseEvaluation: 'READY',
      AnalysisStage.baseClassification: 'READY',
      AnalysisStage.deepEvaluation: 'READY',
      AnalysisStage.coaching: 'READY',
    });

    expect(
      find.text('Your coach has written about your game against Jonas Keller.'),
      findsOneWidget,
    );
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('a readable analysis is announced before the coach has run', (
    tester,
  ) async {
    _script('game-1', {
      AnalysisStage.baseEvaluation: 'READY',
      AnalysisStage.baseClassification: 'READY',
      AnalysisStage.deepEvaluation: 'RUNNING',
    });
    await pumpApp(tester, polling: true, overrides: overrides());
    await watch(tester, 'game-1');
    await report(tester, 'game-1', {
      AnalysisStage.baseEvaluation: 'READY',
      AnalysisStage.baseClassification: 'READY',
      AnalysisStage.deepEvaluation: 'READY',
    });

    // Nothing about engines or steps: there is something to read, and that
    // is the whole news.
    expect(
      find.text('Your game against Jonas Keller has been analysed.'),
      findsOneWidget,
    );
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('the steps on the way say nothing', (tester) async {
    _script('game-1', {AnalysisStage.baseEvaluation: 'RUNNING'});
    await pumpApp(tester, polling: true, overrides: overrides());
    await watch(tester, 'game-1');
    await report(tester, 'game-1', {
      AnalysisStage.baseEvaluation: 'READY',
      AnalysisStage.baseClassification: 'RUNNING',
    });

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('the notice goes away by itself', (tester) async {
    _script('game-1', {
      AnalysisStage.baseEvaluation: 'READY',
      AnalysisStage.baseClassification: 'READY',
      AnalysisStage.deepEvaluation: 'RUNNING',
    });
    await pumpApp(tester, polling: true, overrides: overrides());
    await watch(tester, 'game-1');
    await report(tester, 'game-1', {
      AnalysisStage.baseEvaluation: 'READY',
      AnalysisStage.baseClassification: 'READY',
      AnalysisStage.deepEvaluation: 'READY',
    });
    expect(find.byType(SnackBar), findsOneWidget);

    // Long enough for the eight seconds the notice asks for, and then some:
    // a notice that stays for ever sits over the tab bar and the last row.
    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failed analysis is announced with a way to it', (
    tester,
  ) async {
    _script('game-1', {
      AnalysisStage.baseEvaluation: 'READY',
      AnalysisStage.baseClassification: 'RUNNING',
    });
    await pumpApp(tester, polling: true, overrides: overrides());
    await watch(tester, 'game-1');
    await report(tester, 'game-1', {
      AnalysisStage.baseEvaluation: 'READY',
      AnalysisStage.baseClassification: 'FAILED',
    });

    expect(
      find.text("An analysis failed. It doesn't count towards your limit."),
      findsOneWidget,
    );
    expect(find.text('View'), findsOneWidget);
  });

  testWidgets('moves that changed stop the analysis and say so', (
    tester,
  ) async {
    _script('game-1', {
      AnalysisStage.baseEvaluation: 'READY',
      AnalysisStage.baseClassification: 'RUNNING',
    });
    await pumpApp(tester, polling: true, overrides: overrides());
    await watch(tester, 'game-1');
    await report(tester, 'game-1', {
      AnalysisStage.baseEvaluation: 'STALE',
      AnalysisStage.baseClassification: 'STALE',
    });

    expect(
      find.text('Your moves changed, so the analysis stopped.'),
      findsOneWidget,
    );
    expect(find.text('View'), findsOneWidget);
  });

  testWidgets('nothing is said on the screen of that very game', (
    tester,
  ) async {
    // The engine is done on the game we open and the coach is waiting, so
    // nothing on that screen is animating: `pumpAndSettle` would never return
    // on a running stage, because its progress bar is indeterminate.
    _script('game-1', {
      AnalysisStage.baseEvaluation: 'READY',
      AnalysisStage.baseClassification: 'READY',
      AnalysisStage.deepEvaluation: 'READY',
    });
    _script('game-3', {
      AnalysisStage.baseEvaluation: 'READY',
      AnalysisStage.baseClassification: 'READY',
      AnalysisStage.deepEvaluation: 'RUNNING',
    });
    await pumpApp(tester, polling: true, overrides: overrides());
    await watch(tester, 'game-1');
    await watch(tester, 'game-3');
    await tester.tap(find.text('Fake User – Jonas Keller'));
    await tester.pumpAndSettle();
    expect(
      routerOf(tester).routerDelegate.currentConfiguration.last.matchedLocation,
      AppRoutes.game('game-1'),
    );

    // That screen turns into the ready card by itself; a snack bar over it
    // would only cover the button it just grew.
    await report(tester, 'game-1', {
      AnalysisStage.baseEvaluation: 'READY',
      AnalysisStage.baseClassification: 'READY',
      AnalysisStage.deepEvaluation: 'READY',
      AnalysisStage.coaching: 'READY',
    });
    expect(find.byType(SnackBar), findsNothing);

    // Another game's analysis is still worth saying.
    await report(tester, 'game-3', {
      AnalysisStage.baseEvaluation: 'READY',
      AnalysisStage.baseClassification: 'READY',
      AnalysisStage.deepEvaluation: 'READY',
    });
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('German', (tester) async {
    _script('game-1', {
      AnalysisStage.baseEvaluation: 'READY',
      AnalysisStage.baseClassification: 'READY',
      AnalysisStage.deepEvaluation: 'READY',
      AnalysisStage.coaching: 'RUNNING',
    });
    await pumpApp(
      tester,
      locale: const Locale('de'),
      polling: true,
      overrides: overrides(),
    );
    await watch(tester, 'game-1');
    await report(tester, 'game-1', {
      AnalysisStage.baseEvaluation: 'READY',
      AnalysisStage.baseClassification: 'READY',
      AnalysisStage.deepEvaluation: 'READY',
      AnalysisStage.coaching: 'READY',
    });

    expect(
      find.text(
        'Dein Coach hat über deine Partie gegen Jonas Keller geschrieben.',
      ),
      findsOneWidget,
    );
    expect(find.text('Öffnen'), findsOneWidget);
  });
}
