// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

// Development entry point: starts the real app (fake auth, mock server) and
// lands on one of the settings, consent, legal or account screens, for
// screenshots on a simulator that nothing can tap. Never part of a release;
// `lib/main.dart` does not import it. It lives outside `lib/features`
// because it reaches into the `ui/` of four features.
//
//   dart run tool/mock_server/main.dart --port 5299 &
//   flutter build ios --simulator --debug \
//     --dart-define-from-file=config/fake.json -t lib/dev/settings_demo.dart
//   xcrun simctl launch <udid> com.bognerchess.mobile \
//     -AppleLanguages "(de)" -settings_demo_screen delete
//
// Launch arguments of the form `-key value` end up in NSUserDefaults, which
// is where shared_preferences reads from: one build serves every screen.
//
// settings_demo_screen: settings (default) | consent | analytics | account |
//                       delete | delete-typed | delete-run | legal | terms
//   analytics     lets the one-time analytics question open (it is switched
//                 off for every other screen, so that it is not in the way)
//   delete-typed  the deletion screen with the word typed in
//   delete-run    ... and the button pressed: the final confirmation, or the
//                 blocked state after `POST /__scenario deletion_blocked`
// settings_demo_offset: scroll offset of the screen, in logical pixels

import 'dart:async';

import 'package:bogner_chess/app.dart';
import 'package:bogner_chess/core/auth/auth_providers.dart';
import 'package:bogner_chess/features/account/ui/account_screen.dart';
import 'package:bogner_chess/features/account/ui/delete_account_screen.dart';
import 'package:bogner_chess/features/consent/ui/ai_consent_screen.dart';
import 'package:bogner_chess/features/consent/ui/first_run_consent_prompt.dart';
import 'package:bogner_chess/features/legal/ui/legal_document_screen.dart';
import 'package:bogner_chess/features/settings/ui/settings_screen.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final arguments = SharedPreferencesAsync();
  final screen =
      await arguments.getString('settings_demo_screen') ?? 'settings';
  final offset = double.tryParse(
    await arguments.getString('settings_demo_offset') ?? '',
  );

  final container = ProviderContainer(
    overrides: [
      firstRunConsentPromptEnabledProvider.overrideWithValue(
        screen == 'analytics',
      ),
    ],
  );
  await container.read(authRepositoryProvider).restore();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BognerChessApp(),
    ),
  );
  await _settle();

  final router = container.read(routerProvider);
  switch (screen) {
    case 'consent':
      unawaited(router.push<bool>(AppRoutes.consentAi));
    case 'legal':
      router.go(AppRoutes.settings);
      await _settle();
      unawaited(router.push<void>(AppRoutes.legalDocument('privacy')));
    case 'terms':
      router.go(AppRoutes.settings);
      await _settle();
      unawaited(router.push<void>(AppRoutes.legalDocument('terms')));
    case 'account':
      router.go(AppRoutes.settingsAccount);
    case 'delete' || 'delete-typed' || 'delete-run':
      router.go(AppRoutes.settingsAccount);
      await _settle();
      _press(AccountScreen.deleteKey);
      await _settle();
      if (screen != 'delete') {
        final field = _find((e) => e.widget.key == DeleteAccountScreen.fieldKey)
            ?.widget;
        if (field is TextField) {
          field.controller?.text = 'DELETE';
        }
        await _settle();
      }
      if (screen == 'delete-run') {
        _press(DeleteAccountScreen.confirmKey);
      }
    case 'analytics':
      break;
    default:
      router.go(AppRoutes.settings);
  }
  await _settle();

  if (offset != null) {
    final list = _find(
      (e) =>
          e.widget.key ==
          switch (screen) {
            'consent' => AiConsentScreen.scrollKey,
            'legal' || 'terms' => LegalDocumentScreen.scrollKey,
            'delete' ||
            'delete-typed' ||
            'delete-run' => DeleteAccountScreen.scrollKey,
            _ => SettingsScreen.scrollKey,
          },
    );
    final scrollable = list == null
        ? null
        : _find(
            (e) => e is StatefulElement && e.state is ScrollableState,
            under: list,
          );
    if (scrollable is StatefulElement) {
      final position = (scrollable.state as ScrollableState).position;
      position.jumpTo(offset.clamp(0, position.maxScrollExtent));
    }
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(seconds: 1));

/// The same path a finger takes: the button's own callback.
void _press(Key key) {
  final widget = _find((e) => e.widget.key == key)?.widget;
  if (widget is ButtonStyleButton) {
    widget.onPressed?.call();
  }
}

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
