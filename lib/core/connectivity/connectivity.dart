// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/log.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device has a network interface that is up. A hint, never a
/// promise: "online" says nothing about the server being reachable, so
/// callers still make the request and handle its failure. What it is good
/// for is the moment it turns true, which is when waiting uploads are worth
/// another try, and the word "offline" in a status line.
abstract interface class ConnectivitySource {
  /// The current state. Never throws; when the platform cannot say, the
  /// answer is true, because a wrong "offline" would hold work back.
  Future<bool> isOnline();

  /// Every change of the state, without the initial value.
  Stream<bool> get changes;
}

/// [ConnectivitySource] on `connectivity_plus`, its only importer.
class PluginConnectivitySource implements ConnectivitySource {
  PluginConnectivitySource([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  static const _log = Log('connectivity');

  final Connectivity _connectivity;

  static bool _online(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  @override
  Future<bool> isOnline() async {
    try {
      return _online(await _connectivity.checkConnectivity());
    } on Object catch (error) {
      _log.warning('check failed (${error.runtimeType}), assuming online');
      return true;
    }
  }

  @override
  Stream<bool> get changes => _connectivity.onConnectivityChanged
      .map(_online)
      .handleError((Object error) {
        _log.warning('change stream failed (${error.runtimeType})');
      })
      .distinct();
}

/// Tests override this with a source they control.
final connectivityProvider = Provider<ConnectivitySource>(
  (ref) => PluginConnectivitySource(),
);
