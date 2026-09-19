// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/log.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the display on. Entering a game from a score sheet means looking at
/// the paper for longer than the auto-lock allows.
abstract interface class ScreenWakelock {
  Future<void> enable();
  Future<void> disable();
}

/// The only importer of `wakelock_plus`. Tests override it with a fake.
final screenWakelockProvider = Provider<ScreenWakelock>(
  (ref) => const PluginScreenWakelock(),
);

const _log = Log('entry.wakelock');

/// `wakelock_plus`. A failure (no plugin in a widget test, a platform that
/// refuses) is logged and otherwise ignored: a dimming screen is a nuisance,
/// not a reason to break move entry.
class PluginScreenWakelock implements ScreenWakelock {
  const PluginScreenWakelock();

  @override
  Future<void> enable() => _toggle(enable: true);

  @override
  Future<void> disable() => _toggle(enable: false);

  Future<void> _toggle({required bool enable}) async {
    try {
      await WakelockPlus.toggle(enable: enable);
    } on Object catch (error) {
      _log.warning('wakelock ${enable ? 'enable' : 'disable'} failed: $error');
    }
  }
}
