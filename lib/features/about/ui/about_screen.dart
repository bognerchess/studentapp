// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/app_info.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/core/ui/widgets/app_scaffold.dart';
import 'package:bogner_chess/features/about/domain/licence_document.dart';
import 'package:bogner_chess/features/about/domain/link_launcher.dart';
import 'package:bogner_chess/features/about/domain/source_link.dart';
import 'package:bogner_chess/features/about/ui/licence_text_screen.dart';
import 'package:bogner_chess/features/about/ui/open_source_licences_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

const _log = Log('about');

/// "About and licences" (PRD PL-1): what the GPL asks a distributed app to
/// make reachable. The source of exactly this build, the licence, the
/// additional permission, the third-party notices and the licences of every
/// package, plus the statement that the app has nothing to do with Lichess.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const Key listKey = ValueKey('about-list');
  static const Key sourceLinkKey = ValueKey('about-source-link');
  static const Key gplKey = ValueKey('about-gpl');
  static const Key appStorePermissionKey = ValueKey('about-permission');
  static const Key noticeKey = ValueKey('about-notice');
  static const Key openSourceLicencesKey = ValueKey('about-oss-licences');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // Null while loading and when the platform does not answer; the link
    // then points at the repository instead of the tag.
    final appInfo = ref.watch(appInfoProvider).value;
    final sourceUrl = sourceUrlFor(appInfo);

    return AppScaffold(
      title: l10n.aboutTitle,
      body: ListView(
        key: listKey,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.appTitle, style: theme.textTheme.headlineSmall),
                if (appInfo != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.settingsVersion(appInfo.version, appInfo.buildNumber),
                    style: muted,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(l10n.aboutDescription, style: theme.textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.aboutNotAffiliated, style: muted),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            key: sourceLinkKey,
            leading: const Icon(Icons.code),
            title: Text(l10n.aboutSourceForBuild),
            subtitle: Text(sourceUrl.toString()),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _open(context, ref, sourceUrl),
          ),
          ListTile(
            key: gplKey,
            leading: const Icon(Icons.gavel_outlined),
            title: Text(l10n.aboutGplLicence),
            subtitle: Text(l10n.aboutGplLicenceHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(
              context,
              LicenceTextScreen(
                title: l10n.aboutGplLicence,
                document: LicenceDocument.gpl,
              ),
            ),
          ),
          ListTile(
            key: appStorePermissionKey,
            leading: const Icon(Icons.storefront_outlined),
            title: Text(l10n.aboutAppStorePermission),
            subtitle: Text(l10n.aboutAppStorePermissionDraft),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(
              context,
              LicenceTextScreen(
                title: l10n.aboutAppStorePermission,
                document: LicenceDocument.appStorePermission,
                // TODO(H7): remove together with the DRAFT notice in
                // LICENSE-APP-STORE-PERMISSION.md, and drop the subtitle
                // above, once the final wording is published.
                warning: l10n.aboutAppStorePermissionDraftBanner,
              ),
            ),
          ),
          ListTile(
            key: noticeKey,
            leading: const Icon(Icons.extension_outlined),
            title: Text(l10n.aboutThirdPartyNotices),
            subtitle: Text(l10n.aboutThirdPartyNoticesHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(
              context,
              LicenceTextScreen(
                title: l10n.aboutThirdPartyNotices,
                document: LicenceDocument.notice,
              ),
            ),
          ),
          ListTile(
            key: openSourceLicencesKey,
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(l10n.aboutOpenSourceLicences),
            subtitle: Text(l10n.aboutOpenSourceLicencesHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const OpenSourceLicencesScreen()),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Text(
              l10n.aboutFreeSoftwareNotice,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The text screens are leaves of this screen, not locations of their own:
  /// nothing links to them from outside, so they are pushed on the settings
  /// tab's navigator (the tab bar stays, swipe-back works) and `router.dart`
  /// does not grow.
  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (context) => screen));
  }

  static Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    Uri uri,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.aboutLinkFailed;
    var opened = false;
    try {
      opened = await ref.read(linkLauncherProvider)(uri);
    } on Exception catch (error, stack) {
      _log.warning('could not open $uri', error: error, stackTrace: stack);
    }
    if (!opened) {
      // The address stays readable in the row, so it can still be typed.
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }
}
