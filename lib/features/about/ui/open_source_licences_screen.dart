// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Every package in the build with its licence text, from Flutter's
/// `LicenseRegistry`: what the tool collected from the packages' LICENSE
/// files, plus the entries of `registerAdditionalLicenses()`.
///
/// This is `material_ui`'s [LicensePage], not the framework's legacy one, so
/// it takes the app's theme and the German Material strings. It loads the
/// registry in slices between frames, which a hand-written list would have to
/// repeat: the NOTICES file of a Flutter app is several hundred kilobytes.
class OpenSourceLicencesScreen extends ConsumerWidget {
  const OpenSourceLicencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final appInfo = ref.watch(appInfoProvider).value;
    return LicensePage(
      applicationName: l10n.appTitle,
      applicationVersion: appInfo == null
          ? null
          : l10n.settingsVersion(appInfo.version, appInfo.buildNumber),
      applicationLegalese: l10n.aboutFreeSoftwareNotice,
    );
  }
}
