// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Version and build number of the running app (`0.1.0` and `1` for
/// `version: 0.1.0+1`). Release tags have the form `v<version>+<build>`.
@immutable
class AppInfo {
  const AppInfo({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;
}

/// Tests override it with `appInfoProvider.overrideWith((ref) => ...)`.
final appInfoProvider = FutureProvider<AppInfo>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppInfo(version: info.version, buildNumber: info.buildNumber);
  // A platform that cannot answer now will not answer later either.
}, retry: (_, _) => null);
