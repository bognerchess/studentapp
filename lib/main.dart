// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/material.dart';

void main() {
  runApp(const BognerChessApp());
}

/// Root widget. WP-03 replaces this with the real shell (Riverpod, go_router,
/// theme, l10n); until then it only proves that the toolchain builds and runs.
class BognerChessApp extends StatelessWidget {
  const BognerChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bogner Chess',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E5E4E)),
      ),
      home: const PlaceholderHomeScreen(),
    );
  }
}

/// Placeholder home screen for the scaffold.
class PlaceholderHomeScreen extends StatelessWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Bogner Chess',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
