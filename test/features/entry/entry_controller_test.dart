// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/features/entry/domain/entry_controller.dart';
import 'package:bogner_chess/features/entry/domain/entry_draft_store.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

NormalMove uci(String move) => NormalMove.fromUci(move);

/// A store whose `load` waits until the test lets it go.
class SlowLoadStore extends RecordingDraftStore {
  SlowLoadStore(super.initial);

  final Completer<void> gate = Completer<void>();

  @override
  Future<EntryDraftSnapshot?> load(String draftId) async {
    await gate.future;
    return super.load(draftId);
  }
}

void main() {
  late RecordingDraftStore store;

  ProviderContainer containerWith(EntryDraftStore store) {
    final container = ProviderContainer(
      overrides: [
        entryDraftStoreProvider.overrideWithValue(store),
        entryClockProvider.overrideWithValue(() => DateTime.utc(2026, 9, 19)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => store = RecordingDraftStore());

  test('play reports played, needsConfirmation and rejected', () {
    fakeAsync((async) {
      final container = containerWith(store);
      final provider = entryControllerProvider(null);
      final sub = container.listen(provider, (_, _) {});
      final controller = container.read(provider.notifier);

      expect(controller.play(uci('e2e5')), EntryPlayOutcome.rejected);
      expect(controller.play(uci('e2e4')), EntryPlayOutcome.played);
      expect(controller.play(uci('e7e5')), EntryPlayOutcome.played);
      controller.goTo(1);
      expect(controller.play(uci('e7e5')), EntryPlayOutcome.played);
      controller.goTo(1);
      expect(controller.play(uci('c7c5')), EntryPlayOutcome.needsConfirmation);
      expect(container.read(provider).game.toPgnMoves(), '1. e4 e5');
      expect(
        controller.play(uci('c7c5'), overwrite: true),
        EntryPlayOutcome.played,
      );
      expect(container.read(provider).game.toPgnMoves(), '1. e4 c5');

      sub.close();
      async.elapse(const Duration(seconds: 1));
    });
  });

  test('a single ply animates, a jump does not', () {
    fakeAsync((async) {
      final container = containerWith(store);
      final provider = entryControllerProvider(null);
      final sub = container.listen(provider, (_, _) {});
      final controller = container.read(provider.notifier);
      for (final move in ['e2e4', 'e7e5', 'g1f3', 'b8c6']) {
        controller.play(uci(move));
      }

      controller.goTo(0);
      expect(container.read(provider).animate, isFalse);
      controller.goTo(1);
      expect(container.read(provider).animate, isTrue);
      controller.goTo(4);
      expect(container.read(provider).animate, isFalse);
      controller.undo();
      expect(container.read(provider).animate, isTrue);

      sub.close();
      async.elapse(const Duration(seconds: 1));
    });
  });

  test('each visit gets its own draft id', () {
    final a = containerWith(store);
    final b = containerWith(store);

    expect(
      a.read(entryControllerProvider(null)).draftId,
      isNot(b.read(entryControllerProvider(null)).draftId),
    );
  });

  test('moves are rejected while the draft is loading', () {
    fakeAsync((async) {
      final slow = SlowLoadStore([
        EntryDraftSnapshot(
          id: 'd1',
          pgnMoves: '1. d4 d5',
          cursorPly: 2,
          orientation: Side.black,
          updatedAt: DateTime.utc(2026),
        ),
      ]);
      final container = containerWith(slow);
      final provider = entryControllerProvider('d1');
      final sub = container.listen(provider, (_, _) {});
      final controller = container.read(provider.notifier);

      expect(container.read(provider).loading, isTrue);
      expect(controller.play(uci('e2e4')), EntryPlayOutcome.rejected);
      controller
        ..undo()
        ..flip();

      slow.gate.complete();
      async.flushMicrotasks();

      final state = container.read(provider);
      expect(state.loading, isFalse);
      expect(state.game.toPgnMoves(), '1. d4 d5');
      expect(state.orientation, Side.black);
      expect(state.animate, isFalse);
      expect(slow.saves, isEmpty);

      sub.close();
      async.elapse(const Duration(seconds: 1));
    });
  });

  test('disposing the provider flushes the pending save', () {
    fakeAsync((async) {
      final container = containerWith(store);
      final provider = entryControllerProvider(null);
      final sub = container.listen(provider, (_, _) {});
      container.read(provider.notifier).play(uci('e2e4'));
      expect(store.saves, isEmpty);

      sub.close();
      container.dispose();
      async.flushMicrotasks();

      expect(store.saves.single.pgnMoves, '1. e4');
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('finish flushes and describes the game', () {
    fakeAsync((async) {
      final container = containerWith(store);
      final provider = entryControllerProvider(null);
      final sub = container.listen(provider, (_, _) {});
      final controller = container.read(provider.notifier);
      for (final move in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
        controller.play(uci(move));
      }
      controller.goTo(2);

      final results = <Object>[];
      unawaited(controller.finish().then(results.add));
      async.flushMicrotasks();

      expect(store.saves.single.cursorPly, 2);
      expect(results.single.toString(), contains('4 plies'));
      expect(results.single.toString(), contains('0-1'));

      sub.close();
      async.elapse(const Duration(seconds: 1));
    });
  });

  test(
    'an emptied draft is saved empty, so the store holds no stale moves',
    () {
      fakeAsync((async) {
        final container = containerWith(store);
        final provider = entryControllerProvider(null);
        final sub = container.listen(provider, (_, _) {});
        final controller = container.read(provider.notifier)..play(uci('e2e4'));
        async.elapse(const Duration(milliseconds: 300));
        controller.undo();
        async.elapse(const Duration(milliseconds: 300));

        expect(store.saves.map((s) => s.pgnMoves), ['1. e4', '']);

        sub.close();
        async.elapse(const Duration(seconds: 1));
      });
    },
  );
}
