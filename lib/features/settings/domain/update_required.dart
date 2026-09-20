// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _log = Log('update');

/// Where "Update" leads.
// TODO(launch): the real App Store id, once the app record exists.
const String kAppStoreUrl = 'https://apps.apple.com/app/id0000000000';

/// Compares dotted version numbers ("1.10.0" is newer than "1.9.3").
/// Missing parts count as 0 and anything after the numbers ("-beta", "+45")
/// is ignored; a part that is no number counts as 0. Negative when [a] is
/// older than [b].
int compareVersions(String a, String b) {
  List<int> parse(String version) => version
      .split(RegExp('[-+]'))
      .first
      .split('.')
      .map((part) => int.tryParse(part.trim()) ?? 0)
      .toList();

  final left = parse(a);
  final right = parse(b);
  for (var i = 0; i < left.length || i < right.length; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}

/// True when the backend no longer supports this version of the app
/// (`mobileConfig.minSupportedAppVersion` is newer than the running one).
///
/// Fails open: while nobody is signed in (the query needs a token), offline,
/// or when the version of the app is not known, the answer is false. A
/// version that is really too old gets refused by the server anyway; the
/// gate only turns that into a sentence a person can act on.
final updateRequiredProvider = FutureProvider<bool>((ref) async {
  try {
    if (ref.watch(authStateProvider) is! SignedIn) return false;
    final info = await ref.watch(appInfoProvider.future);
    final config = await ref.watch(configApiProvider).mobileConfig();
    return compareVersions(info.version, config.minSupportedAppVersion) < 0;
  } on Object catch (error) {
    _log.info('minimum version not checked: $error');
    return false;
  }
}, retry: (_, _) => null);
