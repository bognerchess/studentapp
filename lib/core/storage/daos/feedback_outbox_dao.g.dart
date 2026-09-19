// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feedback_outbox_dao.dart';

// ignore_for_file: type=lint
mixin _$FeedbackOutboxDaoMixin on DatabaseAccessor<AppDatabase> {
  $FeedbackOutboxTable get feedbackOutbox => attachedDatabase.feedbackOutbox;
  FeedbackOutboxDaoManager get managers => FeedbackOutboxDaoManager(this);
}

class FeedbackOutboxDaoManager {
  final _$FeedbackOutboxDaoMixin _db;
  FeedbackOutboxDaoManager(this._db);
  $$FeedbackOutboxTableTableManager get feedbackOutbox =>
      $$FeedbackOutboxTableTableManager(
        _db.attachedDatabase,
        _db.feedbackOutbox,
      );
}
