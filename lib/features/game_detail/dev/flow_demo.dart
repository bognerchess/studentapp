// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

// Development entry point: the real app against the mock server, driven by a
// script from the launch arguments, for end-to-end checks and screenshots on
// a simulator that nothing can tap. Never part of a release; `lib/main.dart`
// does not import it.
//
//   dart run tool/mock_server/main.dart --port 5299 --job-seconds 6 --ai-consent
//   flutter build ios --simulator --debug \
//     --dart-define-from-file=config/fake.json \
//     -t lib/features/game_detail/dev/flow_demo.dart
//   xcrun simctl launch <udid> com.bognerchess.mobile \
//     -AppleLanguages "(de)" -flow_demo "game:game-3,request,wait:8,open"
//
// `-flow_demo` is a comma-separated list of steps, one second apart:
//
//   game:<id>     open the game screen of <id>
//   review:<id>   open the review of <id>
//   request       press "Analyse this game" on the open game screen (the
//                 real flow, sheets included)
//   open          press "Open analysis" on the open game screen
//   search:<text> type into the library's search field
//   refresh       pull to refresh the library
//   back          pop the top route
//   wait:<n>      wait n more seconds
//
// Launch arguments of the form `-key value` end up in NSUserDefaults, which
// is where shared_preferences reads from.

import 'dart:async';

import 'package:bogner_chess/app.dart';
import 'package:bogner_chess/core/auth/auth_providers.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/features/game_detail/domain/game_detail_controller.dart';
import 'package:bogner_chess/features/game_detail/ui/analysis_request_flow.dart';
import 'package:bogner_chess/features/library/domain/library_controller.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _log = Log('flow-demo');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final script = await SharedPreferencesAsync().getString('flow_demo') ?? '';

  final container = ProviderContainer();
  await container.read(authRepositoryProvider).restore();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BognerChessApp(),
    ),
  );

  final router = container.read(routerProvider);
  String? openGame;
  for (final step in script.split(',').where((s) => s.trim().isNotEmpty)) {
    await Future<void>.delayed(const Duration(seconds: 1));
    final [name, ...rest] = step.trim().split(':');
    final argument = rest.join(':');
    _log.info('step $name');
    switch (name) {
      case 'game':
        openGame = argument;
        unawaited(router.push(AppRoutes.game(argument)));
      case 'review':
        unawaited(router.push(AppRoutes.gameReview(argument)));
      case 'request' when openGame != null:
        _request(container, openGame);
      case 'open' when openGame != null:
        unawaited(router.push(AppRoutes.gameReview(openGame)));
      case 'search':
        container
            .read(libraryControllerProvider.notifier)
            .setSearchText(argument);
      case 'refresh':
        unawaited(container.read(libraryControllerProvider.notifier).refresh());
      case 'back':
        router.pop();
      case 'wait':
        await Future<void>.delayed(
          Duration(seconds: int.tryParse(argument) ?? 1),
        );
      default:
        _log.warning('unknown or impossible step "$step"');
    }
  }
}

void _request(ProviderContainer container, String gameId) {
  // Below the root navigator, as the button's own context is.
  final context = rootNavigatorKey.currentState!.overlay!.context;
  // Keep the controller alive for the duration of the request.
  final subscription = container.listen(
    gameDetailControllerProvider(gameId),
    (_, _) {},
  );
  unawaited(
    runAnalysisRequest(
      context,
      container.read(gameDetailControllerProvider(gameId).notifier),
    ).whenComplete(subscription.close),
  );
}
