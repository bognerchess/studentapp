// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analysis_cache_dao.dart';

// ignore_for_file: type=lint
mixin _$AnalysisCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $CachedAnalysesTable get cachedAnalyses => attachedDatabase.cachedAnalyses;
  AnalysisCacheDaoManager get managers => AnalysisCacheDaoManager(this);
}

class AnalysisCacheDaoManager {
  final _$AnalysisCacheDaoMixin _db;
  AnalysisCacheDaoManager(this._db);
  $$CachedAnalysesTableTableManager get cachedAnalyses =>
      $$CachedAnalysesTableTableManager(
        _db.attachedDatabase,
        _db.cachedAnalyses,
      );
}
