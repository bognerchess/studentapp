// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/core/auth/auth_providers.dart';
import 'package:bogner_chess/core/auth/fake_auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/mock_server/mock_server.dart';
import '../../helpers/fixture_link.dart';
import 'api_test_support.dart';

void main() {
  test(
    'every repository has a provider, and a FixtureLink feeds them all',
    () async {
      final link = FixtureLink();
      final container = ProviderContainer(overrides: link.overrides);
      addTearDown(container.dispose);

      expect((await container.read(gamesApiProvider).list()).totalCount, 3);
      expect(
        await container.read(analysisApiProvider).activeJobs(),
        hasLength(2),
      );
      expect((await container.read(usageApiProvider).usage()).dailyLimit, 3);
      expect(
        (await container.read(legalApiProvider).aiConsent()).required,
        isFalse,
      );
      expect(
        (await container.read(configApiProvider).mobileConfig())
            .currentAiConsentVersion,
        1,
      );
      expect(container.read(devicesApiProvider), isNotNull);
      expect(container.read(eventsApiProvider), isNotNull);
      expect(container.read(accountApiProvider), isNotNull);
      expect(link.requests.map((r) => r.operationName), [
        'MyMobileGames',
        'MyActiveAnalysisJobs',
        'MyAnalysisUsage',
        'MyAiConsent',
        'MobileConfig',
      ]);
    },
  );

  test(
    'the app wiring: Env, fake auth and app version end up on the wire',
    () async {
      final server = await MockServer.start();
      addTearDown(server.close);
      final auth = FakeAuthRepository();
      addTearDown(auth.dispose);
      final container = ProviderContainer(
        overrides: [
          envProvider.overrideWithValue(apiTestEnv(apiUrl: server.graphqlUri)),
          authRepositoryProvider.overrideWithValue(auth),
          apiLanguageTagProvider.overrideWithValue(() => 'de-AT'),
          appInfoProvider.overrideWith(
            (ref) => const AppInfo(version: '1.2.3', buildNumber: '45'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(appInfoProvider.future);

      await container.read(gamesApiProvider).list();

      final headers = server.requests.single.headers;
      expect(headers['authorization'], 'Bearer $kFakeAccessToken');
      expect(headers['x-tenant-slug'], 'test-tenant');
      expect(headers['graphql-preflight'], '1');
      expect(headers['accept-language'], 'de-AT');
      expect(headers['user-agent'], 'BognerChess-iOS/1.2.3+45');
    },
  );

  test('the default language tag is the system language', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(apiLanguageTagProvider)(),
      matches(r'^[a-z]{2,3}(-|$)'),
    );
  });
}
