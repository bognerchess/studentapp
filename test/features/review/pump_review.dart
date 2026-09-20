// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bogner_chess/app.dart';
import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/features/review/data/review_providers.dart';
import 'package:bogner_chess/features/review/domain/review_controller.dart';
import 'package:bogner_chess/features/review/domain/review_repository.dart';
import 'package:bogner_chess/features/review/ui/review_screen.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

/// The game id every review test uses.
const String kReviewGameId = 'game-1';

/// Fixture paths below `test/fixtures/analysis/`.
const String kFortyMoveGame = 'v1/forty-move-game.json';
const String kShortGame = 'v1/short-game.json';
const String kFallbackCase = 'v1/fallback-case.json';
const String kWithUnknowns = 'forward-compat/v1-with-unknowns.json';
const String kNewerMajor = 'forward-compat/v2-major.json';

/// A vendored analysis fixture as decoded JSON.
Map<String, dynamic> loadAnalysisJson(String fixture) =>
    jsonDecode(File('test/fixtures/analysis/$fixture').readAsStringSync())
        as Map<String, dynamic>;

/// A vendored fixture, parsed. [patch] may change the JSON first.
AnalysisParseResult parseFixture(
  String fixture, {
  void Function(Map<String, dynamic> json)? patch,
}) {
  final json = loadAnalysisJson(fixture);
  patch?.call(json);
  return AnalysisParser.parse(json);
}

/// A coach text of exactly the contract's maximum length (320), in German,
/// with long words: the worst case for the comment card.
final String kLongGermanComment = () {
  const sentence =
      'Mit dem Bauernvorstoss öffnest du die Königsstellung, während deine '
      'Schwerfiguren noch unentwickelt auf der Grundreihe stehen. ';
  final text = sentence * 4;
  return '${text.substring(0, 319)}.';
}();

/// Makes every comment and lesson as long as the contract allows.
void stretchTexts(Map<String, dynamic> json) {
  for (final comment
      in (json['comments'] as List).cast<Map<String, dynamic>>()) {
    comment['title'] = 'Entwicklungsvorsprung konsequent nutzen!'; // 40
    comment['text'] = kLongGermanComment;
    for (final line
        in (comment['lines'] as List).cast<Map<String, dynamic>>()) {
      line['label'] = 'Widerlegungsvariante'; // 20 of 24
    }
  }
  final summary = json['summary'] as Map<String, dynamic>;
  for (final lesson
      in (summary['lessons'] as List).cast<Map<String, dynamic>>()) {
    lesson['title'] = 'Entwicklungsvorsprung konsequent nutzen!';
    lesson['text'] = kLongGermanComment.substring(0, 240);
  }
}

/// Serves one [ReviewData], or fails while [error] is set.
class FakeReviewRepository implements ReviewRepository {
  FakeReviewRepository(this.data);

  ReviewData data;
  Object? error;
  final List<String> loads = [];

  @override
  Future<ReviewData> load(String gameId) async {
    loads.add(gameId);
    if (error case final error?) throw error; // ignore: only_throw_errors
    return data;
  }
}

/// Records ratings. With [gate] set, a call waits for it; with [failWith]
/// set, it throws.
class RecordingFeedbackSink implements FeedbackSink {
  final List<(String, CommentRating?)> calls = [];
  Object? failWith;
  Completer<void>? gate;

  @override
  Future<void> rate(String commentId, CommentRating? rating) async {
    calls.add((commentId, rating));
    await gate?.future;
    if (failWith case final error?) throw error; // ignore: only_throw_errors
  }
}

class ReviewHarness {
  ReviewHarness(this.repository, this.sink);

  final FakeReviewRepository repository;
  final RecordingFeedbackSink sink;
}

/// Pumps the whole app and opens the review screen through the router.
Future<ReviewHarness> pumpReview(
  WidgetTester tester, {
  String fixture = kFortyMoveGame,
  void Function(Map<String, dynamic> json)? patch,
  AnalysisParseResult? result,
  GameHeaderInfo header = const GameHeaderInfo(
    white: 'Anna Beispiel',
    black: 'Bernd Muster',
    result: '1-0',
  ),
  Map<String, CommentRating?> myFeedback = const {},
  Object? loadError,
  Env? env,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Size screen = kIphone17Pro,
}) async {
  final harness = ReviewHarness(
    FakeReviewRepository(
      ReviewData(
        result: result ?? parseFixture(fixture, patch: patch),
        header: header,
        myFeedback: myFeedback,
      ),
    )..error = loadError,
    RecordingFeedbackSink(),
  );

  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = screen * 3;
  tester.platformDispatcher.localesTestValue = [locale];
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        envProvider.overrideWithValue(env ?? testEnv()),
        appInfoProvider.overrideWith(
          (ref) async => const AppInfo(version: '1.2.3', buildNumber: '45'),
        ),
        reviewRepositoryProvider.overrideWithValue(harness.repository),
        feedbackSinkProvider.overrideWithValue(harness.sink),
      ],
      child: const BognerChessApp(),
    ),
  );
  await tester.pumpAndSettle();

  routerOf(tester).go(AppRoutes.gameReview(kReviewGameId));
  await tester.pumpAndSettle();
  expect(find.byType(ReviewScreen), findsOneWidget);
  return harness;
}

extension ReviewTester on WidgetTester {
  Finder reviewControl(String identifier) =>
      find.bySemanticsIdentifier(identifier);

  /// Taps a control by its semantics identifier, scrolling it into view
  /// first when it sits in one of the panels.
  Future<void> tapReview(String identifier) async {
    final finder = reviewControl(identifier);
    expect(finder, findsOneWidget, reason: identifier);
    await ensureVisible(finder);
    await pumpAndSettle();
    await tap(finder);
    await pumpAndSettle();
  }

  ReviewState get reviewState =>
      containerOf(this).read(reviewControllerProvider(kReviewGameId));

  ReviewController get reviewController =>
      containerOf(this).read(reviewControllerProvider(kReviewGameId).notifier);
}
