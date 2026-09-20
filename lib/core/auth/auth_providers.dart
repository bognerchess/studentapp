// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/auth/app_auth_oidc_client.dart';
import 'package:bogner_chess/core/auth/app_auth_repository.dart';
import 'package:bogner_chess/core/auth/auth_repository.dart';
import 'package:bogner_chess/core/auth/fake_auth_repository.dart';
import 'package:bogner_chess/core/auth/install_marker.dart';
import 'package:bogner_chess/core/auth/oidc_client.dart';
import 'package:bogner_chess/core/auth/sign_out_hooks.dart';
import 'package:bogner_chess/core/auth/token_store.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/storage/preferences.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _log = Log('auth');

/// The Keychain in the app, overridden with `InMemoryTokenStore` in tests.
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// `flutter_appauth` in the app, overridden with a fake in tests.
final oidcClientProvider = Provider<OidcClient>((ref) {
  final env = ref.watch(envProvider);
  return AppAuthOidcClient(
    issuer: env.oidcIssuer,
    clientId: env.oidcClientId,
    redirectUrl: env.oidcRedirect,
  );
});

final installMarkerProvider = Provider<InstallMarker>(
  (ref) => PreferencesInstallMarker(() => ref.read(preferencesProvider)),
);

/// The one [AuthRepository] of the app: fake with `AUTH_MODE=fake`, real
/// otherwise. `main.dart` awaits its `restore()` before the first frame.
///
/// An explicit sign-out removes the user's cached games, analyses, jobs and
/// settings from the local database and keeps the drafts.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final env = ref.watch(envProvider);

  Future<void> wipeOwner(String sub) async {
    await ref.read(appDatabaseProvider).wipeOwner(sub, keepDrafts: true);
    _log.info('local data of the signed-out user removed, drafts kept');
  }

  // Read at sign-out time: push and analytics add their hooks after this
  // provider was built (see sign_out_hooks.dart).
  Future<void> beforeSignOut(String sub) =>
      ref.read(beforeSignOutHooksProvider).run(sub);

  if (env.usesFakeAuth) {
    // Env.fromEnvironment already refuses this in a release build. Checked
    // again here, because an Env can also be constructed directly.
    if (kReleaseMode || env.isProd) {
      throw StateError('AUTH_MODE=fake is not allowed for ${env.envName}');
    }
    final repository = FakeAuthRepository(
      onSignedOut: wipeOwner,
      onBeforeSignOut: beforeSignOut,
    );
    ref.onDispose(repository.dispose);
    return repository;
  }

  final repository = AppAuthRepository(
    oidc: ref.watch(oidcClientProvider),
    store: ref.watch(tokenStoreProvider),
    installMarker: ref.watch(installMarkerProvider),
    onSignedOut: wipeOwner,
    onBeforeSignOut: beforeSignOut,
  );
  ref.onDispose(repository.dispose);
  return repository;
});
