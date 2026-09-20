// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:uuid/uuid.dart';

/// The analytics session: a random id per stretch of use. A start of the
/// process begins one; coming back after [timeout] or more in the background
/// begins a new one. The id says nothing about the person or the device and
/// is never stored outside the event outbox.
class SessionTracker {
  SessionTracker({
    required this._now,
    this.timeout = const Duration(minutes: 30),
    String Function()? newId,
  }) : _newId = newId ?? const Uuid().v4 {
    _sessionId = _newId();
  }

  final DateTime Function() _now;
  final String Function() _newId;
  final Duration timeout;

  late String _sessionId;
  DateTime? _backgroundedAt;

  String get sessionId => _sessionId;

  /// The app left the foreground.
  void onBackgrounded() => _backgroundedAt ??= _now();

  /// The app is back. Returns whether that began a new session.
  bool onForegrounded() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null || _now().difference(since) < timeout) {
      return false;
    }
    _sessionId = _newId();
    return true;
  }
}
