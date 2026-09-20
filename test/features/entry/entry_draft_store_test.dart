// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:math';

import 'package:bogner_chess/features/entry/domain/entry_draft_store.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

EntryDraftSnapshot snapshot(String pgn, {String id = 'd1', int? cursor}) =>
    EntryDraftSnapshot(
      id: id,
      pgnMoves: pgn,
      cursorPly: cursor ?? 0,
      orientation: Side.white,
      updatedAt: DateTime.utc(2026, 9, 19),
    );

void main() {
  group('InMemoryEntryDraftStore', () {
    test('saves, replaces, loads and deletes by id', () async {
      final store = InMemoryEntryDraftStore();

      expect(await store.load('d1'), isNull);
      await store.save(snapshot('1. e4'));
      await store.save(snapshot('1. e4 e5'));
      await store.save(snapshot('1. d4', id: 'd2'));

      expect((await store.load('d1'))!.pgnMoves, '1. e4 e5');
      expect(store.drafts.keys, ['d1', 'd2']);

      await store.delete('d1');
      await store.delete('unknown');
      expect(await store.load('d1'), isNull);
      expect((await store.load('d2'))!.pgnMoves, '1. d4');
    });
  });

  group('EntryDraftSnapshot', () {
    test('has value equality', () {
      expect(snapshot('1. e4'), snapshot('1. e4'));
      expect(snapshot('1. e4').hashCode, snapshot('1. e4').hashCode);
      expect(snapshot('1. e4'), isNot(snapshot('1. e4', cursor: 1)));
      expect(snapshot('1. e4').toString(), isNot(contains('e4')));
    });
  });

  group('EntryAutosaver', () {
    test('writes after the debounce, not before', () {
      fakeAsync((async) {
        final store = RecordingDraftStore();
        final saver = EntryAutosaver(store)..schedule(snapshot('1. e4'));

        async.elapse(const Duration(milliseconds: 249));
        expect(store.saves, isEmpty);
        expect(saver.hasPending, isTrue);

        async.elapse(const Duration(milliseconds: 1));
        expect(store.saves.single.pgnMoves, '1. e4');
        expect(saver.hasPending, isFalse);
      });
    });

    test('never waits longer than 300 ms', () {
      expect(
        EntryAutosaver(RecordingDraftStore()).debounce,
        lessThanOrEqualTo(const Duration(milliseconds: 300)),
      );
      expect(
        () => EntryAutosaver(
          RecordingDraftStore(),
          debounce: const Duration(seconds: 1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('one write per ply at a human pace', () {
      fakeAsync((async) {
        final store = RecordingDraftStore();
        final saver = EntryAutosaver(store);

        for (final pgn in ['1. e4', '1. e4 e5', '1. e4 e5 2. Nf3']) {
          saver.schedule(snapshot(pgn));
          async.elapse(const Duration(seconds: 2));
        }

        expect(store.saves.map((s) => s.pgnMoves), [
          '1. e4',
          '1. e4 e5',
          '1. e4 e5 2. Nf3',
        ]);
      });
    });

    test('a burst of plies costs one write, of the newest state', () {
      fakeAsync((async) {
        final store = RecordingDraftStore();
        final saver = EntryAutosaver(store);

        saver.schedule(snapshot('1. e4'));
        async.elapse(const Duration(milliseconds: 100));
        saver.schedule(snapshot('1. e4 e5'));
        async.elapse(const Duration(milliseconds: 100));
        saver.schedule(snapshot('1. e4 e5 2. Nf3'));
        async.elapse(const Duration(milliseconds: 300));

        expect(store.saves.single.pgnMoves, '1. e4 e5 2. Nf3');
      });
    });

    test('flush writes at once and leaves no timer behind', () {
      fakeAsync((async) {
        final store = RecordingDraftStore();
        final saver = EntryAutosaver(store)..schedule(snapshot('1. e4'));

        unawaited(saver.flush());
        async.flushMicrotasks();

        expect(store.saves.single.pgnMoves, '1. e4');
        expect(async.pendingTimers, isEmpty);

        async.elapse(const Duration(seconds: 1));
        expect(store.saves, hasLength(1), reason: 'no second write');
      });
    });

    test('flush without anything pending does nothing', () {
      fakeAsync((async) {
        final store = RecordingDraftStore();
        unawaited(EntryAutosaver(store).flush());
        async.flushMicrotasks();

        expect(store.saves, isEmpty);
      });
    });

    test('dispose flushes', () {
      fakeAsync((async) {
        final store = RecordingDraftStore();
        final saver = EntryAutosaver(store)..schedule(snapshot('1. e4'));
        unawaited(saver.dispose());
        async.flushMicrotasks();

        expect(store.saves.single.pgnMoves, '1. e4');
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('a failing store is reported and the next ply is still saved', () {
      fakeAsync((async) {
        final errors = <Object>[];
        final store = RecordingDraftStore()..saveError = StateError('disk');
        final saver = EntryAutosaver(
          store,
          onError: (error, _) => errors.add(error),
        )..schedule(snapshot('1. e4'));
        async.elapse(const Duration(milliseconds: 300));

        expect(errors.single, isStateError);

        store.saveError = null;
        saver.schedule(snapshot('1. e4 e5'));
        async.elapse(const Duration(milliseconds: 300));

        expect(store.saves.single.pgnMoves, '1. e4 e5');
      });
    });
  });

  group('newEntryDraftId', () {
    test('is a version 4 UUID', () {
      final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );

      for (var seed = 0; seed < 50; seed++) {
        expect(newEntryDraftId(Random(seed)), matches(pattern));
      }
      expect(newEntryDraftId(), matches(pattern));
    });

    test('differs from call to call', () {
      expect({for (var i = 0; i < 100; i++) newEntryDraftId()}, hasLength(100));
    });
  });
}
