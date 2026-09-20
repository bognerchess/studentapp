// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'games_cache_dao.dart';

// ignore_for_file: type=lint
mixin _$GamesCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $CachedGamesTable get cachedGames => attachedDatabase.cachedGames;
  $CachedAnalysesTable get cachedAnalyses => attachedDatabase.cachedAnalyses;
  $PendingJobsTable get pendingJobs => attachedDatabase.pendingJobs;
  GamesCacheDaoManager get managers => GamesCacheDaoManager(this);
}

class GamesCacheDaoManager {
  final _$GamesCacheDaoMixin _db;
  GamesCacheDaoManager(this._db);
  $$CachedGamesTableTableManager get cachedGames =>
      $$CachedGamesTableTableManager(_db.attachedDatabase, _db.cachedGames);
  $$CachedAnalysesTableTableManager get cachedAnalyses =>
      $$CachedAnalysesTableTableManager(
        _db.attachedDatabase,
        _db.cachedAnalyses,
      );
  $$PendingJobsTableTableManager get pendingJobs =>
      $$PendingJobsTableTableManager(_db.attachedDatabase, _db.pendingJobs);
}
