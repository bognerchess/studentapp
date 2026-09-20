// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:ui' show PlatformDispatcher;

import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/api/account_api.dart';
import 'package:bogner_chess/core/api/analysis_api.dart';
import 'package:bogner_chess/core/api/api_client.dart';
import 'package:bogner_chess/core/api/config_api.dart';
import 'package:bogner_chess/core/api/devices_api.dart';
import 'package:bogner_chess/core/api/events_api.dart';
import 'package:bogner_chess/core/api/games_api.dart';
import 'package:bogner_chess/core/api/legal_api.dart';
import 'package:bogner_chess/core/api/usage_api.dart';
import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/core/auth/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gql_link/gql_link.dart';

/// The language for server-side texts, read for every request: the system
/// language as a BCP 47 tag ("de-CH"). Tests override it.
final apiLanguageTagProvider = Provider<String Function()>(
  (ref) =>
      () => PlatformDispatcher.instance.locale.toLanguageTag(),
);

/// The whole link chain, down to HTTP. Widget tests override this one
/// provider with a `FixtureLink` (test/helpers/fixture_link.dart); then no
/// token is asked for and nothing touches the network.
final apiLinkProvider = Provider<Link>((ref) {
  final link = buildApiLink(
    env: ref.watch(envProvider),
    auth: ref.watch(authRepositoryProvider),
    languageTag: ref.watch(apiLanguageTagProvider),
    // Read per request: the version is known once the platform has answered.
    userAgent: () => switch (ref.read(appInfoProvider).value) {
      final info? => 'BognerChess-iOS/${info.version}+${info.buildNumber}',
      null => 'BognerChess-iOS',
    },
  );
  ref.onDispose(link.dispose);
  return link;
});

final apiExecutorProvider = Provider<ApiExecutor>(
  (ref) => ApiExecutor(createGraphQLClient(ref.watch(apiLinkProvider))),
);

// The repositories: the only API surface the features use.

final gamesApiProvider = Provider<GamesApi>(
  (ref) => GamesApi(ref.watch(apiExecutorProvider)),
);

final analysisApiProvider = Provider<AnalysisApi>(
  (ref) => AnalysisApi(ref.watch(apiExecutorProvider)),
);

final usageApiProvider = Provider<UsageApi>(
  (ref) => UsageApi(ref.watch(apiExecutorProvider)),
);

final devicesApiProvider = Provider<DevicesApi>(
  (ref) => DevicesApi(ref.watch(apiExecutorProvider)),
);

final eventsApiProvider = Provider<EventsApi>(
  (ref) => EventsApi(ref.watch(apiExecutorProvider)),
);

final legalApiProvider = Provider<LegalApi>(
  (ref) => LegalApi(ref.watch(apiExecutorProvider)),
);

final accountApiProvider = Provider<AccountApi>(
  (ref) => AccountApi(ref.watch(apiExecutorProvider)),
);

final configApiProvider = Provider<ConfigApi>(
  (ref) => ConfigApi(ref.watch(apiExecutorProvider)),
);
