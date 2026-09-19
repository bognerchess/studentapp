// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/widgets/placeholder_screen.dart';
import 'package:material_ui/material_ui.dart';

/// Placeholder. WP-29a replaces this file.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key, required this.gameId});

  /// The server id of the game, from the route `/games/:id/review`.
  final String gameId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(title: context.l10n.reviewTitle, detail: gameId);
  }
}
