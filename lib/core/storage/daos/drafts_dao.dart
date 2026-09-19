// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';

part 'drafts_dao.g.dart';

/// Drafts and the fields the submit queue needs (AC-3).
///
/// State machine (every transition bumps `updated_at`; a method returns false
/// and changes nothing when the draft is not in one of the "from" states or
/// belongs to somebody else):
///
///     editing --markReady--> ready --markSubmitting--> submitting
///     ready|failed --reopen--> editing
///     submitting --markSubmitted--> submitted
///     submitting --markSubmitFailed--> ready (with back-off) | failed (terminal)
///     failed --retry--> ready (attempts reset)
///     submitting --recoverInterrupted--> ready (after an app kill)
@DriftAccessor(tables: [Drafts])
class DraftsDao extends DatabaseAccessor<AppDatabase> with _$DraftsDaoMixin {
  DraftsDao(super.attachedDatabase);

  static const _uuid = Uuid();

  /// Creates a draft in [DraftState.editing] with a fresh id and
  /// `client_game_id`.
  Future<Draft> create(
    String ownerSub, {
    String pgn = '',
    String metaJson = '{}',
    bool wantsAnalysis = true,
  }) {
    final now = attachedDatabase.now();
    return into(drafts).insertReturning(
      DraftsCompanion.insert(
        id: _uuid.v4(),
        ownerSub: ownerSub,
        pgn: pgn,
        metaJson: Value(metaJson),
        state: DraftState.editing,
        clientGameId: _uuid.v4(),
        wantsAnalysis: Value(wantsAnalysis),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Saves the moves (and optionally the metadata) of a draft that is being
  /// edited. Cheap enough to call on every ply.
  Future<bool> autosave(
    String ownerSub,
    String id, {
    required String pgn,
    String? metaJson,
    bool? wantsAnalysis,
  }) {
    return _update(
      ownerSub,
      id,
      from: const {DraftState.editing},
      DraftsCompanion(
        pgn: Value(pgn),
        metaJson: Value.absentIfNull(metaJson),
        wantsAnalysis: Value.absentIfNull(wantsAnalysis),
      ),
    );
  }

  Future<Draft?> get(String ownerSub, String id) =>
      _byId(ownerSub, id).getSingleOrNull();

  Stream<Draft?> watch(String ownerSub, String id) =>
      _byId(ownerSub, id).watchSingleOrNull();

  /// Drafts of [ownerSub], most recently changed first. [states] narrows the
  /// list; by default every state is included.
  Stream<List<Draft>> watchAll(String ownerSub, {Set<DraftState>? states}) {
    final query = select(drafts)
      ..where((t) => t.ownerSub.equals(ownerSub))
      ..orderBy([
        (t) => OrderingTerm.desc(t.updatedAt),
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.asc(t.id),
      ]);
    if (states != null) {
      query.where((t) => t.state.isInValues(states));
    }
    return query.watch();
  }

  /// The draft the submit queue should send next: the [DraftState.ready] one
  /// that has waited longest and whose back-off is over. Null when there is
  /// none.
  Future<Draft?> nextSubmittable(String ownerSub) {
    final now = attachedDatabase.now();
    final query = select(drafts)
      ..where(
        (t) =>
            t.ownerSub.equals(ownerSub) &
            t.state.equalsValue(DraftState.ready) &
            (t.nextAttemptAt.isNull() |
                t.nextAttemptAt.isSmallerOrEqualValue(now)),
      )
      ..orderBy([
        (t) => OrderingTerm.asc(t.updatedAt),
        (t) => OrderingTerm.asc(t.createdAt),
        (t) => OrderingTerm.asc(t.id),
      ])
      ..limit(1);
    return query.getSingleOrNull();
  }

  /// When the earliest back-off of a ready draft ends, so the queue can set a
  /// timer. Null when no ready draft is waiting for a back-off.
  Future<DateTime?> nextBackoffEnd(String ownerSub) {
    final earliest = drafts.nextAttemptAt.min();
    final query = selectOnly(drafts)
      ..addColumns([earliest])
      ..where(
        drafts.ownerSub.equals(ownerSub) &
            drafts.state.equalsValue(DraftState.ready) &
            drafts.nextAttemptAt.isNotNull(),
      );
    return query.map((row) => row.read(earliest)).getSingle();
  }

  /// editing -> ready: the user asked to submit.
  Future<bool> markReady(String ownerSub, String id) => _update(
    ownerSub,
    id,
    from: const {DraftState.editing},
    const DraftsCompanion(
      state: Value(DraftState.ready),
      attempts: Value(0),
      lastError: Value(null),
      nextAttemptAt: Value(null),
    ),
  );

  /// ready|failed -> editing: the user wants to change the game again.
  /// Refused once the server has the game ([Draft.serverGameId] is set).
  Future<bool> reopen(String ownerSub, String id) => _update(
    ownerSub,
    id,
    from: const {DraftState.ready, DraftState.failed},
    const DraftsCompanion(
      state: Value(DraftState.editing),
      nextAttemptAt: Value(null),
    ),
    extra: (t) => t.serverGameId.isNull(),
  );

  /// ready -> submitting: the queue picked the draft up.
  Future<bool> markSubmitting(String ownerSub, String id) => _update(
    ownerSub,
    id,
    from: const {DraftState.ready},
    const DraftsCompanion(state: Value(DraftState.submitting)),
  );

  /// Records that `createGame` succeeded while the draft is still being
  /// submitted (the analysis request follows). A retry then skips the create.
  Future<bool> setServerGameId(
    String ownerSub,
    String id,
    String serverGameId,
  ) => _update(
    ownerSub,
    id,
    from: const {DraftState.submitting},
    DraftsCompanion(serverGameId: Value(serverGameId)),
  );

  /// submitting -> submitted.
  Future<bool> markSubmitted(
    String ownerSub,
    String id, {
    required String serverGameId,
  }) => _update(
    ownerSub,
    id,
    from: const {DraftState.submitting},
    DraftsCompanion(
      state: const Value(DraftState.submitted),
      serverGameId: Value(serverGameId),
      lastError: const Value(null),
      nextAttemptAt: const Value(null),
    ),
  );

  /// submitting -> ready (try again at [nextAttemptAt]) or, when
  /// [nextAttemptAt] is null, -> failed (terminal, waits for [retry]).
  /// Counts the attempt either way. The back-off policy itself belongs to the
  /// submit queue.
  Future<bool> markSubmitFailed(
    String ownerSub,
    String id, {
    required String error,
    required DateTime? nextAttemptAt,
  }) => _update(
    ownerSub,
    id,
    from: const {DraftState.submitting},
    DraftsCompanion.custom(
      state: Variable(
        (nextAttemptAt == null ? DraftState.failed : DraftState.ready).name,
      ),
      attempts: drafts.attempts + const Constant(1),
      lastError: Variable(error),
      nextAttemptAt: Variable(nextAttemptAt),
    ),
  );

  /// failed -> ready with a clean slate: the manual retry.
  Future<bool> retry(String ownerSub, String id) => _update(
    ownerSub,
    id,
    from: const {DraftState.failed},
    const DraftsCompanion(
      state: Value(DraftState.ready),
      attempts: Value(0),
      nextAttemptAt: Value(null),
    ),
  );

  /// Ends every back-off of [ownerSub] now, for "connectivity is back" and
  /// "retry all". Returns the number of drafts affected.
  Future<int> clearBackoff(String ownerSub) {
    final query = update(drafts)
      ..where(
        (t) =>
            t.ownerSub.equals(ownerSub) &
            t.state.equalsValue(DraftState.ready) &
            t.nextAttemptAt.isNotNull(),
      );
    return query.write(const DraftsCompanion(nextAttemptAt: Value(null)));
  }

  /// submitting -> ready for drafts a killed app left behind. Call once at
  /// start-up, before the queue runs. Returns the number of drafts recovered.
  Future<int> recoverInterrupted(String ownerSub) {
    final query = update(drafts)
      ..where(
        (t) =>
            t.ownerSub.equals(ownerSub) &
            t.state.equalsValue(DraftState.submitting),
      );
    return query.write(
      DraftsCompanion(
        state: const Value(DraftState.ready),
        updatedAt: Value(attachedDatabase.now()),
      ),
    );
  }

  /// Deletes the draft, whatever its state.
  Future<bool> remove(String ownerSub, String id) async {
    final query = delete(drafts)
      ..where((t) => t.ownerSub.equals(ownerSub) & t.id.equals(id));
    return await query.go() > 0;
  }

  SimpleSelectStatement<$DraftsTable, Draft> _byId(String ownerSub, String id) {
    return select(drafts)
      ..where((t) => t.ownerSub.equals(ownerSub) & t.id.equals(id));
  }

  Future<bool> _update(
    String ownerSub,
    String id,
    Insertable<Draft> changes, {
    required Set<DraftState> from,
    Expression<bool> Function($DraftsTable t)? extra,
  }) async {
    final query = update(drafts)
      ..where(
        (t) =>
            t.ownerSub.equals(ownerSub) &
            t.id.equals(id) &
            t.state.isInValues(from),
      );
    if (extra != null) {
      query.where(extra);
    }
    final now = attachedDatabase.now();
    final rows = await query.write(_WithUpdatedAt(changes, now));
    return rows > 0;
  }
}

/// [inner] plus `updated_at`, so that both plain and custom companions work.
class _WithUpdatedAt implements Insertable<Draft> {
  _WithUpdatedAt(this.inner, this.updatedAt);

  final Insertable<Draft> inner;
  final DateTime updatedAt;

  @override
  Map<String, Expression<Object>> toColumns(bool nullToAbsent) => {
    ...inner.toColumns(nullToAbsent),
    'updated_at': Variable<DateTime>(updatedAt),
  };
}
