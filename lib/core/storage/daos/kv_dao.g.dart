// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kv_dao.dart';

// ignore_for_file: type=lint
mixin _$KvDaoMixin on DatabaseAccessor<AppDatabase> {
  $KvTable get kv => attachedDatabase.kv;
  KvDaoManager get managers => KvDaoManager(this);
}

class KvDaoManager {
  final _$KvDaoMixin _db;
  KvDaoManager(this._db);
  $$KvTableTableManager get kv =>
      $$KvTableTableManager(_db.attachedDatabase, _db.kv);
}
