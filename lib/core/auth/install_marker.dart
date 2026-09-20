// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers that this installation has started before.
///
/// iOS deletes an app's preferences together with the app, but not its
/// Keychain items. A missing marker next to stored tokens therefore means:
/// the app was deleted and installed again, and the tokens belong to whoever
/// used it before. `AppAuthRepository.restore` wipes them in that case.
abstract interface class InstallMarker {
  Future<bool> isSet();

  Future<void> set();
}

class PreferencesInstallMarker implements InstallMarker {
  /// Takes a getter, because `SharedPreferencesAsync()` needs the platform
  /// plugin at construction time and nothing here is needed before
  /// `restore()`.
  const PreferencesInstallMarker(this._preferences);

  static const String key = 'auth.install_marker';

  final SharedPreferencesAsync Function() _preferences;

  @override
  Future<bool> isSet() async => await _preferences().getBool(key) ?? false;

  @override
  Future<void> set() => _preferences().setBool(key, true);
}

/// For tests.
class InMemoryInstallMarker implements InstallMarker {
  InMemoryInstallMarker({this._isSet = false});

  bool _isSet;

  @override
  Future<bool> isSet() async => _isSet;

  @override
  Future<void> set() async => _isSet = true;
}
