// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:bogner_chess/features/entry/domain/entry_draft_store.dart';
import 'package:bogner_chess/features/submit_queue/domain/draft_meta.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The entry screen's drafts in the `drafts` table, owned by the signed-in
/// user.
///
/// The entry screen owns the moves (`pgn`) and, inside `meta_json`, the
/// cursor and the orientation. Everything else in the row belongs to the
/// submit flow and is left alone: [save] merges into the metadata instead of
/// replacing it, and only writes while the draft is `editing`.
class DriftEntryDraftStore implements EntryDraftStore {
  DriftEntryDraftStore({required this._database, required this._owner});

  DriftEntryDraftStore.of(Ref ref)
    : this(
        database: () => ref.read(appDatabaseProvider),
        owner: () => switch (ref.read(authStateProvider)) {
          SignedIn(:final sub) => sub,
          SignedOut() => null,
        },
      );

  static const _log = Log('entry-drafts');

  final AppDatabase Function() _database;
  final String? Function() _owner;

  /// Resuming also brings a draft back that was finished but not sent yet
  /// (`ready` or `failed`): the user opened it to change it. One that is
  /// being sent or was sent is not resumable; the screen then starts empty.
  @override
  Future<EntryDraftSnapshot?> load(String draftId) async {
    final owner = _owner();
    if (owner == null) return null;
    final dao = _database().draftsDao;
    var draft = await dao.get(owner, draftId);
    if (draft == null) return null;
    if (draft.state == DraftState.ready || draft.state == DraftState.failed) {
      if (!await dao.reopen(owner, draftId)) return null;
      draft = await dao.get(owner, draftId);
      if (draft == null) return null;
    }
    if (draft.state != DraftState.editing) return null;
    final meta = DraftMeta.decode(draft.metaJson);
    return EntryDraftSnapshot(
      id: draft.id,
      pgnMoves: draft.pgn,
      // Past the end: the entry game clamps it to the last move.
      cursorPly: meta.cursorPly ?? 1 << 20,
      orientation: meta.orientation ?? Side.white,
      updatedAt: draft.updatedAt,
    );
  }

  @override
  Future<void> save(EntryDraftSnapshot snapshot) async {
    final owner = _owner();
    if (owner == null) {
      // Cannot happen inside the shell; the router shows the sign-in screen.
      _log.warning('not signed in, draft not saved');
      return;
    }
    final db = _database();
    final dao = db.draftsDao;
    await db.transaction(() async {
      final draft = await dao.get(owner, snapshot.id);
      if (draft == null) {
        await dao.create(
          owner,
          id: snapshot.id,
          pgn: snapshot.pgnMoves,
          metaJson: DraftMeta(
            cursorPly: snapshot.cursorPly,
            orientation: snapshot.orientation,
          ).encode(),
        );
        return;
      }
      // Finished in the meantime: the last flush of a closing entry screen
      // must not change a game that is on its way to the server.
      if (draft.state != DraftState.editing) return;
      await dao.autosave(
        owner,
        snapshot.id,
        pgn: snapshot.pgnMoves,
        metaJson: DraftMeta.decode(draft.metaJson)
            .withEntryView(
              cursorPly: snapshot.cursorPly,
              orientation: snapshot.orientation,
            )
            .encode(),
      );
    });
  }

  @override
  Future<void> delete(String draftId) async {
    final owner = _owner();
    if (owner == null) return;
    await _database().draftsDao.remove(owner, draftId);
  }
}
