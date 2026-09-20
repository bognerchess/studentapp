// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/analysis/analysis_job_sink.dart';
import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/auth/auth_state.dart';
import 'package:bogner_chess/core/connectivity/connectivity.dart';
import 'package:bogner_chess/core/game/library_refresh.dart';
import 'package:bogner_chess/core/storage/app_database.dart';
import 'package:bogner_chess/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'draft_meta.dart';
import 'submit_models.dart';
import 'submit_queue.dart';

/// The languages the coach writes in. The server's `mobileConfig` has the
/// authoritative list; until somebody loads it, this is what the backend
/// ships with.
const Set<String> kCoachLanguages = {'en', 'de'};

/// The coach language for the system language: "de-CH" gives "de", anything
/// the coach does not write in gives "en".
String coachLanguageOf(String languageTag) {
  final language = languageTag.split(RegExp('[-_]')).first.toLowerCase();
  return kCoachLanguages.contains(language) ? language : 'en';
}

/// The `sub` of the signed-in user, or null.
String? _ownerOf(Ref ref) => switch (ref.read(authStateProvider)) {
  SignedIn(:final sub) => sub,
  SignedOut() => null,
};

/// The submit queue of the app. Creating it touches nothing (no database, no
/// plugin); `main.dart` calls `start()`, and saving a game calls `kick()`.
final submitQueueProvider = Provider<SubmitQueue>((ref) {
  final queue = SubmitQueue(
    database: () => ref.read(appDatabaseProvider),
    games: () => ref.read(gamesApiProvider),
    analysis: () => ref.read(analysisApiProvider),
    owner: () => _ownerOf(ref),
    connectivity: ref.watch(connectivityProvider),
    jobSink: () => ref.read(analysisJobSinkProvider),
    onLibraryChanged: () => ref.read(libraryRefreshProvider.notifier).request(),
    coachLanguage: () => coachLanguageOf(ref.read(apiLanguageTagProvider)()),
  );
  // Sign-in is a trigger; sign-out stops the timer. The drafts stay.
  ref.listen(authStateProvider, (previous, next) {
    final before = previous is SignedIn ? previous.sub : null;
    final after = next is SignedIn ? next.sub : null;
    if (before != after) queue.onOwnerChanged();
  });
  ref.onDispose(queue.dispose);
  return queue;
});

/// Counts and state for the queue surface (`SubmitQueueBanner`, a badge on
/// the library, ...). Idle until the queue has run once.
final submitQueueStatusProvider =
    NotifierProvider<SubmitQueueStatusNotifier, SubmitQueueStatus>(
      SubmitQueueStatusNotifier.new,
    );

class SubmitQueueStatusNotifier extends Notifier<SubmitQueueStatus> {
  @override
  SubmitQueueStatus build() {
    final status = ref.watch(submitQueueProvider).status;
    void update() => state = status.value;
    status.addListener(update);
    ref.onDispose(() => status.removeListener(update));
    return status.value;
  }
}

/// Finished uploads, one event each.
final submitQueueEventsProvider = StreamProvider<SubmitEvent>(
  (ref) => ref.watch(submitQueueProvider).events,
);

/// The signed-in user's drafts that wait or have failed, newest change
/// first: what the queue sheet lists.
final submitQueueDraftsProvider = StreamProvider.autoDispose<List<Draft>>((
  ref,
) {
  final auth = ref.watch(authStateProvider);
  if (auth is! SignedIn) return Stream.value(const []);
  return ref
      .watch(appDatabaseProvider)
      .draftsDao
      .watchAll(
        auth.sub,
        states: const {
          DraftState.ready,
          DraftState.submitting,
          DraftState.failed,
        },
      );
});

/// Why the analysis of the game with this server id was not started by
/// "Save & analyse", or null. For the game detail screen: "Saved. Analysis
/// not started: …" next to its own button. Goes away when the draft row is
/// pruned (a week) or the account's drafts are wiped.
final analysisHoldProvider = StreamProvider.autoDispose
    .family<AnalysisHold?, String>((ref, gameId) {
      final auth = ref.watch(authStateProvider);
      if (auth is! SignedIn) return Stream.value(null);
      return ref
          .watch(appDatabaseProvider)
          .draftsDao
          .watchAll(auth.sub, states: const {DraftState.submitted})
          .map((drafts) {
            for (final draft in drafts) {
              if (draft.serverGameId == gameId) {
                return DraftMeta.decode(draft.metaJson).analysisHold;
              }
            }
            return null;
          });
    });
