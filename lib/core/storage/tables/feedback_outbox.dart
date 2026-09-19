// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:drift/drift.dart';

/// Thumbs on a coach comment. `cleared` takes a rating back.
enum FeedbackRating { up, down, cleared }

/// Coach-comment ratings waiting to be sent. One row per owner and comment:
/// a newer rating replaces the older one (latest wins).
@DataClassName('OutboxFeedback')
class FeedbackOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ownerSub => text()();
  TextColumn get commentId => text()();
  TextColumn get rating => textEnum<FeedbackRating>()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {ownerSub, commentId},
  ];
}
