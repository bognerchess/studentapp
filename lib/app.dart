// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/links/incoming_link_notices.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/core/ui/widgets/env_banner.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The root widget: router, themes and localisation. It expects a
/// `ProviderScope` above it (see `main.dart`).
class BognerChessApp extends ConsumerWidget {
  const BognerChessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      onGenerateTitle: (context) => context.l10n.appTitle,
      // Our own EnvBanner replaces the debug ribbon; both sit top-end.
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      // The locale follows the system. English is first in supportedLocales
      // (l10n.yaml), which makes it the fallback for every other language.
      supportedLocales: AppLocalizations.supportedLocales,
      // Not AppLocalizations.localizationsDelegates: that list carries the
      // framework's legacy Material delegate, while this app is built on
      // package:material_ui, which looks up its own.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      // IncomingLinkNotices: "this file could not be read" for a document
      // opened from outside, on whatever screen is showing.
      builder: (context, child) =>
          EnvBanner(child: IncomingLinkNotices(child: child!)),
    );
  }
}
