// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_workflows_dao.dart';

// ignore_for_file: type=lint
mixin _$PendingWorkflowsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PendingWorkflowsTable get pendingWorkflows =>
      attachedDatabase.pendingWorkflows;
  PendingWorkflowsDaoManager get managers => PendingWorkflowsDaoManager(this);
}

class PendingWorkflowsDaoManager {
  final _$PendingWorkflowsDaoMixin _db;
  PendingWorkflowsDaoManager(this._db);
  $$PendingWorkflowsTableTableManager get pendingWorkflows =>
      $$PendingWorkflowsTableTableManager(
        _db.attachedDatabase,
        _db.pendingWorkflows,
      );
}
