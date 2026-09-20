// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/links/link_launcher.dart';
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/core/ui/widgets/empty_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/update_required.dart';

/// Replaces the whole app with "Please update" when the backend no longer
/// supports this version. Sits in `MaterialApp.builder`, above the navigator,
/// so no route, link or notification gets past it.
///
/// Nothing on the device is touched: drafts are still there after the update.
class UpdateRequiredGate extends ConsumerStatefulWidget {
  const UpdateRequiredGate({super.key, required this.child});

  final Widget child;

  static const Key updateKey = Key('update-required-open-store');

  @override
  ConsumerState<UpdateRequiredGate> createState() => _UpdateRequiredGateState();
}

class _UpdateRequiredGateState extends ConsumerState<UpdateRequiredGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // A start without a network is not checked (fail open); coming back to
  // the app is the next chance. (Not an AppLifecycleListener: that one
  // asserts on the order of states, which tests do not keep.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(updateRequiredProvider).value != true) {
      ref.invalidate(updateRequiredProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final required = ref.watch(updateRequiredProvider).value ?? false;
    if (!required) {
      return widget.child;
    }
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: CenteredMessage(
          children: [
            Icon(
              Icons.system_update,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              header: true,
              child: Text(
                l10n.updateRequiredTitle,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.updateRequiredMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: UpdateRequiredGate.updateKey,
              onPressed: () => unawaited(
                ref
                    .read(linkLauncherProvider)(Uri.parse(kAppStoreUrl))
                    .catchError((Object _) => false),
              ),
              child: Text(l10n.updateRequiredAction),
            ),
          ],
        ),
      ),
    );
  }
}
