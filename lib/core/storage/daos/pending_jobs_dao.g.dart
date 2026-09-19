// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_jobs_dao.dart';

// ignore_for_file: type=lint
mixin _$PendingJobsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PendingJobsTable get pendingJobs => attachedDatabase.pendingJobs;
  PendingJobsDaoManager get managers => PendingJobsDaoManager(this);
}

class PendingJobsDaoManager {
  final _$PendingJobsDaoMixin _db;
  PendingJobsDaoManager(this._db);
  $$PendingJobsTableTableManager get pendingJobs =>
      $$PendingJobsTableTableManager(_db.attachedDatabase, _db.pendingJobs);
}
