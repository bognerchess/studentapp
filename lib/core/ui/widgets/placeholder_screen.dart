// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/widgets/app_scaffold.dart';
import 'package:bogner_chess/core/ui/widgets/empty_state.dart';
import 'package:material_ui/material_ui.dart';

/// Stands in for a screen that a later work package builds. [detail] shows
/// route parameters, which makes deep links checkable in a screenshot.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final message = context.l10n.commonPlaceholderMessage;
    return AppScaffold(
      title: title,
      body: EmptyState(
        icon: Icons.construction,
        title: title,
        message: detail == null ? message : '$message\n$detail',
      ),
    );
  }
}
