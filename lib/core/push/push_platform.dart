// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/api/models/device_models.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/push/push_message.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What iOS says about notifications for this app.
enum PushPermissionStatus {
  /// The system prompt was never shown. It can be shown exactly once.
  notDetermined,

  /// The user said no, in the prompt or in the Settings app. Only the
  /// Settings app can change that.
  denied,

  /// Allowed (also "provisional" and "ephemeral").
  authorized,
}

/// What the native side reports.
@immutable
sealed class PushEvent {
  const PushEvent();
}

/// APNs gave the app a device token.
final class PushTokenEvent extends PushEvent {
  const PushTokenEvent(this.token, this.environment);

  /// Lowercase hex.
  final String token;
  final ApnsEnvironment environment;

  @override
  String toString() => 'PushTokenEvent';
}

/// Registering with APNs failed (no entitlement, no network, a simulator
/// that cannot). The app works without push.
final class PushTokenErrorEvent extends PushEvent {
  const PushTokenErrorEvent(this.code);

  /// The `NSError` domain and code, never its text.
  final String code;

  @override
  String toString() => 'PushTokenErrorEvent($code)';
}

/// A notification arrived while the app was in the foreground.
final class PushReceivedEvent extends PushEvent {
  const PushReceivedEvent(this.message);

  final PushMessage message;

  @override
  String toString() => 'PushReceivedEvent($message)';
}

/// The user tapped a notification.
final class PushOpenedEvent extends PushEvent {
  const PushOpenedEvent(this.message, {required this.coldStart});

  final PushMessage message;

  /// The tap started the app.
  final bool coldStart;

  @override
  String toString() => 'PushOpenedEvent($message, coldStart: $coldStart)';
}

/// The native half of push (`ios/Runner/PushHandler.swift`).
abstract interface class PushPlatform {
  /// One stream covers both starts: what happened before anybody listened (a
  /// tap that started the app) is kept by the native side and delivered
  /// first.
  Stream<PushEvent> get events;

  Future<PushPermissionStatus> permissionStatus();

  /// Shows the system prompt (once in the life of an installation) and
  /// returns whether notifications are allowed. When they are, the native
  /// side registers with APNs and a [PushTokenEvent] follows.
  Future<bool> requestPermission();

  /// Registers with APNs if, and only if, the user has allowed
  /// notifications. For every app start: tokens change. Returns the status.
  Future<PushPermissionStatus> registerIfAuthorized();

  /// The build's APNs environment, for a registration without a token.
  Future<ApnsEnvironment> environment();

  /// The game whose review is on screen, or null. A notification for it is
  /// not shown as a banner while the app is in the foreground.
  Future<void> setVisibleGame(String? gameId);

  /// Opens this app's page in the Settings app.
  Future<void> openSettings();
}

final pushPlatformProvider = Provider<PushPlatform>(
  (ref) => const ChannelPushPlatform(),
);

/// Channel contract, all names below `com.bognerchess.mobile/`:
///
/// Event channel `push_events`, maps:
/// * `{kind: token, token: <lowercase hex>, environment: SANDBOX|PRODUCTION}`
/// * `{kind: tokenError, code: <domain>#<code>}`
/// * `{kind: received, payload: {type, gameId?, jobId?}}`
/// * `{kind: opened, coldStart: bool, payload: {type, gameId?, jobId?}}`
///
/// Method channel `push`: `permissionStatus` → `notDetermined|denied|
/// authorized`; `requestPermission` → bool; `registerIfAuthorized` → status;
/// `environment` → `SANDBOX|PRODUCTION`; `setVisibleGame(String?)`;
/// `openSettings`.
///
/// Anything else is dropped, never thrown.
class ChannelPushPlatform implements PushPlatform {
  const ChannelPushPlatform();

  static const String eventChannelName = 'com.bognerchess.mobile/push_events';
  static const String methodChannelName = 'com.bognerchess.mobile/push';
  static const EventChannel _events = EventChannel(eventChannelName);
  static const MethodChannel _methods = MethodChannel(methodChannelName);
  static const _log = Log('push.platform');

  @override
  Stream<PushEvent> get events => _events
      .receiveBroadcastStream()
      .map(decode)
      .where((event) => event != null)
      .cast<PushEvent>();

  @override
  Future<PushPermissionStatus> permissionStatus() async =>
      decodeStatus(await _methods.invokeMethod<Object?>('permissionStatus'));

  @override
  Future<bool> requestPermission() async =>
      await _methods.invokeMethod<bool>('requestPermission') ?? false;

  @override
  Future<PushPermissionStatus> registerIfAuthorized() async => decodeStatus(
    await _methods.invokeMethod<Object?>('registerIfAuthorized'),
  );

  @override
  Future<ApnsEnvironment> environment() async =>
      decodeEnvironment(await _methods.invokeMethod<Object?>('environment')) ??
      _fallbackEnvironment;

  @override
  Future<void> setVisibleGame(String? gameId) =>
      _methods.invokeMethod<void>('setVisibleGame', gameId);

  @override
  Future<void> openSettings() => _methods.invokeMethod<void>('openSettings');

  /// When the native side does not say: a release build is signed for
  /// production, everything else for the sandbox.
  static const ApnsEnvironment _fallbackEnvironment = kReleaseMode
      ? ApnsEnvironment.production
      : ApnsEnvironment.sandbox;

  /// Anything unknown counts as "denied": the app then neither prompts nor
  /// registers.
  @visibleForTesting
  static PushPermissionStatus decodeStatus(Object? value) => switch (value) {
    'authorized' => PushPermissionStatus.authorized,
    'notDetermined' => PushPermissionStatus.notDetermined,
    _ => PushPermissionStatus.denied,
  };

  @visibleForTesting
  static ApnsEnvironment? decodeEnvironment(Object? value) => switch (value) {
    'SANDBOX' => ApnsEnvironment.sandbox,
    'PRODUCTION' => ApnsEnvironment.production,
    _ => null,
  };

  static final RegExp _hexToken = RegExp(r'^[0-9a-f]{16,512}$');

  /// Null for an event this version does not understand.
  @visibleForTesting
  static PushEvent? decode(Object? event) {
    if (event is! Map) {
      _log.warning('dropped an event of type ${event.runtimeType}');
      return null;
    }
    switch (event['kind']) {
      case 'token':
        final token = event['token'];
        final environment = decodeEnvironment(event['environment']);
        if (token is String &&
            _hexToken.hasMatch(token) &&
            environment != null) {
          return PushTokenEvent(token, environment);
        }
      case 'tokenError':
        final code = event['code'];
        return PushTokenErrorEvent(code is String ? code : 'unknown');
      case 'received':
        return PushReceivedEvent(PushMessage.parse(event['payload']));
      case 'opened':
        return PushOpenedEvent(
          PushMessage.parse(event['payload']),
          coldStart: event['coldStart'] == true,
        );
    }
    _log.warning('dropped an event of an unknown shape');
    return null;
  }
}
