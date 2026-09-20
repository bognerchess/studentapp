// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/log.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Work that needs the session one last time: called at the start of an
/// explicit sign-out, while the access token still works, with the subject
/// that is signing out.
typedef BeforeSignOutHook = Future<void> Function(String sub);

/// The hooks the auth repositories run before they forget the tokens. Push
/// unregisters the device here and analytics sends what is in its outbox.
///
/// A hook cannot stop a sign-out: each one gets [timeout], and what it throws
/// is logged by type and dropped. They run one after the other, in the order
/// they were added.
class BeforeSignOutHooks {
  BeforeSignOutHooks({this.timeout = const Duration(seconds: 5)});

  final Duration timeout;
  final List<BeforeSignOutHook> _hooks = [];

  static const _log = Log('auth.hooks');

  /// Adds [hook] and returns the call that removes it again.
  void Function() add(BeforeSignOutHook hook) {
    _hooks.add(hook);
    return () => _hooks.remove(hook);
  }

  /// Never throws.
  Future<void> run(String sub) async {
    for (final hook in List.of(_hooks)) {
      try {
        await hook(sub).timeout(timeout);
      } on Object catch (error) {
        _log.warning('a before-sign-out hook failed (${error.runtimeType})');
      }
    }
  }
}

final beforeSignOutHooksProvider = Provider<BeforeSignOutHooks>(
  (ref) => BeforeSignOutHooks(),
);
