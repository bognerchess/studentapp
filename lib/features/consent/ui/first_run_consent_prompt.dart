// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/config/env.dart';
import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/consent/consent_state.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/features/legal/domain/legal_documents.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'analytics_consent_sheet.dart';

/// Off in tests that pump the whole app for other reasons (a sheet over the
/// first screen would be in their way): `pumpApp` overrides it with false.
final firstRunConsentPromptEnabledProvider = Provider<bool>((ref) => true);

/// Opens the analytics question once per account and device, on the first
/// start with somebody signed in. Sits in `MaterialApp.builder`.
///
/// It only opens over one of the three tabs: never over the sign-in screen, a
/// board or another dialog. When the app starts somewhere else (a push tap, a
/// shared PGN), the question waits for the next start.
class FirstRunConsentPrompt extends ConsumerStatefulWidget {
  const FirstRunConsentPrompt({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FirstRunConsentPrompt> createState() =>
      _FirstRunConsentPromptState();
}

class _FirstRunConsentPromptState extends ConsumerState<FirstRunConsentPrompt> {
  static const Set<String> _calmLocations = {
    AppRoutes.games,
    AppRoutes.newGame,
    AppRoutes.settings,
  };

  bool _checking = false;

  /// The account that has had its answer (shown, or not due) this session.
  String? _settledSub;
  late final GoRouter _router = ref.read(routerProvider);

  @override
  void initState() {
    super.initState();
    // Until the question is settled, every navigation is another chance: a
    // start on a deep link reaches a tab sooner or later.
    _router.routerDelegate.addListener(_schedule);
    // A sign-in (also the first one after a sign-out) asks the new account.
    try {
      ref.listenManual(authStateProvider, (previous, next) {
        if (next is SignedIn && previous is! SignedIn) _schedule();
      }, onError: (_, _) {});
    } on Object catch (_) {
      // An auth layer that cannot even start has nobody to ask.
    }
    _schedule();
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_schedule);
    super.dispose();
  }

  void _schedule() {
    if (_checking || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    if (!ref.read(firstRunConsentPromptEnabledProvider)) return;
    _checking = true;
    try {
      final auth = ref.read(authStateProvider);
      if (auth is! SignedIn || auth.sub == _settledSub) return;
      final notifier = ref.read(analyticsConsentProvider.notifier);
      await notifier.loaded;
      if (!mounted || !_isCalm()) return;
      _settledSub = auth.sub;
      if (!await notifier.takeFirstRunPrompt()) return;

      // The backend's wording, when it can be had quickly; the app's own
      // otherwise. A draft is not shown to real users.
      LegalDocument? document;
      try {
        final language = mounted
            ? Localizations.maybeLocaleOf(
                rootNavigatorKey.currentContext ?? context,
              )?.languageCode
            : null;
        document = await ref
            .read(legalApiProvider)
            .document(
              LegalDocumentKey.analyticsConsent,
              language: language ?? 'en',
            )
            .timeout(const Duration(seconds: 3));
        if (document != null &&
            document.isDraft &&
            ref.read(envProvider).isProd) {
          document = null;
        }
      } on Object catch (_) {
        document = null;
      }

      final navigatorContext = rootNavigatorKey.currentContext;
      if (!mounted || navigatorContext == null || !navigatorContext.mounted) {
        return;
      }
      if (!_isCalm()) return;
      await showAnalyticsConsentSheet(navigatorContext, document: document);
    } on Object catch (error) {
      // A question that cannot be asked is not worth a crash: the switch in
      // the settings is still there.
      const Log('consent').warning('first-run prompt failed: $error');
    } finally {
      _checking = false;
    }
  }

  bool _isCalm() {
    final path = _router.routerDelegate.currentConfiguration.uri.path;
    return _calmLocations.contains(path);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
