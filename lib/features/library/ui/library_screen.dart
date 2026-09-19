// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/widgets/app_scaffold.dart';
import 'package:bogner_chess/core/ui/widgets/empty_state.dart';
import 'package:bogner_chess/router.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Placeholder for the games library: shows the empty state only. WP-26
/// replaces this file.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      title: l10n.libraryTitle,
      body: EmptyState(
        icon: Icons.library_books_outlined,
        title: l10n.libraryEmptyTitle,
        message: l10n.libraryEmptyMessage,
        actionLabel: l10n.libraryEmptyAction,
        onAction: () => context.go(AppRoutes.newGame),
      ),
    );
  }
}
