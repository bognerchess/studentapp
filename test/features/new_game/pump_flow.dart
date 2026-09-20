// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/connectivity/connectivity.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/core/storage/preferences.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:bogner_chess/features/entry/data/screen_wakelock.dart';
import 'package:bogner_chess/features/submit_queue/submit_queue_overrides.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fixture_link.dart';
import '../../helpers/pump_app.dart';
import '../entry/fakes.dart';
import '../entry/pump_entry.dart' show FakePreferences;
import '../submit_queue/fakes.dart';

/// The account of these tests. Its name is what PGN headers are matched
/// against.
const kFlowUser = SignedIn(kFakeAuthSub, name: 'Fake User');

class FlowHarness {
  FlowHarness(this.api, this.db, this.connectivity);

  final FixtureLink api;
  final AppDatabase db;
  final FakeConnectivity connectivity;

  Future<List<Draft>> drafts() => db.draftsDao.getAll(kFakeAuthSub);

  Map<String, dynamic> importInput([int index = 0]) =>
      api.requestsOf('ImportMobileGame')[index].variables['input']
          as Map<String, dynamic>;
}

/// The whole app as `main.dart` runs it: the real router, the drift-backed
/// draft store, the real submit queue; below them fixtures instead of the
/// network, an in-memory database and a connectivity switch.
Future<FlowHarness> pumpFlow(
  WidgetTester tester, {
  FixtureLink? api,
  bool online = true,
  AuthState auth = kFlowUser,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Size screen = kIphone17Pro,
}) async {
  final harness = FlowHarness(
    api ?? FixtureLink(),
    openWidgetTestDatabase(),
    FakeConnectivity(online: online),
  );
  addTearDown(harness.db.close);
  await pumpApp(
    tester,
    auth: auth,
    locale: locale,
    brightness: brightness,
    textScale: textScale,
    screen: screen,
    overrides: [
      ...harness.api.overrides,
      ...submitQueueOverrides,
      appDatabaseProvider.overrideWithValue(harness.db),
      connectivityProvider.overrideWithValue(harness.connectivity),
      screenWakelockProvider.overrideWithValue(FakeWakelock()),
      preferencesProvider.overrideWithValue(FakePreferences()),
    ],
  );
  return harness;
}
