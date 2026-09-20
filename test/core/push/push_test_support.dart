// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/analytics/analytics.dart';
import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/api/models/device_models.dart';
import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/device/device_id.dart';
import 'package:bogner_chess/core/push/push_hooks.dart';
import 'package:bogner_chess/core/push/push_platform.dart';
import 'package:bogner_chess/core/push/push_service.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixture_link.dart';
import '../../helpers/pump_app.dart';
import '../storage/test_database.dart';

const kTestToken =
    '00ff10a9b8c7d6e5f40123456789abcdef0123456789abcdef0123456789abcd';

/// Stands in for `PushHandler.swift`. Like the real one, it keeps what is
/// added before anybody listens and delivers it first.
class FakePushPlatform implements PushPlatform {
  FakePushPlatform({this.status = PushPermissionStatus.notDetermined});

  // Closed by a tear-down in PushHarness.
  // ignore: close_sinks
  final StreamController<PushEvent> controller = StreamController<PushEvent>();

  PushPermissionStatus status;

  /// What the user answers to the system prompt.
  bool grantOnRequest = true;

  /// Whether APNs hands out a token after a registration.
  bool deliversToken = true;

  final List<String> calls = [];
  String? visibleGame;

  @override
  Stream<PushEvent> get events => controller.stream;

  @override
  Future<PushPermissionStatus> permissionStatus() async {
    calls.add('permissionStatus');
    return status;
  }

  @override
  Future<bool> requestPermission() async {
    calls.add('requestPermission');
    status = grantOnRequest
        ? PushPermissionStatus.authorized
        : PushPermissionStatus.denied;
    if (grantOnRequest) _registerWithApns();
    return grantOnRequest;
  }

  @override
  Future<PushPermissionStatus> registerIfAuthorized() async {
    calls.add('registerIfAuthorized');
    if (status == PushPermissionStatus.authorized) _registerWithApns();
    return status;
  }

  void _registerWithApns() {
    calls.add('apns.register');
    if (deliversToken) {
      controller.add(const PushTokenEvent(kTestToken, ApnsEnvironment.sandbox));
    }
  }

  @override
  Future<ApnsEnvironment> environment() async => ApnsEnvironment.sandbox;

  @override
  Future<void> setVisibleGame(String? gameId) async {
    calls.add('setVisibleGame($gameId)');
    visibleGame = gameId;
  }

  @override
  Future<void> openSettings() async => calls.add('openSettings');
}

class RecordingAnalytics implements Analytics {
  final List<(String, Map<String, Object?>)> events = [];

  @override
  void track(String name, [Map<String, Object?> props = const {}]) =>
      events.add((name, props));
}

class RecordingListener implements AnalysisReadyListener {
  final List<String> calls = [];

  @override
  void refreshNow({String? gameId, String? jobId}) =>
      calls.add('$gameId/$jobId');
}

/// The providers `PushService` reads, on an in-memory database, a
/// [FixtureLink] and a [FakePushPlatform].
class PushHarness {
  PushHarness({
    AuthState auth = const SignedIn(alice),
    PushPermissionStatus status = PushPermissionStatus.notDetermined,
    List<Override> overrides = const [],
  }) : platform = FakePushPlatform(status: status),
       auth = TestAuthNotifier(auth) {
    db = openTestDatabase(clock);
    container = ProviderContainer(
      overrides: [
        envProvider.overrideWithValue(testEnv()),
        appInfoProvider.overrideWith(
          (ref) async => const AppInfo(version: '1.2.3', buildNumber: '45'),
        ),
        appDatabaseProvider.overrideWithValue(db),
        authStateProvider.overrideWith(() => this.auth),
        deviceIdProvider.overrideWith((ref) async => 'installation-1'),
        apiLanguageTagProvider.overrideWithValue(() => 'de-CH'),
        pushPlatformProvider.overrideWithValue(platform),
        pushClockProvider.overrideWithValue(clock.call),
        analyticsProvider.overrideWithValue(analytics),
        analysisReadyListenerProvider.overrideWithValue(listener),
        ...api.overrides,
        ...overrides,
      ],
    );
    addTearDown(() async {
      container.dispose();
      // Not awaited: without a listener the future of close() never ends.
      unawaited(platform.controller.close());
      await db.close();
    });
  }

  final FakeClock clock = FakeClock();
  final FixtureLink api = FixtureLink();
  final FakePushPlatform platform;
  final TestAuthNotifier auth;
  final RecordingAnalytics analytics = RecordingAnalytics();
  final RecordingListener listener = RecordingListener();
  late final AppDatabase db;
  late final ProviderContainer container;

  PushService get service => container.read(pushServiceProvider);

  List<Map<String, dynamic>> get registrations => [
    for (final request in api.requestsOf('RegisterMobileDevice'))
      request.variables['input'] as Map<String, dynamic>,
  ];

  List<String> get apiCalls => [
    for (final request in api.requests) request.operationName,
  ];
}
