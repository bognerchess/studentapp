// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';
import 'dart:io';

import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/analysis/analysis_parser.dart';
import 'package:bogner_chess/features/review/data/fixture_review_repository.dart';
import 'package:bogner_chess/features/review/data/outbox_feedback_sink.dart';
import 'package:bogner_chess/features/review/data/review_providers.dart';
import 'package:bogner_chess/features/review/dev/demo_analysis.dart';
import 'package:bogner_chess/features/review/domain/review_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

ProviderContainer _container(AuthMode mode) {
  final container = ProviderContainer(
    overrides: [
      envProvider.overrideWithValue(testEnv(authMode: mode)),
      ...backendOverrides(),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('defaults', () {
    for (final mode in AuthMode.values) {
      test('${mode.name} configuration: the API repository and the outbox', () {
        final container = _container(mode);
        expect(
          container.read(reviewRepositoryProvider),
          isNot(isA<FixtureReviewRepository>()),
        );
        expect(
          container.read(outboxFeedbackSinkProvider),
          isA<OutboxFeedbackSink>(),
        );
        expect(container.read(feedbackSinkProvider), isA<FeedbackSink>());
      });
    }

    test('the demo repository still serves the dev entry point', () async {
      final data = await FixtureReviewRepository().load('anything');
      expect(data.result, isA<AnalysisSupported>());
      expect(data.header.white, isNotEmpty);

      final sink = InMemoryFeedbackSink();
      await sink.rate('c', CommentRating.down);
      expect(sink.ratings, {'c': CommentRating.down});
      await sink.rate('c', null);
      expect(sink.ratings, isEmpty);
    });
  });

  group('demo document', () {
    test('is the contract fixture short-game.json, unchanged', () {
      final fixture = jsonDecode(
        File('test/fixtures/analysis/v1/short-game.json').readAsStringSync(),
      );
      expect(demoAnalysisJson(), fixture);
    });

    for (final language in ['en', 'de']) {
      test('parses without warnings ($language)', () {
        final result = AnalysisParser.parseString(
          demoAnalysisPayload(languageCode: language),
        );
        expect(result, isA<AnalysisSupported>());
        final supported = result as AnalysisSupported;
        expect(supported.warnings, isEmpty);
        expect(supported.document.comments, hasLength(3));
        expect(supported.document.lessons, hasLength(3));
      });
    }

    test('German texts keep the mentioned moves and the length limits', () {
      final document = (AnalysisParser.parse(
        demoAnalysisJson(languageCode: 'de'),
      ) as AnalysisSupported).document;
      for (final comment in document.comments) {
        expect(comment.title.length, lessThanOrEqualTo(40));
        expect(comment.text.length, lessThanOrEqualTo(320));
        for (final move in comment.movesMentioned) {
          expect(comment.text, contains(move), reason: comment.title);
        }
        for (final line in comment.lines) {
          expect([
            'Besser',
            'Bestrafung',
            'Auch möglich',
          ], contains(line.label));
        }
      }
      for (final lesson in document.lessons) {
        expect(lesson.title.length, lessThanOrEqualTo(40));
        expect(lesson.text.length, lessThanOrEqualTo(240));
      }
      expect(document.comments.first.title, 'Zentrum zu früh geöffnet');
    });

    test('another payload shows the other states', () async {
      final invalid = await FixtureReviewRepository(payload: '{}').load('g');
      expect(invalid.result, isA<AnalysisInvalid>());
    });
  });
}
