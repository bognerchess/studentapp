// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/analytics/analytics.dart';
import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/api/devices_api.dart';
import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/auth/sign_out_hooks.dart';
import 'package:bogner_chess/core/device/device_id.dart';
import 'package:bogner_chess/core/links/incoming_link_service.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/push/push_hooks.dart';
import 'package:bogner_chess/core/push/push_message.dart';
import 'package:bogner_chess/core/push/push_permission.dart';
import 'package:bogner_chess/core/push/push_platform.dart';
import 'package:bogner_chess/core/push/ui/push_explainer_sheet.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// The clock of [PushService]; tests move it.
final pushClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Shows the explainer and returns whether the user wants notifications.
/// Tests override it to answer without a sheet.
typedef PushExplainer = Future<bool> Function(BuildContext context);

final pushExplainerProvider = Provider<PushExplainer>(
  (ref) => showPushExplainerSheet,
);

/// What iOS says right now; for the settings screen, which shows "Open
/// Settings" (`PushService.openSystemSettings`) when it is `denied`.
/// Invalidate it when the app resumes.
final pushPermissionStatusProvider =
    FutureProvider.autoDispose<PushPermissionStatus>(
      (ref) => ref.watch(pushPlatformProvider).permissionStatus(),
    );

/// A registration is sent again after this long even when nothing changed,
/// so that the server's "last seen" stays meaningful.
const Duration kPushRegistrationMaxAge = Duration(days: 7);

/// Push notifications, the Dart half.
///
/// **Permission.** [maybeAskForPermission] is called by the feature that
/// just sent the first analysis request. It shows the explainer sheet and
/// only then the system prompt, which iOS shows once per installation. After
/// a "no" to iOS it never asks again (the settings screen offers the way
/// into the Settings app); after "Not now" in the explainer it asks once
/// more, two weeks later at the earliest. The native side registers with
/// APNs only after the user allowed notifications.
///
/// **Token.** The device is registered with the server at app start, after a
/// sign-in and when APNs reports a token, unless the same registration
/// (account, token, environment, app version, language) was sent within
/// [kPushRegistrationMaxAge]. Before an explicit sign-out the device is
/// unregistered, while the access token still works
/// (`beforeSignOutHooksProvider`). A session that merely expired cannot
/// unregister; the next sign-in on this installation re-registers the device
/// for whoever signs in.
///
/// **Notifications.** "Analysis ready" in the foreground refreshes the job
/// tracker ([analysisReadyListenerProvider]); iOS shows the banner unless
/// that game's review is on screen. A tap opens the review through
/// `IncomingLinkService.openLocation` (so the payload cannot open anything a
/// link could not), refreshes, and records `analysis_ready_opened`. Signed
/// out, the router keeps the location until after sign-in. A notification of
/// an unknown type just opens the app.
///
/// `main.dart` calls [start] once. Nothing here throws into a caller.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  StreamSubscription<PushEvent>? _subscription;
  ProviderSubscription<AuthState>? _authSubscription;
  void Function()? _removeSignOutHook;
  GoRouterListenable? _routerListenable;
  Timer? _tokenWait;

  String? _token;
  ApnsEnvironment? _environment;
  String? _visibleGame;
  bool _asking = false;

  /// Registrations and the unregistration happen one after the other.
  Future<void> _tail = Future<void>.value();

  static const _log = Log('push');
  static const _registrationKey = 'push.registration';

  /// How long the first registration of a start waits for the APNs token, so
  /// that one call carries it instead of two calls a moment apart.
  /// Tests shorten it.
  @visibleForTesting
  static Duration tokenWait = const Duration(seconds: 8);

  DateTime _now() => _ref.read(pushClockProvider)();

  /// Completes when every registration call requested so far is done.
  @visibleForTesting
  Future<void> get idle => _tail;

  void start() {
    if (_subscription != null) return;
    _subscription = _ref
        .read(pushPlatformProvider)
        .events
        .listen(
          _onEvent,
          onError: (Object error, StackTrace stack) {
            _log.warning('push events failed: ${error.runtimeType}');
          },
        );
    _authSubscription = _ref.listen(authStateProvider, (previous, next) {
      if (previous is SignedOut && next is SignedIn) {
        syncRegistration();
      }
    });
    _removeSignOutHook = _ref
        .read(beforeSignOutHooksProvider)
        .add(unregisterBeforeSignOut);
    _watchVisibleGame();
    unawaited(_registerAtStart());
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _authSubscription?.close();
    _authSubscription = null;
    _removeSignOutHook?.call();
    _removeSignOutHook = null;
    _routerListenable?.dispose();
    _routerListenable = null;
    _tokenWait?.cancel();
    _tokenWait = null;
  }

  // ---- Permission ---------------------------------------------------------

  /// Asks for the notification permission if this is a good moment and the
  /// user has not been asked before (see the class comment). [context] is
  /// where the explainer sheet opens; without one the root navigator is used.
  Future<PushAskOutcome> maybeAskForPermission({
    PushAskReason reason = PushAskReason.afterFirstSubmit,
    BuildContext? context,
  }) async {
    if (_asking || _ref.read(authStateProvider) is! SignedIn) {
      return PushAskOutcome.notAsked;
    }
    _asking = true;
    try {
      final platform = _ref.read(pushPlatformProvider);
      final store = PushAskStore(_ref.read(appDatabaseProvider).kvDao);
      final decision = decidePushAsk(
        status: await platform.permissionStatus(),
        record: await store.read(),
        now: _now(),
      );
      if (decision != PushAskDecision.ask) {
        _log.info('not asking for push: ${decision.name}');
        return PushAskOutcome.notAsked;
      }
      final sheetContext = context ?? rootNavigatorKey.currentContext;
      if (sheetContext == null || !sheetContext.mounted) {
        return PushAskOutcome.notAsked;
      }
      final wanted = await _ref.read(pushExplainerProvider)(sheetContext);
      if (!wanted) {
        await store.recordNotNow(_now());
        _trackPermission('not_now', reason);
        return PushAskOutcome.notNow;
      }
      final granted = await platform.requestPermission();
      await store.recordSystemAnswer(granted: granted);
      _trackPermission(granted ? 'granted' : 'denied', reason);
      _ref.invalidate(pushPermissionStatusProvider);
      // Granted: the native side registers with APNs, the token arrives as
      // an event and is sent to the server from there.
      return granted ? PushAskOutcome.granted : PushAskOutcome.denied;
    } on Object catch (error) {
      _log.warning('asking for push failed (${error.runtimeType})');
      return PushAskOutcome.notAsked;
    } finally {
      _asking = false;
    }
  }

  /// For the settings screen, when iOS says "denied".
  Future<void> openSystemSettings() async {
    try {
      await _ref.read(pushPlatformProvider).openSettings();
    } on Object catch (error) {
      _log.warning('could not open the settings (${error.runtimeType})');
    }
  }

  void _trackPermission(String result, PushAskReason reason) {
    _ref.read(analyticsProvider).track(AnalyticsEvents.pushPermissionResult, {
      'result': result,
      'reason': reason.wireName,
    });
  }

  // ---- Token and registration --------------------------------------------

  Future<void> _registerAtStart() async {
    var status = PushPermissionStatus.denied;
    try {
      status = await _ref.read(pushPlatformProvider).registerIfAuthorized();
    } on Object catch (error) {
      _log.warning('could not check the permission (${error.runtimeType})');
    }
    if (_subscription == null) return;
    if (status != PushPermissionStatus.authorized) {
      syncRegistration();
    } else if (_token == null) {
      // The token event triggers the registration; this is the net below it
      // (no network, a simulator without APNs).
      _tokenWait = Timer(tokenWait, syncRegistration);
    }
    // Otherwise the token was quicker than this method and has registered.
  }

  /// Registers this installation for the signed-in account unless the same
  /// registration was sent recently. Never throws; completes with [idle].
  void syncRegistration() {
    _tokenWait?.cancel();
    _tokenWait = null;
    _tail = _tail.then((_) => _register());
  }

  Future<void> _register() async {
    try {
      final auth = _ref.read(authStateProvider);
      if (auth is! SignedIn) return;
      final platform = _ref.read(pushPlatformProvider);
      final environment = _environment ?? await platform.environment();
      final deviceId = await _ref.read(deviceIdProvider.future);
      final appVersion = await _appVersion();
      final locale = _ref.read(apiLanguageTagProvider)();
      final token = _token;

      final kv = _ref.read(appDatabaseProvider).kvDao;
      final fingerprint = [
        token ?? '-',
        environment.name,
        appVersion ?? '-',
        locale,
      ].join('|');
      final now = _now().toUtc();
      final last = await kv.get(_registrationKey, ownerSub: auth.sub);
      if (last != null) {
        final separator = last.indexOf(' ');
        final sentAt = DateTime.tryParse(
          separator < 0 ? '' : last.substring(0, separator),
        );
        if (sentAt != null &&
            last.substring(separator + 1) == fingerprint &&
            now.difference(sentAt) < kPushRegistrationMaxAge) {
          return;
        }
      }
      await _ref
          .read(devicesApiProvider)
          .register(
            deviceId: deviceId,
            environment: environment,
            apnsToken: token,
            appVersion: appVersion,
            locale: locale,
          );
      // Owner-scoped: a sign-out wipes it, so the next sign-in registers.
      if (_ref.read(authStateProvider) == auth) {
        await kv.set(
          _registrationKey,
          '${now.toIso8601String()} $fingerprint',
          ownerSub: auth.sub,
        );
      }
      _log.info('device registered (token: ${token != null})');
    } on ApiError catch (error) {
      // The next start, sign-in or token tries again.
      _log.warning('device registration failed: $error');
    } on Object catch (error) {
      _log.warning('device registration failed (${error.runtimeType})');
    }
  }

  /// The before-sign-out hook: the server stops sending to this installation
  /// before the tokens are gone. Waits for a registration in flight, so that
  /// it cannot overtake the unregistration.
  Future<void> unregisterBeforeSignOut(String sub) {
    final done = _tail.then((_) async {
      try {
        final deviceId = await _ref.read(deviceIdProvider.future);
        await _ref.read(devicesApiProvider).unregister(deviceId);
        _log.info('device unregistered');
      } on ApiError catch (error) {
        // Offline sign-out: the device stays registered until somebody signs
        // in here again or the server sees APNs refuse the token.
        _log.warning('device unregistration failed: $error');
      } finally {
        await _ref
            .read(appDatabaseProvider)
            .kvDao
            .remove(_registrationKey, ownerSub: sub);
      }
    });
    _tail = done.then((_) {}, onError: (Object _) {});
    return done;
  }

  Future<String?> _appVersion() async {
    try {
      final info = await _ref.read(appInfoProvider.future);
      return '${info.version}+${info.buildNumber}';
    } on Object {
      return null;
    }
  }

  // ---- Notifications -------------------------------------------------------

  void _onEvent(PushEvent event) {
    try {
      switch (event) {
        case PushTokenEvent(:final token, :final environment):
          _token = token;
          _environment = environment;
          syncRegistration();
        case PushTokenErrorEvent(:final code):
          _log.warning('no APNs token: $code');
          syncRegistration();
        case PushReceivedEvent(:final message):
          _log.info('push received in the foreground: $message');
          if (message is AnalysisReadyMessage) {
            _refresh(message);
          }
        case PushOpenedEvent(:final message, :final coldStart):
          _log.info('push opened: $message');
          if (message is AnalysisReadyMessage) {
            _open(message, coldStart: coldStart);
          }
      }
    } on Object catch (error) {
      // Input from outside must not be able to take the app down.
      _log.warning('could not handle a push event (${error.runtimeType})');
    }
  }

  void _open(AnalysisReadyMessage message, {required bool coldStart}) {
    final opened = _ref
        .read(incomingLinkServiceProvider)
        .openLocation(AppRoutes.gameReview(message.gameId));
    _refresh(message);
    if (opened) {
      _ref.read(analyticsProvider).track(AnalyticsEvents.analysisReadyOpened, {
        'source': 'push',
        'cold_start': coldStart,
      });
    }
  }

  void _refresh(AnalysisReadyMessage message) {
    try {
      _ref
          .read(analysisReadyListenerProvider)
          .refreshNow(gameId: message.gameId, jobId: message.jobId);
    } on Object catch (error) {
      _log.warning('the analysis-ready listener failed (${error.runtimeType})');
    }
  }

  // ---- Which review is on screen -----------------------------------------

  void _watchVisibleGame() {
    final router = _ref.read(routerProvider);
    final listenable = GoRouterListenable(router, _updateVisibleGame);
    _routerListenable = listenable;
    _updateVisibleGame(listenable.currentUri);
  }

  void _updateVisibleGame(Uri uri) {
    final segments = uri.pathSegments;
    final gameId =
        segments.length == 3 &&
            segments[0] == 'games' &&
            segments[2] == 'review'
        ? segments[1]
        : null;
    if (gameId == _visibleGame) return;
    _visibleGame = gameId;
    unawaited(
      _ref.read(pushPlatformProvider).setVisibleGame(gameId).catchError((
        Object error,
      ) {
        _log.warning('could not set the visible game (${error.runtimeType})');
      }),
    );
  }
}

/// Reports the router's location whenever it changes.
class GoRouterListenable {
  GoRouterListenable(this._router, this._onChanged) {
    _router.routerDelegate.addListener(_changed);
  }

  final GoRouter _router;
  final void Function(Uri uri) _onChanged;

  Uri get currentUri => _router.routerDelegate.currentConfiguration.uri;

  void _changed() => _onChanged(currentUri);

  void dispose() => _router.routerDelegate.removeListener(_changed);
}
