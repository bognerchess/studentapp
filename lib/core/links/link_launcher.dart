// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

/// Opens [uri] outside the app. Completes with false when nothing could open
/// it; may also throw, callers treat both the same way.
typedef LinkLauncher = Future<bool> Function(Uri uri);

/// The only importer of `url_launcher`. Widgets read this provider, so tests
/// override it and never reach the platform:
/// `linkLauncherProvider.overrideWithValue((uri) async => true)`.
final linkLauncherProvider = Provider<LinkLauncher>((ref) {
  // In the browser (or the mail app for mailto:), not in an in-app web view:
  // the source link and the links of a legal text are pages people want to
  // keep and share.
  return (uri) => url_launcher.launchUrl(
    uri,
    mode: url_launcher.LaunchMode.externalApplication,
  );
});
