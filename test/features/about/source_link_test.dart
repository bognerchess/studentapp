// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/features/about/domain/source_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the link names the release tag of the running build', () {
    const info = AppInfo(version: '1.2.3', buildNumber: '45');

    expect(releaseTagFor(info), 'v1.2.3+45');
    expect(
      sourceUrlFor(info).toString(),
      'https://github.com/bognerchess/studentapp/tree/v1.2.3+45',
    );
  });

  test('without app info the link is the repository', () {
    expect(sourceUrlFor(null).toString(), kSourceRepositoryBase);
  });

  test('the repository address is https and has no trailing slash', () {
    final base = Uri.parse(kSourceRepositoryBase);
    expect(base.scheme, 'https');
    expect(kSourceRepositoryBase.endsWith('/'), isFalse);
  });
}
