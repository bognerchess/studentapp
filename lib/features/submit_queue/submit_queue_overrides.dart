// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/features/entry/domain/entry_draft_store.dart';
import 'package:bogner_chess/features/submit_queue/data/drift_entry_draft_store.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// What `main.dart` (and every test of the real flow) puts into the root
/// `ProviderContainer`: the entry screen's drafts live in the database.
///
/// An override rather than a new default, because `features/entry` must not
/// import this feature's `data/` (layer check), and because the entry
/// feature's own tests and demo are happier with the in-memory store.
final List<Override> submitQueueOverrides = [
  entryDraftStoreProvider.overrideWith(DriftEntryDraftStore.of),
];
