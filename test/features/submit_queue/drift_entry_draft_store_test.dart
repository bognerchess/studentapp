// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/features/entry/domain/entry_draft_store.dart';
import 'package:bogner_chess/features/submit_queue/data/drift_entry_draft_store.dart';
import 'package:bogner_chess/features/submit_queue/domain/draft_meta.dart';
import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter_test/flutter_test.dart';

import '../../core/storage/test_database.dart';

const _id = '00000000-0000-4000-8000-00000000000a';

EntryDraftSnapshot _snapshot(
  String pgn, {
  int cursor = 0,
  Side orientation = Side.white,
  String id = _id,
}) => EntryDraftSnapshot(
  id: id,
  pgnMoves: pgn,
  cursorPly: cursor,
  orientation: orientation,
  updatedAt: DateTime.utc(2020),
);

void main() {
  late FakeClock clock;
  late AppDatabase db;
  late DraftsDao dao;
  String? owner;
  late DriftEntryDraftStore store;

  setUp(() {
    clock = FakeClock();
    db = openTestDatabase(clock);
    dao = db.draftsDao;
    owner = alice;
    store = DriftEntryDraftStore(database: () => db, owner: () => owner);
  });

  tearDown(() => db.close());

  test(
    'the first save creates an editing draft under the screen\'s id',
    () async {
      await store.save(_snapshot('1. e4', cursor: 1));

      final draft = (await dao.get(alice, _id))!;
      expect(draft.state, DraftState.editing);
      expect(draft.pgn, '1. e4');
      expect(draft.clientGameId, isNot(_id));
      expect(draft.wantsAnalysis, isTrue);
      expect(
        DraftMeta.decode(draft.metaJson),
        const DraftMeta(cursorPly: 1, orientation: Side.white),
      );
    },
  );

  test(
    'load gives back moves, cursor, orientation and the row\'s time',
    () async {
      await store.save(
        _snapshot('1. e4 e5', cursor: 1, orientation: Side.black),
      );
      clock.advance(const Duration(minutes: 1));
      await store.save(
        _snapshot('1. e4 e5 2. Nf3', cursor: 3, orientation: Side.black),
      );

      final loaded = (await store.load(_id))!;
      expect(loaded.id, _id);
      expect(loaded.pgnMoves, '1. e4 e5 2. Nf3');
      expect(loaded.cursorPly, 3);
      expect(loaded.orientation, Side.black);
      expect(loaded.updatedAt.isAtSameMomentAs(clock()), isTrue);
      expect(await store.load('unknown'), isNull);
    },
  );

  test('save touches the moves and the entry view, nothing else', () async {
    await store.save(_snapshot('1. e4'));
    const metadata = GameMetadata(
      whiteName: 'Alice Example',
      playerColor: PlayerColor.white,
    );
    final before = (await dao.get(alice, _id))!;
    await dao.autosave(
      alice,
      _id,
      pgn: '1. e4',
      metaJson: DraftMeta.decode(before.metaJson)
          .withMetadata(metadata)
          .encode(),
      wantsAnalysis: false,
    );

    await store.save(_snapshot('1. e4 e5', cursor: 2, orientation: Side.black));

    final after = (await dao.get(alice, _id))!;
    expect(after.pgn, '1. e4 e5');
    expect(after.clientGameId, before.clientGameId);
    expect(after.wantsAnalysis, isFalse);
    final meta = DraftMeta.decode(after.metaJson);
    expect(meta.metadata, metadata);
    expect(meta.cursorPly, 2);
    expect(meta.orientation, Side.black);
  });

  test(
    'a draft that is on its way to the server is not written any more',
    () async {
      await store.save(_snapshot('1. e4 e5'));
      await dao.markReady(alice, _id);
      await dao.markSubmitting(alice, _id);

      await store.save(_snapshot('1. d4'));
      expect((await dao.get(alice, _id))!.pgn, '1. e4 e5');
      expect(await store.load(_id), isNull, reason: 'not resumable either');

      await dao.markSubmitted(alice, _id, serverGameId: 'game-1');
      await store.save(_snapshot('1. d4'));
      expect((await dao.get(alice, _id))!.pgn, '1. e4 e5');
      expect(await store.load(_id), isNull);
    },
  );

  test('resuming a ready or failed draft makes it editable again', () async {
    await store.save(_snapshot('1. e4 e5'));
    await dao.markReady(alice, _id);

    expect((await store.load(_id))!.pgnMoves, '1. e4 e5');
    expect((await dao.get(alice, _id))!.state, DraftState.editing);

    await dao.markReady(alice, _id);
    await dao.markSubmitting(alice, _id);
    await dao.markSubmitFailed(
      alice,
      _id,
      error: 'rejected',
      nextAttemptAt: null,
    );
    expect((await store.load(_id))!.pgnMoves, '1. e4 e5');
    expect((await dao.get(alice, _id))!.state, DraftState.editing);
  });

  test('a game the server already has cannot be resumed', () async {
    await store.save(_snapshot('1. e4 e5'));
    await dao.markReady(alice, _id);
    await dao.markSubmitting(alice, _id);
    await dao.setServerGameId(alice, _id, 'game-1');
    await dao.markSubmitFailed(
      alice,
      _id,
      error: 'network',
      nextAttemptAt: clock().add(const Duration(seconds: 5)),
    );

    expect(await store.load(_id), isNull);
    expect((await dao.get(alice, _id))!.state, DraftState.ready);
  });

  test('drafts belong to whoever is signed in', () async {
    await store.save(_snapshot('1. e4'));
    owner = bob;
    expect(await store.load(_id), isNull);
    await store.delete(_id);
    expect(await dao.get(alice, _id), isNotNull);

    owner = alice;
    await store.delete(_id);
    expect(await dao.get(alice, _id), isNull);
    await store.delete(_id);
  });

  test('signed out: nothing is read or written, nothing throws', () async {
    owner = null;
    await store.save(_snapshot('1. e4'));
    expect(await store.load(_id), isNull);
    await store.delete(_id);
    expect(await dao.getAll(alice), isEmpty);
  });

  test(
    'a draft without a stored cursor opens at the end of the line',
    () async {
      await dao.create(alice, id: _id, pgn: '1. e4 e5 2. Nf3');
      final loaded = (await store.load(_id))!;
      expect(loaded.cursorPly, greaterThan(3));
      expect(loaded.orientation, Side.white);
    },
  );
}
