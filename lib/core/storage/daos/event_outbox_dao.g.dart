// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_outbox_dao.dart';

// ignore_for_file: type=lint
mixin _$EventOutboxDaoMixin on DatabaseAccessor<AppDatabase> {
  $EventOutboxTable get eventOutbox => attachedDatabase.eventOutbox;
  EventOutboxDaoManager get managers => EventOutboxDaoManager(this);
}

class EventOutboxDaoManager {
  final _$EventOutboxDaoMixin _db;
  EventOutboxDaoManager(this._db);
  $$EventOutboxTableTableManager get eventOutbox =>
      $$EventOutboxTableTableManager(_db.attachedDatabase, _db.eventOutbox);
}
