// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

// Development entry point: starts the real app on the review screen of the
// bundled demo analysis and puts it into a given state, for screenshots on a
// simulator that nothing can tap. Never part of a release; `lib/main.dart`
// does not import it.
//
//   flutter build ios --simulator --debug \
//     --dart-define-from-file=config/fake.json \
//     -t lib/features/review/dev/review_demo.dart
//   xcrun simctl launch <udid> com.bognerchess.mobile \
//     -AppleLanguages "(de)" -review_demo_ply 16 -review_demo_tab summary
//
// Launch arguments of the form `-key value` end up in NSUserDefaults, which
// is where shared_preferences reads from: one build serves every state.
//
// review_demo_ply    main-line ply to show (default 0)
// review_demo_tab    coach (default) | moves | summary
// review_demo_line   id of a variation of that ply to open in the line
//                    viewer, for example v16-refutation
// review_demo_index  how many moves of that line are played (default 1)
// review_demo_rate   up | down: rate the comment on that ply
// review_demo_state  ok (default) | newer | invalid | error
// review_demo_coach  en | de: language of the coach texts (default: the
//                    language of the device)

import 'dart:async';
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:bogner_chess/app.dart';
import 'package:bogner_chess/features/review/data/fixture_review_repository.dart';
import 'package:bogner_chess/features/review/data/review_providers.dart';
import 'package:bogner_chess/features/review/dev/demo_analysis.dart';
import 'package:bogner_chess/features/review/domain/review_controller.dart';
import 'package:bogner_chess/features/review/domain/review_repository.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _gameId = 'demo';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final arguments = SharedPreferencesAsync();
  Future<String?> argument(String name) async {
    // `-review_demo_ply 16` arrives as an integer, not as a string.
    try {
      return await arguments.getString(name);
    } on Object {
      return (await arguments.getInt(name))?.toString();
    }
  }

  final ply = int.tryParse(await argument('review_demo_ply') ?? '') ?? 0;
  final tab = await argument('review_demo_tab');
  final line = await argument('review_demo_line');
  final index = int.tryParse(await argument('review_demo_index') ?? '') ?? 1;
  final rate = await argument('review_demo_rate');
  final state = await argument('review_demo_state') ?? 'ok';
  final coach =
      await argument('review_demo_coach') ??
      PlatformDispatcher.instance.locale.languageCode;

  final container = ProviderContainer(
    overrides: [
      reviewRepositoryProvider.overrideWithValue(_repository(state, coach)),
      feedbackSinkProvider.overrideWithValue(InMemoryFeedbackSink()),
    ],
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BognerChessApp(),
    ),
  );

  container.read(routerProvider).go(AppRoutes.gameReview(_gameId));
  await Future<void>.delayed(const Duration(seconds: 1));
  if (state != 'ok' && state != 'newer') return;

  final controller = container.read(reviewControllerProvider(_gameId).notifier);
  controller.goTo(ply);
  if (tab != null) {
    controller.setTab(ReviewTab.values.asNameMap()[tab] ?? ReviewTab.coach);
  }
  if (rate != null) {
    final comment = controller.document?.nodeAt(ply)?.commentIds.firstOrNull;
    final rating = CommentRating.values.asNameMap()[rate];
    if (comment != null && rating != null) {
      await controller.rate(comment, rating);
    }
  }
  if (line != null) {
    controller
      ..enterLine(line)
      ..lineGoTo(index);
  }
}

ReviewRepository _repository(String state, String coach) => switch (state) {
  'newer' => FixtureReviewRepository(
    payload: jsonEncode(
      demoAnalysisJson()
        ..['schema_version'] = 2
        ..['schema_minor'] = 0,
    ),
  ),
  'invalid' => FixtureReviewRepository(payload: '{"schema": "something"}'),
  'error' => _FailingRepository(),
  _ => FixtureReviewRepository(languageCode: coach),
};

class _FailingRepository implements ReviewRepository {
  @override
  Future<ReviewData> load(String gameId) async =>
      throw StateError('demo: the analysis could not be loaded');
}
