// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/app_info.dart';

/// The public repository that holds the complete corresponding source of
/// every released build. The only place this address is written down.
// TODO(launch): the repository is private until launch (PRD phase 6). Until
// then the link answers 404 for everybody outside the organisation. Check the
// address again when the repository goes public.
const String kSourceRepositoryBase =
    'https://github.com/bognerchess/studentapp';

/// The tag a build is released from: `v<version>+<build>`, see `pubspec.yaml`
/// and `docs/building.md`.
String releaseTagFor(AppInfo info) => 'v${info.version}+${info.buildNumber}';

/// Where the source of exactly this build can be read and downloaded. The GPL
/// asks for the source of the conveyed version, so the link names the tag and
/// not the default branch.
///
/// Without [info] (the platform did not answer) it falls back to the
/// repository itself, which is still better than no link.
Uri sourceUrlFor(AppInfo? info) {
  if (info == null) {
    return Uri.parse(kSourceRepositoryBase);
  }
  return Uri.parse('$kSourceRepositoryBase/tree/${releaseTagFor(info)}');
}
