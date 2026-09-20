// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/widgets/app_scaffold.dart';
import 'package:bogner_chess/core/ui/widgets/empty_state.dart';
import 'package:material_ui/material_ui.dart';

/// The router's error screen: a link led to a route that does not exist.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.onGoHome});

  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      title: l10n.notFoundTitle,
      body: EmptyState(
        icon: Icons.link_off,
        title: l10n.notFoundTitle,
        message: l10n.notFoundMessage,
        actionLabel: l10n.notFoundAction,
        onAction: onGoHome,
      ),
    );
  }
}
