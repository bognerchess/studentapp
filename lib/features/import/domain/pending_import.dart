// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// PGN text that arrived from outside the app ("Open in Bogner Chess", the
/// share extension) and waits for the import screen.
///
/// The sender calls `offer` and then navigates to the import route. The
/// screen takes the text when it opens, and also while it is already open, so
/// a second file replaces the first. `take` empties the slot: the text is
/// shown once and does not come back when the screen is opened by hand later.
final pendingImportProvider = NotifierProvider<PendingImport, String?>(
  PendingImport.new,
);

class PendingImport extends Notifier<String?> {
  @override
  String? build() => null;

  // ignore: use_setters_to_change_properties
  void offer(String pgnText) => state = pgnText;

  String? take() {
    final text = state;
    if (text != null) state = null;
    return text;
  }
}
