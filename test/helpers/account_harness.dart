// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/analytics/analytics.dart';
import 'package:bogner_chess/core/auth/auth_providers.dart';
import 'package:bogner_chess/core/auth/fake_auth_repository.dart';
import 'package:bogner_chess/core/links/link_launcher.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../core/storage/test_database.dart';
import 'fixture_link.dart';

/// What [Analytics.track] was called with.
class RecordingAnalytics implements Analytics {
  final List<({String name, Map<String, Object?> props})> events = [];

  List<String> get names => [for (final event in events) event.name];

  @override
  void track(String name, [Map<String, Object?> props = const {}]) =>
      events.add((name: name, props: props));
}

/// Everything the settings, consent, legal and account screens touch, as
/// fakes: the API from fixtures, an in-memory database, in-memory
/// preferences, fake auth (with the real wipe-on-sign-out hook), recorded
/// analytics and recorded outgoing links.
///
///     final h = AccountHarness();            // in the test body
///     await pumpApp(tester, overrides: h.overrides);
class AccountHarness {
  AccountHarness({
    Map<String, String> scenarios = const {},
    bool signedIn = true,
  }) : api = FixtureLink(scenarios),
       database = openTestDatabase(FakeClock()) {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    auth = FakeAuthRepository(
      signedIn: signedIn,
      onSignedOut: (sub) => database.wipeOwner(sub, keepDrafts: true),
    );
    addTearDown(() async {
      await auth.dispose();
      await database.close();
    });
  }

  final FixtureLink api;
  final AppDatabase database;
  late final FakeAuthRepository auth;
  final RecordingAnalytics analytics = RecordingAnalytics();

  /// Links the app wanted to open outside.
  final List<Uri> launched = [];

  List<Override> get overrides => [
    ...api.overrides,
    appDatabaseProvider.overrideWithValue(database),
    authRepositoryProvider.overrideWithValue(auth),
    analyticsProvider.overrideWithValue(analytics),
    linkLauncherProvider.overrideWithValue((uri) async {
      launched.add(uri);
      return true;
    }),
  ];

  /// The legal texts in the language that was asked for, as the mock server
  /// serves them (`<key>_<language>.json`, English when there is no such
  /// file).
  void serveLegalDocumentsByLanguage() {
    api.respond('LegalDocument', (variables) {
      final key = (variables['key'] as String).toLowerCase();
      final language = variables['language'] as String? ?? 'en';
      final wanted = '${key}_$language';
      return api.store.response(
        'LegalDocument',
        api.store.scenarios('LegalDocument').contains(wanted)
            ? wanted
            : '${key}_en',
      );
    });
  }
}
