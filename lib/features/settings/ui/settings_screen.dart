// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/consent/consent_state.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/core/ui/widgets/app_scaffold.dart';
import 'package:bogner_chess/features/entry/domain/entry_settings.dart';
import 'package:bogner_chess/features/legal/domain/legal_documents.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'settings_board.dart';
import 'settings_usage.dart';

/// The "Settings" tab: account, analysis quota, board, entry, privacy, legal
/// texts and the version.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const Key scrollKey = Key('settings-scroll');
  static const Key accountKey = Key('settings-account');
  static const Key autoQueenKey = Key('settings-auto-queen');
  static const Key analyticsKey = Key('settings-analytics');
  static const Key aiConsentKey = Key('settings-ai-consent');
  static const Key privacyPolicyKey = Key('settings-privacy-policy');
  static const Key termsKey = Key('settings-terms');
  static const Key aboutKey = Key('settings-about');

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final GoRouter _router = ref.read(routerProvider);
  String? _lastPath;

  @override
  void initState() {
    super.initState();
    _lastPath = _path;
    _router.routerDelegate.addListener(_onNavigation);
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_onNavigation);
    super.dispose();
  }

  String get _path => _router.routerDelegate.currentConfiguration.uri.path;

  /// The tab stays alive while the user is elsewhere (submitting games, for
  /// one). Coming back to it asks for the numbers again.
  void _onNavigation() {
    final path = _path;
    if (path == AppRoutes.settings && _lastPath != AppRoutes.settings) {
      ref.invalidate(settingsUsageProvider);
    }
    _lastPath = path;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final appInfo = ref.watch(appInfoProvider).value;
    final auth = ref.watch(authStateProvider);
    final autoQueen = ref.watch(entryAutoQueenProvider);
    final analytics = ref.watch(analyticsConsentProvider);

    final (String? name, String? email) = switch (auth) {
      SignedIn(:final name, :final email) => (name, email),
      SignedOut() => (null, null),
    };

    return AppScaffold(
      title: l10n.settingsTitle,
      // Not a lazy list: the screen is short, and a row that exists can be
      // found by a screen reader's rotor and by a test without scrolling.
      body: SingleChildScrollView(
        key: SettingsScreen.scrollKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(l10n.settingsAccount),
            ListTile(
              key: SettingsScreen.accountKey,
              leading: const Icon(Icons.person_outline),
              title: Text(name ?? email ?? l10n.settingsAccountSignedIn),
              subtitle: name != null && email != null ? Text(email) : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(AppRoutes.settingsAccount),
            ),
            const _SectionDivider(),

            _SectionHeader(l10n.settingsSectionAnalyses),
            const SettingsUsage(),
            const _SectionDivider(),

            _SectionHeader(l10n.settingsSectionBoard),
            const SettingsBoard(),
            const _SectionDivider(),

            _SectionHeader(l10n.settingsSectionEntry),
            SwitchListTile(
              key: SettingsScreen.autoQueenKey,
              secondary: const Icon(Icons.keyboard_double_arrow_up),
              title: Text(l10n.entryAutoQueen),
              subtitle: Text(l10n.settingsAutoQueenHint),
              value: autoQueen,
              onChanged: (value) => unawaited(
                ref.read(entryAutoQueenProvider.notifier).set(enabled: value),
              ),
            ),
            const _SectionDivider(),

            _SectionHeader(l10n.settingsSectionPrivacy),
            SwitchListTile(
              key: SettingsScreen.analyticsKey,
              secondary: const Icon(Icons.insights_outlined),
              title: Text(l10n.settingsAnalytics),
              subtitle: Text(l10n.settingsAnalyticsHint),
              value: analytics == AnalyticsConsent.granted,
              onChanged: (value) => unawaited(
                ref.read(analyticsConsentProvider.notifier).set(granted: value),
              ),
            ),
            const _AiConsentTile(),
            const _SectionDivider(),

            _SectionHeader(l10n.settingsLegal),
            ListTile(
              key: SettingsScreen.privacyPolicyKey,
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.legalPrivacyPolicy),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  context.push(AppRoutes.legalDocument(LegalPage.privacy.slug)),
            ),
            ListTile(
              key: SettingsScreen.termsKey,
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.legalTerms),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  context.push(AppRoutes.legalDocument(LegalPage.terms.slug)),
            ),
            ListTile(
              key: SettingsScreen.aboutKey,
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.settingsAbout),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(AppRoutes.settingsAbout),
            ),
            if (appInfo != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  l10n.settingsVersion(appInfo.version, appInfo.buildNumber),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Whether the AI consent is given, with a way to read the text again (and
/// to withdraw on that screen).
class _AiConsentTile extends ConsumerWidget {
  const _AiConsentTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(aiConsentStatusProvider);
    final subtitle = switch (status) {
      AsyncData(:final value) when !value.required =>
        l10n.settingsAiConsentAgreed(
          value.acceptedVersion ?? value.currentVersion,
        ),
      AsyncData(:final value) when value.acceptedVersion != null =>
        l10n.settingsAiConsentNewVersion,
      AsyncData() => l10n.settingsAiConsentNotYet,
      AsyncError() => l10n.settingsAiConsentUnknown,
      _ => l10n.settingsAiConsentLoading,
    };
    return ListTile(
      key: SettingsScreen.aiConsentKey,
      leading: const Icon(Icons.auto_awesome_outlined),
      title: Text(l10n.settingsAiConsent),
      subtitle: Text(subtitle),
      trailing: TextButton(
        onPressed: () async {
          await context.push<bool>(AppRoutes.consentAi);
          // The screen updates the status itself; after a failed load, ask
          // again.
          if (context.mounted && status.hasError) {
            ref.invalidate(aiConsentStatusProvider);
          }
        },
        child: Text(l10n.settingsAiConsentReview),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: AppSpacing.md, indent: 16, endIndent: 16);
}
