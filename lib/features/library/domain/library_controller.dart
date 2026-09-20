// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:convert';

import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/storage/app_database.dart' show DraftState;
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:bogner_chess/features/analysis_status/domain/job_tracker_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'games_repository.dart';
import 'library_models.dart';
import 'owner.dart';

/// Filter and synchronisation state of the library. The rows themselves come
/// from the cache ([libraryRowsProvider]); this says what the server was
/// last asked and how that went.
@immutable
class LibrarySyncState {
  const LibrarySyncState({
    this.filter = const LibraryFilter(),
    this.refreshing = false,
    this.loadingMore = false,
    this.hasNextPage = false,
    this.loadedOnce = false,
    this.error,
  });

  final LibraryFilter filter;

  /// The first page is being fetched.
  final bool refreshing;
  final bool loadingMore;

  /// The server has more games for [filter] than were fetched so far.
  final bool hasNextPage;

  /// At least one refresh ended, well or badly: an empty list means "no
  /// games", not "not asked yet".
  final bool loadedOnce;

  /// Why the last refresh failed; null after a good one.
  final ApiError? error;

  bool get offline => error is ApiNetworkError;

  LibrarySyncState copyWith({
    LibraryFilter? filter,
    bool? refreshing,
    bool? loadingMore,
    bool? hasNextPage,
    bool? loadedOnce,
    ApiError? Function()? error,
  }) {
    return LibrarySyncState(
      filter: filter ?? this.filter,
      refreshing: refreshing ?? this.refreshing,
      loadingMore: loadingMore ?? this.loadingMore,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      loadedOnce: loadedOnce ?? this.loadedOnce,
      error: error == null ? this.error : error(),
    );
  }
}

final libraryControllerProvider =
    NotifierProvider.autoDispose<LibraryController, LibrarySyncState>(
      LibraryController.new,
    );

class LibraryController extends Notifier<LibrarySyncState> {
  /// How long the search field has to be quiet before the server is asked.
  static const Duration searchDebounce = Duration(milliseconds: 400);

  Timer? _debounce;
  int _generation = 0;
  DateTime? _refreshStartedAt;
  String? _endCursor;

  @override
  LibrarySyncState build() {
    ref.watch(currentOwnerProvider);
    final lifecycle = AppLifecycleListener(onResume: refresh);
    ref
      ..onDispose(lifecycle.dispose)
      ..onDispose(() => _debounce?.cancel());
    unawaited(Future.microtask(refresh));
    return const LibrarySyncState();
  }

  String? get _owner => ref.read(currentOwnerProvider);

  /// The cache answers every keystroke at once; the server is asked when
  /// typing pauses.
  void setSearchText(String text) {
    if (text == state.filter.text) {
      return;
    }
    state = state.copyWith(filter: state.filter.withText(text));
    _debounce?.cancel();
    _debounce = Timer(searchDebounce, refresh);
  }

  void setDateRange(GameDate? from, GameDate? to) {
    state = state.copyWith(filter: state.filter.withDates(from, to));
    unawaited(refresh());
  }

  void clearFilters() {
    state = state.copyWith(filter: const LibraryFilter());
    unawaited(refresh());
  }

  /// Fetches the first page for the current filter. An unfiltered refresh
  /// that reaches the last page also drops cached games the server no longer
  /// has. Never throws; see [LibrarySyncState.error].
  Future<void> refresh() async {
    final owner = _owner;
    if (owner == null || !ref.mounted) {
      return;
    }
    _debounce?.cancel();
    final generation = ++_generation;
    final games = ref.read(gamesRepositoryProvider);
    final filter = state.filter;
    final startedAt = games.now();
    state = state.copyWith(refreshing: true);
    // Jobs first seen elsewhere (another device, the submit queue).
    unawaited(ref.read(jobTrackerProvider).refreshNow());
    try {
      final page = await games.fetchPage(
        owner,
        filter: filter,
        fetchedAt: startedAt,
      );
      if (!ref.mounted || generation != _generation) {
        return;
      }
      _refreshStartedAt = startedAt;
      _endCursor = page.endCursor;
      await _dropStaleIfComplete(owner, filter, page);
      if (!ref.mounted || generation != _generation) {
        return;
      }
      state = state.copyWith(
        refreshing: false,
        loadedOnce: true,
        hasNextPage: page.hasNextPage && page.endCursor != null,
        error: () => null,
      );
    } on ApiError catch (e) {
      if (ref.mounted && generation == _generation) {
        state = state.copyWith(
          refreshing: false,
          loadedOnce: true,
          hasNextPage: false,
          error: () => e,
        );
      }
    }
  }

  /// The next page, when the list was scrolled near its end.
  Future<void> loadMore() async {
    final owner = _owner;
    final startedAt = _refreshStartedAt;
    final cursor = _endCursor;
    if (owner == null ||
        startedAt == null ||
        cursor == null ||
        !state.hasNextPage ||
        state.loadingMore ||
        state.refreshing) {
      return;
    }
    final generation = _generation;
    final filter = state.filter;
    state = state.copyWith(loadingMore: true);
    try {
      final games = ref.read(gamesRepositoryProvider);
      final page = await games.fetchPage(
        owner,
        filter: filter,
        fetchedAt: startedAt,
        after: cursor,
      );
      if (!ref.mounted || generation != _generation) {
        return;
      }
      _endCursor = page.endCursor;
      await _dropStaleIfComplete(owner, filter, page);
      if (!ref.mounted || generation != _generation) {
        return;
      }
      state = state.copyWith(
        loadingMore: false,
        hasNextPage: page.hasNextPage && page.endCursor != null,
      );
    } on ApiError catch (e) {
      if (ref.mounted && generation == _generation) {
        // Stop asking: the banner offers the retry.
        state = state.copyWith(
          loadingMore: false,
          hasNextPage: false,
          error: () => e,
        );
      }
    }
  }

  Future<void> _dropStaleIfComplete(
    String owner,
    LibraryFilter filter,
    GamesPage page,
  ) async {
    final startedAt = _refreshStartedAt;
    if (!filter.isActive && !page.hasNextPage && startedAt != null) {
      await ref.read(gamesRepositoryProvider).removeStale(owner, startedAt);
    }
  }

  /// Deletes a game on the server and in the cache.
  Future<DeleteGameOutcome> deleteGame(String gameId) async {
    final owner = _owner;
    if (owner == null) {
      return const DeleteGameFailed(ApiUnauthenticated());
    }
    return ref.read(gamesRepositoryProvider).delete(owner, gameId);
  }

  /// Deletes a draft that only exists on this device.
  Future<bool> deleteDraft(String draftId) async {
    final owner = _owner;
    if (owner == null) {
      return false;
    }
    return ref.read(appDatabaseProvider).draftsDao.remove(owner, draftId);
  }
}

/// The cached games that match the filter.
final libraryGamesProvider = StreamProvider.autoDispose<List<GameSummary>>((
  ref,
) {
  final owner = ref.watch(currentOwnerProvider);
  if (owner == null) {
    return Stream.value(const []);
  }
  final filter = ref.watch(libraryControllerProvider.select((s) => s.filter));
  return ref.watch(gamesRepositoryProvider).watchGames(owner, filter);
});

/// The drafts of this device that the server does not have yet, newest
/// first. A submitted draft is a game of the list above.
final libraryDraftsProvider = StreamProvider.autoDispose<List<LibraryDraftRow>>(
  (ref) {
    final owner = ref.watch(currentOwnerProvider);
    if (owner == null) {
      return Stream.value(const []);
    }
    return ref
        .watch(appDatabaseProvider)
        .draftsDao
        .watchAll(
          owner,
          states: const {
            DraftState.editing,
            DraftState.ready,
            DraftState.submitting,
            DraftState.failed,
          },
        )
        .map(
          (drafts) => [
            for (final draft in drafts)
              LibraryDraftRow(
                draftId: draft.id,
                state: draft.state,
                metadata: GameMetadata.fromJson(_tryDecode(draft.metaJson)),
                updatedAt: draft.updatedAt,
              ),
          ],
        );
  },
);

Object? _tryDecode(String json) {
  try {
    return jsonDecode(json);
  } on FormatException {
    return null;
  }
}

/// The rows of the library: drafts on top, then games, both filtered. Null
/// until the cache has answered.
final libraryRowsProvider = Provider.autoDispose<List<LibraryRow>?>((ref) {
  final games = ref.watch(libraryGamesProvider).value;
  final drafts = ref.watch(libraryDraftsProvider).value;
  if (games == null || drafts == null) {
    return null;
  }
  final filter = ref.watch(libraryControllerProvider.select((s) => s.filter));
  final tracked = ref.watch(trackedJobsProvider);
  return [
    for (final draft in drafts)
      if (filter.matchesDate(draft.playedDate) &&
          filter.matchesText([
            draft.whiteName,
            draft.blackName,
            draft.eventName,
          ]))
        draft,
    for (final game in games)
      LibraryGameRow(game, job: newestJob(tracked[game.id], game.latestJob)),
  ];
});
