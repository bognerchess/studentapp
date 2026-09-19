// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/features/entry/data/screen_wakelock.dart';
import 'package:bogner_chess/features/entry/domain/entry_draft_store.dart';

/// A draft store that records every call.
class RecordingDraftStore implements EntryDraftStore {
  RecordingDraftStore([Iterable<EntryDraftSnapshot> initial = const []]) {
    for (final snapshot in initial) {
      drafts[snapshot.id] = snapshot;
    }
  }

  final Map<String, EntryDraftSnapshot> drafts = {};
  final List<EntryDraftSnapshot> saves = [];
  final List<String> loads = [];
  final List<String> deletes = [];

  /// When set, the next saves fail with it.
  Object? saveError;

  @override
  Future<EntryDraftSnapshot?> load(String draftId) async {
    loads.add(draftId);
    return drafts[draftId];
  }

  @override
  Future<void> save(EntryDraftSnapshot snapshot) async {
    final error = saveError;
    // ignore: only_throw_errors
    if (error != null) throw error;
    saves.add(snapshot);
    drafts[snapshot.id] = snapshot;
  }

  @override
  Future<void> delete(String draftId) async {
    deletes.add(draftId);
    drafts.remove(draftId);
  }
}

class FakeWakelock implements ScreenWakelock {
  final List<String> calls = [];

  bool get isOn => calls.isNotEmpty && calls.last == 'enable';

  @override
  Future<void> enable() async => calls.add('enable');

  @override
  Future<void> disable() async => calls.add('disable');
}
