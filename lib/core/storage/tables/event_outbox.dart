// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:drift/drift.dart';

/// Analytics events waiting to be sent. Device-level: events exist before
/// sign-in, so [ownerSub] may be null.
@DataClassName('OutboxEvent')
class EventOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ownerSub => text().nullable()();
  TextColumn get deviceId => text()();
  TextColumn get sessionId => text()();
  TextColumn get name => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get propsJson => text().withDefault(const Constant('{}'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
}
