// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/storage/preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Preferences key of [entryAutoQueenProvider].
const String kEntryAutoQueenKey = 'entry.autoQueen';

const _log = Log('entry.settings');

/// "Always promote to queen": opt-in, off by default, kept across launches.
///
/// The value is `false` until the stored one has been read, which takes a
/// moment after the first use. A preferences failure only costs persistence.
final entryAutoQueenProvider = NotifierProvider<EntryAutoQueenNotifier, bool>(
  EntryAutoQueenNotifier.new,
);

class EntryAutoQueenNotifier extends Notifier<bool> {
  bool _changedByUser = false;

  @override
  bool build() {
    unawaited(_load());
    return false;
  }

  Future<void> _load() async {
    try {
      final stored = await ref
          .read(preferencesProvider)
          .getBool(kEntryAutoQueenKey);
      if (stored != null && !_changedByUser && ref.mounted) state = stored;
    } on Object catch (error) {
      _log.warning('could not read $kEntryAutoQueenKey: $error');
    }
  }

  Future<void> set({required bool enabled}) async {
    _changedByUser = true;
    state = enabled;
    try {
      await ref.read(preferencesProvider).setBool(kEntryAutoQueenKey, enabled);
    } on Object catch (error) {
      _log.warning('could not write $kEntryAutoQueenKey: $error');
    }
  }
}
