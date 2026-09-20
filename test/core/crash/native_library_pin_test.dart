// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';
import 'dart:io';

import 'package:bogner_chess/features/about/domain/additional_licenses.dart';
import 'package:flutter_test/flutter_test.dart';

/// sentry-cocoa arrives through Swift Package Manager, so nothing in
/// pubspec.lock names its version. NOTICE, the in-app licence list and
/// docs/dependencies.md do, and an upgrade of sentry_flutter must not leave
/// them behind.
void main() {
  test('the sentry-cocoa version in the documents is the resolved one', () {
    final versions = <String>{};
    for (final path in [
      'ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved',
      'ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved',
    ]) {
      final resolved =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final pin = (resolved['pins'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((pin) => pin['identity'] == 'sentry-cocoa');
      versions.add((pin['state'] as Map)['version'] as String);
    }
    final version = versions.single;

    expect(File('NOTICE').readAsStringSync(), contains('| $version '));
    expect(
      File('docs/dependencies.md').readAsStringSync(),
      contains('sentry-cocoa $version'),
    );
    expect(
      additionalLicenses.singleWhere((l) => l.package == 'sentry-cocoa').text,
      contains('version $version'),
    );
  });
}
