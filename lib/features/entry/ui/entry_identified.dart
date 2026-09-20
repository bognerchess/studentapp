// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/widgets.dart';

/// Semantics identifiers of the entry screen's controls
/// (`accessibilityIdentifier` on iOS), for UI automation and tests. Squares
/// are `board-square-e4`, moves in the list `entry-move-<ply>`.
abstract final class EntryIds {
  static const String autoQueen = 'entry-auto-queen';
  static const String done = 'entry-done';
  static const String flip = 'entry-flip';
  static const String menu = 'entry-menu';
  static const String overwriteCancel = 'entry-overwrite-cancel';
  static const String overwriteConfirm = 'entry-overwrite-confirm';
  static const String redo = 'entry-redo';
  static const String status = 'entry-status';
  static const String undo = 'entry-undo';
}

/// One semantics node with an identifier around a control, in the way
/// `BoardView` labels its squares: automation finds `entry-undo`, a screen
/// reader hears [label], and both activate [onTap].
class EntryIdentified extends StatelessWidget {
  const EntryIdentified({
    super.key,
    required this.identifier,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String identifier;
  final String label;

  /// Null marks the control as disabled.
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      excludeSemantics: true,
      identifier: identifier,
      label: label,
      button: true,
      enabled: onTap != null,
      onTap: onTap,
      child: child,
    );
  }
}
