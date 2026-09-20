// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

// Development entry point: starts the real app and lands on the about screen
// or on one of its sub-screens, for screenshots on a simulator that nothing
// can tap. Never part of a release; `lib/main.dart` does not import it.
//
//   flutter build ios --simulator --debug \
//     --dart-define-from-file=config/fake.json \
//     -t lib/features/about/dev/about_demo.dart
//   xcrun simctl launch <udid> com.bognerchess.mobile \
//     -AppleLanguages "(de)" -about_demo_screen notice -about_demo_offset 900
//
// Launch arguments of the form `-key value` end up in NSUserDefaults, which
// is where shared_preferences reads from: one build serves every screen.
//
// about_demo_screen: about (default) | source | gpl | permission | notice |
//                    licences
// about_demo_offset: scroll offset of the opened text, in logical pixels

import 'dart:async';

import 'package:bogner_chess/app.dart';
import 'package:bogner_chess/features/about/domain/additional_licenses.dart';
import 'package:bogner_chess/features/about/ui/about_screen.dart';
import 'package:bogner_chess/features/about/ui/licence_text_screen.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Map<String, Key> _rows = {
  // Leaves the app: opens the browser through url_launcher.
  'source': AboutScreen.sourceLinkKey,
  'gpl': AboutScreen.gplKey,
  'permission': AboutScreen.appStorePermissionKey,
  'notice': AboutScreen.noticeKey,
  'licences': AboutScreen.openSourceLicencesKey,
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAdditionalLicenses();

  final arguments = SharedPreferencesAsync();
  final screen = await arguments.getString('about_demo_screen') ?? 'about';
  final offset = double.tryParse(
    await arguments.getString('about_demo_offset') ?? '',
  );

  final container = ProviderContainer();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BognerChessApp(),
    ),
  );

  container.read(routerProvider).go(AppRoutes.settingsAbout);
  await _settle();

  final row = _rows[screen];
  if (row != null) {
    // The same path a finger takes: the row's own onTap.
    final tile = _find((e) => e.widget.key == row)?.widget;
    if (tile is ListTile) {
      tile.onTap?.call();
      await _settle();
    }
  }

  if (offset != null) {
    // A licence text, or else the package list of the licence page.
    final list =
        _find((e) => e.widget.key == LicenceTextScreen.listKey) ??
        _find((e) => e.widget is LicensePage);
    final scrollable = _find(
      (e) => e is StatefulElement && e.state is ScrollableState,
      under: list,
    );
    if (scrollable is StatefulElement) {
      (scrollable.state as ScrollableState).position.jumpTo(offset);
    }
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(seconds: 1));

/// Depth-first search of the widget tree, below [under] or from the root.
Element? _find(bool Function(Element element) test, {Element? under}) {
  Element? found;
  void visit(Element element) {
    if (found != null) {
      return;
    }
    if (test(element)) {
      found = element;
      return;
    }
    element.visitChildren(visit);
  }

  (under ?? WidgetsBinding.instance.rootElement)?.visitChildren(visit);
  return found;
}
