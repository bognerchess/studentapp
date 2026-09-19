// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the entry screen needs to come back to a game exactly as it was.
class EntryDraftSnapshot {
  const EntryDraftSnapshot({
    required this.id,
    required this.pgnMoves,
    required this.cursorPly,
    required this.orientation,
    required this.updatedAt,
  });

  /// The draft's id, a UUID (the `drafts.id` column once WP-27 is in).
  final String id;

  /// Movetext without headers and result: `1. e4 e5 2. Nf3`.
  final String pgnMoves;

  /// The ply the board showed. Inside the line when the user was correcting.
  final int cursorPly;

  /// The side at the bottom of the board.
  final Side orientation;

  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is EntryDraftSnapshot &&
      other.id == id &&
      other.pgnMoves == pgnMoves &&
      other.cursorPly == cursorPly &&
      other.orientation == orientation &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, pgnMoves, cursorPly, orientation, updatedAt);

  @override
  String toString() =>
      'EntryDraftSnapshot($id, ply $cursorPly, ${orientation.name}, '
      '${pgnMoves.length} chars)';
}

/// Where the entry screen keeps its drafts. Deliberately tiny: WP-27 puts the
/// drift DAO behind it by overriding [entryDraftStoreProvider].
abstract interface class EntryDraftStore {
  /// The snapshot saved under [draftId], or null when there is none.
  Future<EntryDraftSnapshot?> load(String draftId);

  /// Creates or replaces the snapshot with `snapshot.id`.
  Future<void> save(EntryDraftSnapshot snapshot);

  /// Forgets the draft. Unknown ids are not an error.
  Future<void> delete(String draftId);
}

/// Keeps drafts for the lifetime of the process. The default until the
/// database is wired in, and good enough for tests.
class InMemoryEntryDraftStore implements EntryDraftStore {
  final Map<String, EntryDraftSnapshot> _drafts = {};

  /// Everything that is stored, for tests and debugging.
  Map<String, EntryDraftSnapshot> get drafts => Map.unmodifiable(_drafts);

  @override
  Future<EntryDraftSnapshot?> load(String draftId) async => _drafts[draftId];

  @override
  Future<void> save(EntryDraftSnapshot snapshot) async =>
      _drafts[snapshot.id] = snapshot;

  @override
  Future<void> delete(String draftId) async => _drafts.remove(draftId);
}

/// The draft store of the app. One instance, so that a draft survives leaving
/// and reopening the entry screen.
final entryDraftStoreProvider = Provider<EntryDraftStore>(
  (ref) => InMemoryEntryDraftStore(),
);

/// Saves the newest snapshot a short moment after it was scheduled, so that a
/// burst of plies costs one write, and at once on [flush].
///
/// A failing store never breaks move entry: the error goes to [onError] and
/// the next ply tries again.
class EntryAutosaver {
  EntryAutosaver(
    this._store, {
    this.debounce = const Duration(milliseconds: 250),
    this.onError,
  }) : assert(
         debounce <= const Duration(milliseconds: 300),
         'the product promise is that at most 300 ms of entry can be lost',
       );

  final EntryDraftStore _store;
  final Duration debounce;
  final void Function(Object error, StackTrace stackTrace)? onError;

  Timer? _timer;
  EntryDraftSnapshot? _pending;
  Future<void> _writing = Future.value();

  /// Whether a snapshot is waiting for its write.
  bool get hasPending => _pending != null;

  /// Replaces whatever was waiting and restarts the debounce.
  void schedule(EntryDraftSnapshot snapshot) {
    _pending = snapshot;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  /// Writes the waiting snapshot now. Completes when the store has it (or has
  /// failed). Call it when the app is paused and when the screen closes.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    final snapshot = _pending;
    if (snapshot == null) return _writing;
    _pending = null;
    // Writes are chained, so that an older snapshot can never land last.
    return _writing = _writing.then((_) async {
      try {
        await _store.save(snapshot);
      } on Object catch (error, stackTrace) {
        onError?.call(error, stackTrace);
      }
    });
  }

  /// Flushes and stops the timer. The autosaver can still be used afterwards;
  /// there is nothing to release.
  Future<void> dispose() => flush();
}

/// A random (version 4) UUID for a new draft, matching the `drafts.id` column.
String newEntryDraftId([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')];
  return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
      '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
      '${hex.sublist(10).join()}';
}
