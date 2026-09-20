// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/widgets.dart';

/// "Is the app on screen?", for providers that poll or send while it is.
///
/// A plain [WidgetsBindingObserver] and not [AppLifecycleListener], which
/// asserts on a transition it considers impossible (paused straight back to
/// resumed). Widget tests drive the life cycle by hand and skip states, and
/// a wrong assumption about iOS must not crash the app.
class AppForeground extends WidgetsBindingObserver {
  AppForeground({this.onResume, this.onChanged}) {
    WidgetsBinding.instance.addObserver(this);
  }

  /// The app became visible again.
  final VoidCallback? onResume;

  /// Called with true when the app became visible, false when it left.
  final ValueChanged<bool>? onChanged;

  /// Whether the app is visible now. Before the platform has said anything
  /// (`lifecycleState` is null at start-up) it counts as visible.
  static bool get isForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  bool _foreground = isForeground;

  void dispose() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) {
      return;
    }
    _foreground = foreground;
    onChanged?.call(foreground);
    if (foreground) {
      onResume?.call();
    }
  }
}
