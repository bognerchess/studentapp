// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

import 'package:bogner_chess/core/api/account_api.dart';
import 'package:bogner_chess/core/api/analysis_api.dart';
import 'package:bogner_chess/core/api/api_client.dart';
import 'package:bogner_chess/core/api/config_api.dart';
import 'package:bogner_chess/core/api/devices_api.dart';
import 'package:bogner_chess/core/api/events_api.dart';
import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/api/generated/operations/account.graphql.dart';
import 'package:bogner_chess/core/api/generated/operations/analysis.graphql.dart';
import 'package:bogner_chess/core/api/generated/operations/config.graphql.dart';
import 'package:bogner_chess/core/api/generated/operations/devices.graphql.dart';
import 'package:bogner_chess/core/api/generated/operations/games.graphql.dart';
import 'package:bogner_chess/core/api/generated/operations/legal.graphql.dart';
import 'package:bogner_chess/core/api/legal_api.dart';
import 'package:bogner_chess/core/api/usage_api.dart';
import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixture_link.dart';
import 'api_test_support.dart';

/// One operation of `graphql/operations/`: how the generated code reads its
/// data, and how the repository is called for it.
typedef _Operation = ({
  Object Function(Map<String, dynamic> data) parse,
  Future<Object?> Function(ApiExecutor executor) call,
});

final Map<String, _Operation> _operations = {
  'MobileConfig': (
    parse: Query$MobileConfig.fromJson,
    call: (e) => ConfigApi(e).mobileConfig(),
  ),
  'MyMobileGames': (
    parse: Query$MyMobileGames.fromJson,
    call: (e) => GamesApi(e).list(),
  ),
  'GameById': (
    parse: Query$GameById.fromJson,
    call: (e) => GamesApi(e).get('game-1'),
  ),
  'ImportMobileGame': (
    parse: Mutation$ImportMobileGame.fromJson,
    call: (e) => GamesApi(e).import(
      metadata: const GameMetadata(playerColor: PlayerColor.white),
      movetext: '1. e4 e5',
      clientGameId: 'client-1',
      source: ImportSource.board,
    ),
  ),
  'DeleteChessGame': (
    parse: Mutation$DeleteChessGame.fromJson,
    call: (e) => GamesApi(e).delete('game-1'),
  ),
  'RequestGameAnalysis': (
    parse: Mutation$RequestGameAnalysis.fromJson,
    call: (e) => AnalysisApi(e).request(gameId: 'game-1'),
  ),
  'AnalysisJob': (
    parse: Query$AnalysisJob.fromJson,
    call: (e) => AnalysisApi(e).job('job-1'),
  ),
  'MyActiveAnalysisJobs': (
    parse: Query$MyActiveAnalysisJobs.fromJson,
    call: (e) => AnalysisApi(e).activeJobs(),
  ),
  'GameAnalysis': (
    parse: Query$GameAnalysis.fromJson,
    call: (e) => AnalysisApi(e).analysis('game-1'),
  ),
  'SubmitCoachCommentFeedback': (
    parse: Mutation$SubmitCoachCommentFeedback.fromJson,
    call: (e) =>
        AnalysisApi(e)
            .submitFeedback(commentId: 'c-1', rating: CommentRating.up),
  ),
  'MyAnalysisUsage': (
    parse: Query$MyAnalysisUsage.fromJson,
    call: (e) => UsageApi(e).usage(),
  ),
  'RegisterMobileDevice': (
    parse: Mutation$RegisterMobileDevice.fromJson,
    call: (e) =>
        DevicesApi(e)
            .register(deviceId: 'd-1', environment: ApnsEnvironment.sandbox),
  ),
  'UnregisterMobileDevice': (
    parse: Mutation$UnregisterMobileDevice.fromJson,
    call: (e) => DevicesApi(e).unregister('d-1'),
  ),
  'TrackMobileEvents': (
    parse: Mutation$TrackMobileEvents.fromJson,
    call: (e) => EventsApi(e).track(
      deviceId: 'd-1',
      sessionId: 's-1',
      events: [
        AnalyticsEvent(name: 'app_opened', occurredAt: DateTime.utc(2026)),
      ],
    ),
  ),
  'LegalDocument': (
    parse: Query$LegalDocument.fromJson,
    call: (e) => LegalApi(e).document(LegalDocumentKey.aiConsent),
  ),
  'MyAiConsent': (
    parse: Query$MyAiConsent.fromJson,
    call: (e) => LegalApi(e).aiConsent(),
  ),
  'MyConsent': (
    parse: Query$MyConsent.fromJson,
    call: (e) => LegalApi(e).consent(LegalDocumentKey.analyticsConsent),
  ),
  'RecordAiConsent': (
    parse: Mutation$RecordAiConsent.fromJson,
    call: (e) => LegalApi(e).recordAiConsent(version: 1),
  ),
  'RecordConsent': (
    parse: Mutation$RecordConsent.fromJson,
    call: (e) => LegalApi(e).recordConsent(
      key: LegalDocumentKey.analyticsConsent,
      version: 1,
      accepted: true,
    ),
  ),
  'DeleteMyAccount': (
    parse: Mutation$DeleteMyAccount.fromJson,
    call: (e) => AccountApi(e).deleteMyAccount(),
  ),
};

/// The members of each mutation's error union in `graphql/schema.graphql`.
/// Every one of them needs a fixture.
const Map<String, Set<String>> _errorUnions = {
  'ImportMobileGame': {
    'PgnInvalidError',
    'RateLimitedError',
    'InputValidationError',
    'BusinessError',
    'TechnicalError',
  },
  'DeleteChessGame': {
    'TechnicalError',
    'BusinessError',
    'InputValidationError',
  },
  'RequestGameAnalysis': {
    'AnalysisLimitReachedError',
    'AnalysisQueueFullError',
    'RateLimitedError',
    'EmailNotVerifiedError',
    'AiConsentRequiredError',
    'BusinessError',
    'InputValidationError',
    'TechnicalError',
  },
  'SubmitCoachCommentFeedback': _generic,
  'RegisterMobileDevice': {'RateLimitedError', ..._generic},
  'UnregisterMobileDevice': _generic,
  'TrackMobileEvents': {'RateLimitedError', ..._generic},
  'RecordAiConsent': _generic,
  'RecordConsent': _generic,
  'DeleteMyAccount': {'AccountDeletionBlockedError', ..._generic},
};

const Set<String> _generic = {
  'BusinessError',
  'InputValidationError',
  'TechnicalError',
};

void main() {
  final store = FixtureStore();

  test('there are fixtures for exactly the operations of the app', () {
    expect(store.operations(), _operations.keys.toList()..sort());
    for (final operation in _operations.keys) {
      // The happy path, which a FixtureLink serves unless told otherwise.
      expect(
        store.scenarios(operation),
        contains('default'),
        reason: operation,
      );
    }
  });

  test('every member of every error union has a fixture, and one fixture '
      'has a member this build does not know', () {
    for (final MapEntry(key: operation, value: members)
        in _errorUnions.entries) {
      final seen = <String>{};
      for (final scenario in store.scenarios(operation)) {
        final payload = store.data(operation, scenario).values.single as Map;
        for (final error in payload['errors'] as List? ?? const <Object?>[]) {
          seen.add((error as Map)['__typename'] as String);
        }
      }
      expect(seen, containsAll(members), reason: operation);
      expect(seen.difference(members), {
        'SomethingNewError',
      }, reason: operation);
    }
  });

  for (final MapEntry(key: operation, value: entry) in _operations.entries) {
    group(operation, () {
      for (final scenario in store.scenarios(operation)) {
        test('$scenario: generated fromJson, toJson round trip', () {
          final data = store.data(operation, scenario);
          final parsed = entry.parse(data);
          // The generated toJson writes what fromJson read: nothing the
          // operation selects is missing from the fixture.
          // (Compared as JSON: the analysis document is a map, and maps are
          // only equal to themselves.)
          final json = jsonEncode(parsed);
          final again = entry.parse(jsonDecode(json) as Map<String, dynamic>);
          expect(jsonEncode(again), json);
        });

        test('$scenario: through the repository', () async {
          final link = FixtureLink({operation: scenario}, store);
          try {
            await entry.call(linkExecutor(link));
          } on ApiRejected {
            // A mutation without typed outcomes reports its errors this way.
          }
          expect(link.requestsOf(operation), hasLength(1));
        });
      }
    });
  }
}
