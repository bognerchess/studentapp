// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:io';

import 'package:bogner_chess/core/api/models/device_models.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/auth/sign_out_hooks.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/push/push_message.dart';
import 'package:bogner_chess/core/push/push_permission.dart';
import 'package:bogner_chess/core/push/push_platform.dart';
import 'package:bogner_chess/core/push/push_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../storage/test_database.dart';
import 'push_test_support.dart';

/// Lets start(), the event stream and the database run. Real time, because
/// drift's in-memory database answers asynchronously.
Future<void> settle(PushHarness h) async {
  await Future<void>.delayed(const Duration(milliseconds: 40));
  await h.service.idle;
}

class _MountedContext extends Fake implements BuildContext {
  @override
  bool get mounted => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Log.sink = (_) {};
    PushService.tokenWait = const Duration(milliseconds: 100);
  });
  tearDown(() {
    Log.resetSink();
    PushService.tokenWait = const Duration(seconds: 8);
  });

  group('registration', () {
    test('without permission the device is registered without a token, and '
        'APNs is not asked', () async {
      final h = PushHarness()..service.start();
      await settle(h);

      expect(h.platform.calls, isNot(contains('apns.register')));
      expect(h.platform.calls, isNot(contains('requestPermission')));
      final input = h.registrations.single;
      expect(input['deviceId'], 'installation-1');
      expect(input['apnsToken'], isNull);
      expect(input['environment'], 'SANDBOX');
      expect(input['appVersion'], '1.2.3+45');
      expect(input['locale'], 'de-CH');
    });

    test('with permission the start registers with APNs and sends the token '
        'in one call', () async {
      final h = PushHarness(status: PushPermissionStatus.authorized)
        ..service.start();
      await settle(h);

      expect(h.platform.calls, contains('apns.register'));
      expect(h.registrations.single['apnsToken'], kTestToken);
    });

    test('no token from APNs (a simulator, no network): registered without '
        'one after the wait', () async {
      final h = PushHarness(status: PushPermissionStatus.authorized);
      h.platform.deliversToken = false;
      h.service.start();
      await settle(h);
      expect(h.registrations, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      await h.service.idle;
      expect(h.registrations.single['apnsToken'], isNull);
    });

    test('the same registration is not sent twice', () async {
      final h = PushHarness(status: PushPermissionStatus.authorized)
        ..service.start();
      await settle(h);

      h.service
        ..syncRegistration()
        ..syncRegistration();
      h.platform.controller.add(
        const PushTokenEvent(kTestToken, ApnsEnvironment.sandbox),
      );
      await settle(h);
      expect(h.registrations, hasLength(1));
    });

    test('a new token is sent', () async {
      final h = PushHarness(status: PushPermissionStatus.authorized)
        ..service.start();
      await settle(h);

      final newToken = kTestToken.replaceFirst('00ff', 'aabb');
      h.platform.controller.add(
        PushTokenEvent(newToken, ApnsEnvironment.sandbox),
      );
      await settle(h);
      expect(
        [for (final r in h.registrations) r['apnsToken']],
        [kTestToken, newToken],
      );
    });

    test('after a week the registration is refreshed', () async {
      final h = PushHarness(status: PushPermissionStatus.authorized)
        ..service.start();
      await settle(h);

      h.clock.advance(const Duration(days: 6));
      h.service.syncRegistration();
      await settle(h);
      expect(h.registrations, hasLength(1));

      h.clock.advance(const Duration(days: 1));
      h.service.syncRegistration();
      await settle(h);
      expect(h.registrations, hasLength(2));
    });

    test('a failed registration is tried again the next time', () async {
      final h = PushHarness(status: PushPermissionStatus.authorized);
      h.api.fail('RegisterMobileDevice', const SocketException('offline'));
      h.service.start();
      await settle(h);
      expect(h.registrations, hasLength(1));

      h.api.use('RegisterMobileDevice', 'default');
      h.service.syncRegistration();
      await settle(h);
      expect(h.registrations, hasLength(2));

      h.service.syncRegistration();
      await settle(h);
      expect(h.registrations, hasLength(2));
    });

    test('signed out, nothing is registered; the sign-in registers', () async {
      final h = PushHarness(
        auth: const SignedOut(),
        status: PushPermissionStatus.authorized,
      )..service.start();
      await settle(h);
      expect(h.registrations, isEmpty);

      h.auth.set(const SignedIn(alice));
      await settle(h);
      expect(h.registrations.single['apnsToken'], kTestToken);
    });
  });

  group('sign-out', () {
    test('the device is unregistered by the before-sign-out hook, after a '
        'registration that was still in flight', () async {
      final h = PushHarness(status: PushPermissionStatus.authorized);
      h.api.delay = const Duration(milliseconds: 30);
      h.service.start();
      // Do not wait: the registration is on its way when the user signs out.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await h.container.read(beforeSignOutHooksProvider).run(alice);

      expect(h.apiCalls, ['RegisterMobileDevice', 'UnregisterMobileDevice']);
      expect(
        (h.api.requestsOf('UnregisterMobileDevice').single.variables['input']
            as Map)['deviceId'],
        'installation-1',
      );
    });

    test(
      'the next sign-in registers again, also for the same account',
      () async {
        final h = PushHarness(status: PushPermissionStatus.authorized)
          ..service.start();
        await settle(h);
        await h.container.read(beforeSignOutHooksProvider).run(alice);
        h.auth.set(const SignedOut());
        await settle(h);

        h.auth.set(const SignedIn(alice));
        await settle(h);
        expect(h.apiCalls, [
          'RegisterMobileDevice',
          'UnregisterMobileDevice',
          'RegisterMobileDevice',
        ]);
      },
    );

    test('an offline sign-out is not held up and does not throw', () async {
      final h = PushHarness(status: PushPermissionStatus.authorized)
        ..service.start();
      await settle(h);
      h.api.fail('UnregisterMobileDevice', const SocketException('offline'));
      await expectLater(
        h.container.read(beforeSignOutHooksProvider).run(alice),
        completes,
      );
    });

    test('a disposed service leaves no hook behind', () async {
      final h = PushHarness()..service.start();
      await settle(h);
      h.service.dispose();
      await h.container.read(beforeSignOutHooksProvider).run(alice);
      expect(h.api.requestsOf('UnregisterMobileDevice'), isEmpty);
    });
  });

  group('maybeAskForPermission', () {
    PushHarness harness({
      required bool explainerAnswer,
      PushPermissionStatus status = PushPermissionStatus.notDetermined,
      AuthState auth = const SignedIn(alice),
      List<String>? shown,
    }) {
      return PushHarness(
        status: status,
        auth: auth,
        overrides: [
          pushExplainerProvider.overrideWithValue((context) async {
            shown?.add('explainer');
            return explainerAnswer;
          }),
        ],
      );
    }

    // The explainer is replaced, so a stand-in context will do.
    Future<PushAskOutcome> ask(PushHarness h) =>
        h.service.maybeAskForPermission(context: _MountedContext());

    test('explainer, then the system prompt; granted', () async {
      final shown = <String>[];
      final h = harness(explainerAnswer: true, shown: shown);
      expect(await ask(h), PushAskOutcome.granted);

      expect(shown, ['explainer']);
      expect(h.platform.calls, [
        'permissionStatus',
        'requestPermission',
        'apns.register',
      ]);
      final (name, props) = h.analytics.events.single;
      expect(name, 'push_permission_result');
      expect(props, {'result': 'granted', 'reason': 'after_first_submit'});
    });

    test('the token that follows a grant is registered', () async {
      final h = harness(explainerAnswer: true);
      h.service.start();
      await settle(h);
      await ask(h);
      await settle(h);

      expect(
        [for (final r in h.registrations) r['apnsToken']],
        [null, kTestToken],
      );
    });

    test('denied in the system prompt: recorded, never asked again', () async {
      final shown = <String>[];
      final h = harness(explainerAnswer: true, shown: shown);
      h.platform.grantOnRequest = false;
      expect(await ask(h), PushAskOutcome.denied);
      expect(h.analytics.events.single.$2['result'], 'denied');

      expect(await ask(h), PushAskOutcome.notAsked);
      h.clock.advance(const Duration(days: 365));
      expect(await ask(h), PushAskOutcome.notAsked);
      expect(shown, ['explainer']);
      expect(
        h.platform.calls.where((call) => call == 'requestPermission'),
        hasLength(1),
      );
    });

    test('"Not now": no system prompt; once more after two weeks, '
        'then never', () async {
      final shown = <String>[];
      final h = harness(explainerAnswer: false, shown: shown);

      expect(await ask(h), PushAskOutcome.notNow);
      expect(h.platform.calls, isNot(contains('requestPermission')));
      expect(h.analytics.events.single.$2['result'], 'not_now');

      h.clock.advance(const Duration(days: 13));
      expect(await ask(h), PushAskOutcome.notAsked);
      h.clock.advance(const Duration(days: 1));
      expect(await ask(h), PushAskOutcome.notNow);
      h.clock.advance(const Duration(days: 365));
      expect(await ask(h), PushAskOutcome.notAsked);

      expect(shown, hasLength(2));
      expect(h.platform.calls, isNot(contains('requestPermission')));
    });

    test('already allowed, denied in Settings, or signed out: no '
        'explainer', () async {
      for (final (status, auth) in [
        (PushPermissionStatus.authorized, const SignedIn(alice)),
        (PushPermissionStatus.denied, const SignedIn(alice)),
        (PushPermissionStatus.notDetermined, const SignedOut()),
      ]) {
        final shown = <String>[];
        final h = harness(
          explainerAnswer: true,
          status: status,
          auth: auth,
          shown: shown,
        );
        expect(await ask(h), PushAskOutcome.notAsked);
        expect(shown, isEmpty);
        expect(h.analytics.events, isEmpty);
      }
    });

    test('openSystemSettings asks the native side', () async {
      final h = harness(explainerAnswer: true);
      await h.service.openSystemSettings();
      expect(h.platform.calls, ['openSettings']);
    });
  });

  group('notifications', () {
    const ready = AnalysisReadyMessage(gameId: 'game-1', jobId: 'job-1');

    test('received in the foreground: the job tracker refreshes, nothing is '
        'opened or tracked', () async {
      final h = PushHarness()..service.start();
      await settle(h);
      h.platform.controller.add(const PushReceivedEvent(ready));
      await settle(h);

      expect(h.listener.calls, ['game-1/job-1']);
      expect(h.analytics.events, isEmpty);
    });

    test('an unknown type does nothing, received or opened', () async {
      final h = PushHarness()..service.start();
      await settle(h);
      h.platform.controller
        ..add(const PushReceivedEvent(UnknownPushMessage('weekly_summary')))
        ..add(
          const PushOpenedEvent(
            UnknownPushMessage('weekly_summary'),
            coldStart: false,
          ),
        );
      await settle(h);

      expect(h.listener.calls, isEmpty);
      expect(h.analytics.events, isEmpty);
    });

    test('an error on the event stream is survived', () async {
      final h = PushHarness()..service.start();
      await settle(h);
      h.platform.controller
        ..addError(StateError('channel'))
        ..add(const PushReceivedEvent(ready));
      await settle(h);
      expect(h.listener.calls, ['game-1/job-1']);
    });
  });
}
