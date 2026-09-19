// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:drift/drift.dart';

import '../app_database.dart';

part 'event_outbox_dao.g.dart';

/// Analytics events on their way to the server. Not scoped by owner: the
/// outbox belongs to the device, and an event may predate sign-in.
///
/// The consent gate sits in front of this DAO (lib/core/analytics); nothing
/// here decides whether an event may be recorded.
@DriftAccessor(tables: [EventOutbox])
class EventOutboxDao extends DatabaseAccessor<AppDatabase>
    with _$EventOutboxDaoMixin {
  EventOutboxDao(super.attachedDatabase);

  /// The outbox never grows beyond this many rows; the oldest go first.
  static const defaultMaxRows = 1000;

  /// Adds an event, then trims the outbox to [maxRows]. Returns the row id.
  Future<int> enqueue({
    required String deviceId,
    required String sessionId,
    required String name,
    String? ownerSub,
    DateTime? occurredAt,
    String propsJson = '{}',
    int maxRows = defaultMaxRows,
  }) {
    return transaction(() async {
      final id = await into(eventOutbox).insert(
        EventOutboxCompanion.insert(
          ownerSub: Value(ownerSub),
          deviceId: deviceId,
          sessionId: sessionId,
          name: name,
          occurredAt: occurredAt ?? attachedDatabase.now(),
          propsJson: Value(propsJson),
        ),
      );
      await trim(maxRows);
      return id;
    });
  }

  /// The [limit] oldest events.
  Future<List<OutboxEvent>> takeBatch(int limit) {
    final query = select(eventOutbox)
      ..orderBy([(t) => OrderingTerm.asc(t.id)])
      ..limit(limit);
    return query.get();
  }

  /// After a successful send.
  Future<int> removeByIds(Iterable<int> ids) {
    return (delete(eventOutbox)..where((t) => t.id.isIn(ids))).go();
  }

  /// After a failed send.
  Future<void> bumpAttempts(Iterable<int> ids) {
    final query = update(eventOutbox)..where((t) => t.id.isIn(ids));
    return query.write(
      EventOutboxCompanion.custom(
        attempts: eventOutbox.attempts + const Constant(1),
      ),
    );
  }

  /// Drops events that failed [maxAttempts] times or more.
  Future<int> removeExhausted(int maxAttempts) {
    final query = delete(eventOutbox)
      ..where((t) => t.attempts.isBiggerOrEqualValue(maxAttempts));
    return query.go();
  }

  /// Keeps the newest [maxRows] events and returns how many were dropped.
  Future<int> trim(int maxRows) {
    final keep = selectOnly(eventOutbox)
      ..addColumns([eventOutbox.id])
      ..orderBy([OrderingTerm.desc(eventOutbox.id)])
      ..limit(maxRows);
    final query = delete(eventOutbox)..where((t) => t.id.isNotInQuery(keep));
    return query.go();
  }

  Future<int> count() async {
    final rows = eventOutbox.id.count();
    final query = selectOnly(eventOutbox)..addColumns([rows]);
    return (await query.map((row) => row.read(rows)).getSingle()) ?? 0;
  }

  /// Everything, consent withdrawn.
  Future<int> clear() => delete(eventOutbox).go();
}
