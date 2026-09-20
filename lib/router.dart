// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/links/link_target.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/ui/widgets/not_found_screen.dart';
import 'package:bogner_chess/core/ui/widgets/tab_shell.dart';
import 'package:bogner_chess/features/about/ui/about_screen.dart';
import 'package:bogner_chess/features/account/ui/account_screen.dart';
import 'package:bogner_chess/features/auth/ui/sign_in_screen.dart';
import 'package:bogner_chess/features/consent/ui/ai_consent_screen.dart';
import 'package:bogner_chess/features/entry/ui/entry_screen.dart';
import 'package:bogner_chess/features/import/ui/import_screen.dart';
import 'package:bogner_chess/features/legal/domain/legal_documents.dart';
import 'package:bogner_chess/features/legal/ui/legal_document_screen.dart';
import 'package:bogner_chess/features/legal/ui/legal_screen.dart';
import 'package:bogner_chess/features/library/ui/game_screen.dart';
import 'package:bogner_chess/features/library/ui/library_screen.dart';
import 'package:bogner_chess/features/metadata/ui/metadata_screen.dart';
import 'package:bogner_chess/features/new_game/ui/new_game_screen.dart';
import 'package:bogner_chess/features/review/ui/review_screen.dart';
import 'package:bogner_chess/features/settings/ui/settings_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

// This file is edited by many branches at once. To keep them mergeable:
// one constant per line and one route per block, every section in
// alphabetical order, append instead of rearranging.

/// Every location in the app. Navigate with these, never with literals:
/// `context.go(AppRoutes.gameReview(id))`.
abstract final class AppRoutes {
  // Alphabetical.
  static const String consentAi = '/consent/ai';
  static const String games = '/games';
  static const String newGame = '/new';
  static const String newGameEntry = '/new/entry';
  static const String newGameImport = '/new/import';
  static const String newGameMetadata = '/new/metadata';
  static const String settings = '/settings';
  static const String settingsAbout = '/settings/about';
  static const String settingsAccount = '/settings/account';
  static const String settingsLegal = '/settings/legal';
  static const String signIn = '/sign-in';

  // Locations with parameters, alphabetical.
  static String game(String id) => '/games/${Uri.encodeComponent(id)}';
  static String gameReview(String id) => '${game(id)}/review';
  static String legalDocument(String slug) =>
      '/legal/${Uri.encodeComponent(slug)}';

  /// The location a fresh start opens.
  static const String initial = games;

  /// Query parameter of [signIn]: where to go once signed in.
  static const String fromParam = 'from';

  /// Path parameter of [game] and [gameReview].
  static const String gameIdParam = 'id';

  /// Query parameter of [newGameEntry]: the draft to resume.
  static const String draftIdParam = 'draftId';

  /// Path parameter of [legalDocument]: a `LegalPage.slug`.
  static const String legalDocParam = 'doc';

  /// [newGameEntry], resuming the draft with [draftId].
  static String newGameEntryResume(String draftId) => Uri(
    path: newGameEntry,
    queryParameters: {draftIdParam: draftId},
  ).toString();
}

/// Route names, for `context.goNamed` and for analytics screen names.
abstract final class AppRouteNames {
  // Alphabetical.
  static const String consentAi = 'consent-ai';
  static const String game = 'game';
  static const String gameReview = 'game-review';
  static const String games = 'games';
  static const String legalDocument = 'legal-document';
  static const String newGame = 'new-game';
  static const String newGameEntry = 'new-game-entry';
  static const String newGameImport = 'new-game-import';
  static const String newGameMetadata = 'new-game-metadata';
  static const String settings = 'settings';
  static const String settingsAbout = 'settings-about';
  static const String settingsAccount = 'settings-account';
  static const String settingsLegal = 'settings-legal';
  static const String signIn = 'sign-in';
}

/// Locations a signed-out user may see. Everything else redirects to
/// [AppRoutes.signIn]. Alphabetical.
const Set<String> _publicLocations = {
  AppRoutes.signIn, //
};

/// The navigator that covers the whole screen, tab bar included. Routes with
/// `parentNavigatorKey: rootNavigatorKey` open above the tabs.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

const _log = Log('router');

/// Decides where a navigation really ends, given who is signed in. Pure, so
/// that it can be tested without widgets. Returns null to let it pass.
String? authRedirect({required AuthState auth, required Uri uri}) {
  final isPublic = _publicLocations.contains(uri.path);
  switch (auth) {
    case SignedOut():
      if (isPublic) {
        return null;
      }
      // Remember the target, so that a push tap or a shared link still
      // arrives after signing in.
      return Uri(
        path: AppRoutes.signIn,
        queryParameters: {AppRoutes.fromParam: uri.toString()},
      ).toString();
    case SignedIn():
      if (uri.path != AppRoutes.signIn) {
        return null;
      }
      final from = uri.queryParameters[AppRoutes.fromParam];
      // Only in-app locations: never follow an absolute URL from a link.
      final isInApp =
          from != null && from.startsWith('/') && !from.startsWith('//');
      return isInApp ? from : AppRoutes.initial;
  }
}

/// Where a URI with a scheme leads: the location from the mapping table in
/// `core/links/link_target.dart`; the start location for the OIDC redirect,
/// which is not a place; null (the not-found screen) for everything else.
String? externalLinkRedirect(Uri uri) {
  return switch (classifyUri(uri)) {
    AppLocationTarget(:final location) => location,
    IgnoredTarget(reason: IgnoredLinkReason.oauthRedirect) => AppRoutes.initial,
    _ => null,
  };
}

/// The app's router. It re-evaluates its redirect whenever the auth state
/// changes.
final routerProvider = Provider<GoRouter>((ref) {
  final authChanged = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, _) => authChanged.value++);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.initial,
    refreshListenable: authChanged,
    redirect: (context, state) {
      // A URI with a scheme is a link from outside that reached the router
      // directly. Normally IncomingLinkService normalises those first (and
      // Flutter's own deep linking is off in Info.plist); this is the net
      // below it. The result passes through this redirect again, so the
      // auth rules apply to it as to any location.
      if (state.uri.hasScheme) {
        return externalLinkRedirect(state.uri);
      }
      final target = authRedirect(
        auth: ref.read(authStateProvider),
        uri: state.uri,
      );
      if (target != null) {
        _log.debug('redirect ${state.uri.path} -> ${Uri.parse(target).path}');
      }
      return target;
    },
    errorBuilder: (context, state) =>
        NotFoundScreen(onGoHome: () => context.go(AppRoutes.initial)),
    routes: [
      // ---- Root routes: full screen, no tab bar. Alphabetical by path. ----
      GoRoute(path: '/', redirect: (context, state) => AppRoutes.initial),
      GoRoute(
        path: AppRoutes.consentAi,
        name: AppRouteNames.consentAi,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: const AiConsentScreen(),
        ),
      ),
      GoRoute(
        // Full screen, so that it can open above a sheet or the consent
        // screen as well as from the settings: `context.push(...)`.
        path: '/legal/:${AppRoutes.legalDocParam}',
        name: AppRouteNames.legalDocument,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final page = LegalPage.ofSlug(
            state.pathParameters[AppRoutes.legalDocParam],
          );
          return page == null
              ? NotFoundScreen(onGoHome: () => context.go(AppRoutes.initial))
              : LegalDocumentScreen(page: page);
        },
      ),
      GoRoute(
        path: AppRoutes.signIn,
        name: AppRouteNames.signIn,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SignInScreen(),
      ),

      // ---- The tab shell. Branch order is the tab order (see TabShell). ----
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            TabShell(navigationShell: navigationShell),
        branches: [
          // ---- Tab 1: Games. Sub-routes alphabetical by path. ----
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.games,
                name: AppRouteNames.games,
                builder: (context, state) => const LibraryScreen(),
                routes: [
                  GoRoute(
                    path: ':${AppRoutes.gameIdParam}',
                    name: AppRouteNames.game,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => GameScreen(
                      gameId: state.pathParameters[AppRoutes.gameIdParam]!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'review',
                        name: AppRouteNames.gameReview,
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => ReviewScreen(
                          gameId: state.pathParameters[AppRoutes.gameIdParam]!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // ---- Tab 2: New game. Sub-routes alphabetical by path. ----
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.newGame,
                name: AppRouteNames.newGame,
                builder: (context, state) => const NewGameScreen(),
                routes: [
                  GoRoute(
                    path: 'entry',
                    name: AppRouteNames.newGameEntry,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => EntryScreen(
                      draftId:
                          state.uri.queryParameters[AppRoutes.draftIdParam],
                    ),
                  ),
                  GoRoute(
                    path: 'import',
                    name: AppRouteNames.newGameImport,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const ImportScreen(),
                  ),
                  GoRoute(
                    path: 'metadata',
                    name: AppRouteNames.newGameMetadata,
                    parentNavigatorKey: rootNavigatorKey,
                    // Push it with `extra: MetadataScreenArgs(...)` and await
                    // the GameMetadata it pops with. A cold deep link has no
                    // extra and gets the empty form.
                    builder: (context, state) => MetadataScreen(
                      args: switch (state.extra) {
                        final MetadataScreenArgs args => args,
                        _ => const MetadataScreenArgs(),
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ---- Tab 3: Settings. Sub-routes alphabetical by path; they ----
          // ---- stay inside the tab, so the tab bar remains visible.    ----
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                name: AppRouteNames.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'about',
                    name: AppRouteNames.settingsAbout,
                    builder: (context, state) => const AboutScreen(),
                  ),
                  GoRoute(
                    path: 'account',
                    name: AppRouteNames.settingsAccount,
                    builder: (context, state) => const AccountScreen(),
                  ),
                  GoRoute(
                    path: 'legal',
                    name: AppRouteNames.settingsLegal,
                    builder: (context, state) => const LegalScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    authChanged.dispose();
  });
  return router;
});
