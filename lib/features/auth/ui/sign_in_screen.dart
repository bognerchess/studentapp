// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/ui/widgets/placeholder_screen.dart';
import 'package:material_ui/material_ui.dart';

/// Placeholder. WP-25 replaces this file.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(title: context.l10n.signInTitle);
  }
}
