---
id: WP-13
title: drift database
status: review
size: M
depends_on: [WP-02]
blocked_by_human: []
branch: mobile/WP-13
pr:
---

## Scope

The local database of the app, in `lib/core/storage/`.

- `app_database.dart`: `AppDatabase(QueryExecutor, {clock})` and `AppDatabase.open({clock})` (drift_flutter, background isolate, `bogner_chess.sqlite` in the application support directory), `schemaVersion` 1, migration strategy, `wipeOwner(sub, {keepDrafts})`, `wipeAll()`.
- `tables/`: `drafts`, `cached_games`, `cached_analyses`, `pending_jobs`, `event_outbox`, `feedback_outbox`, `kv`. `converters.dart`: `DateOnlyConverter`.
- `daos/`: `DraftsDao`, `GamesCacheDao`, `AnalysisCacheDao`, `PendingJobsDao`, `EventOutboxDao`, `FeedbackOutboxDao`, `KvDao`.
- Schema versioning from day one: `drift_schemas/drift_schema_v1.json`, generated helpers in `test/core/storage/generated/`, the harness `test/core/storage/migration_test.dart`.
- Tests on an in-memory database for every DAO, the state machine, latest-wins feedback, the outbox cap, owner scoping and both wipe functions.
- `docs/storage.md`; rows in `docs/dependencies.md`; `build.yaml`.

## Out of scope

Riverpod providers (WP-03 owns the setup; see the handoff notes). The back-off policy and the submit queue (WP-27), the poller (WP-28), the analytics consent gate and event catalogue (WP-33), the feedback sender (WP-29d). `lib/main.dart`, the router, l10n, `lib/core/chess`. `docs/tasks/INDEX.md`.

## Contracts

**Consumes:** `tool/gen.sh` and `tool/check.sh` from WP-02 (unchanged); the table sketch in `product-hub/docs/mobile-mvp/03-design-flutter-client.md` ("Offline drafts and submit-later", "Job status", "Auth": drafts are scoped by the token `sub`).
**Produces:** `package:bogner_chess/core/storage/app_database.dart` (one import: database, DAOs, row classes, enums) for WP-20, WP-26, WP-27, WP-28, WP-29d, WP-33; `test/core/storage/test_database.dart` (`openTestDatabase`, `FakeClock`) for their tests; the migration procedure in `docs/storage.md`.

## Steps

1. Re-verify the packages on pub.dev, add them, read how `sqlite3` 3.x gets its native library.
2. Tables, database class, DAOs; `build.yaml`; generate.
3. Schema dump, generated helpers, migration harness; check that the harness really fails on an undeclared schema change.
4. Tests.
5. Rehearse the documented "add a column" procedure in a scratch copy.
6. iOS simulator build, a look into the bundle, a smoke run of `AppDatabase.open()` on a simulator.
7. Documentation.

## Acceptance commands

```bash
tool/check.sh
flutter test test/core/storage
flutter build ios --simulator --debug
ls build/ios/iphonesimulator/Runner.app/Frameworks   # contains sqlite3.framework
git status --short ios/                              # empty: no Podfile, no project change
```

## Evidence

All commands were run on 2026-09-19 (macOS 26.6, Flutter 3.47.5, Xcode as in `docs/building.md`) after the last change. Progress lines of `flutter test` and the list of outdated packages are cut.

### The gate

`tool/check.sh`

```
==> 1/7 dependencies: flutter pub get --enforce-lockfile
Got dependencies!

==> 2/7 format: dart format --set-exit-if-changed
Formatted 59 files (0 changed) in 0.07 seconds.

==> 3/7 analyze: flutter analyze --fatal-infos
No issues found! (ran in 1.7s)

==> 4/7 licence headers: tool/check_headers.dart
check_headers: ok

==> 5/7 layer imports: tool/check_layers.dart
check_layers: ok

==> 6/7 codegen is clean: tool/gen.sh, then compare the working tree
gen: dart run build_runner build --delete-conflicting-outputs
W These options have been removed and were ignored: --delete-conflicting-outputs
  0s drift_dev on 64 inputs: 64 skipped
  0s source_gen:combining_builder on 85 inputs: 85 skipped
  Built with build_runner/aot in 0s; wrote 0 outputs.
codegen: clean

==> 7/7 tests: flutter test --exclude-tags golden
00:01 +98: All tests passed!

OK in 7s
```

98 tests: the 29 from WP-02 and 69 in `test/core/storage`. Codegen was also run cold (`rm -rf .dart_tool/build && tool/gen.sh`, 18 s, 52 outputs): no difference to the committed files.

### The migration harness catches an undeclared schema change

A nullable column `extra` was added to `kv` without raising `schemaVersion`, code regenerated, then `flutter test test/core/storage/migration_test.dart`:

```
  Schema does not match
  kv:
   columns:
    additional:
     Contains the following unexpected entries: extra

Failing tests:
  test/core/storage/migration_test.dart: a fresh install has exactly the dumped schema
```

The change was reverted afterwards.

### The documented migration procedure works

In a scratch copy outside the repository, following "Changing the schema" in `docs/storage.md` to the letter: nullable column `drafts.source`, `schemaVersion` 2, the four commands, which produced `drift_schemas/drift_schema_v2.json`, `lib/core/storage/generated/schema_versions.dart` and `test/core/storage/generated/schema_v2.dart`. Before the migration was written, the harness failed with `upgrades end in the dumped schema from 1 to 2` (the `onUpgrade` that throws). With `onUpgrade: stepByStep(from1To2: ...addColumn...)` sections 1 to 6 of the gate were green, generated files in the two `generated/` directories included, and `flutter test test/core/storage` ended with `+70: All tests passed!` (the new case `from 1 to 2` appeared by itself).

### iOS

`flutter build ios --simulator --debug`

```
Building com.bognerchess.mobile for simulator (ios)...
Xcode build done.                                            6.4s
✓ Built build/ios/iphonesimulator/Runner.app
$ ls build/ios/iphonesimulator/Runner.app/Frameworks
App.framework  Flutter.framework  objective_c.framework  sqlite3.framework
$ git status --short ios/
$
```

No CocoaPods, no Swift package, no change under `ios/`. `.flutter-plugins-dependencies` lists one iOS plugin, `path_provider_foundation`, with `native_build: false` (2.6.0 calls Foundation through FFI and has no native plugin code; that is where `objective_c.framework` comes from). `sqlite3.framework` is the code asset of the `sqlite3` build hook.

Smoke run on a simulator, with a temporary entry point that was not committed (`AppDatabase.open()`, create and autosave a draft, read it, list the support directory, `wipeAll`, close). It ran on a second simulator (iPhone 17) so as not to replace the app on the one other agents use; the app was uninstalled and the simulator shut down afterwards.

```
flutter: SMOKE sqlite 3.53.4
flutter: SMOKE draft 1. e4 e5 state=DraftState.editing
flutter: SMOKE files [bogner_chess.sqlite]
flutter: SMOKE OK
```

### Not verified

`flutter test` on Linux. Nothing was run on Linux (pulling and running a container image was not part of the brief). See "How SQLite gets into the app, and CI" below for why it is expected to work and what to do if it does not.

## Handoff notes

### Dependencies (re-verified on pub.dev on 2026-09-19)

| Package | Constraint | Locked | Licence |
| --- | --- | --- | --- |
| `drift` | `^2.35.0` | 2.35.0 | MIT |
| `drift_flutter` | `^0.3.1` | 0.3.1 | MIT |
| `path_provider` | `^2.1.6` | 2.1.6 | BSD-3-Clause |
| `uuid` | `^4.6.0` | 4.6.0 | MIT |
| `build_runner` (dev) | `^2.16.1` | 2.16.1 | BSD-3-Clause |
| `drift_dev` (dev) | `^2.35.0` | 2.35.0 | MIT |

Transitive: `sqlite3` 3.5.2 (MIT; 3.6.0 needs `hooks ^2.2.0` → `meta ^1.19.0`, Flutter 3.47.5 pins `meta` 1.18.3). `sqlite3_flutter_libs 0.6.0+eol` and `sqlcipher_flutter_libs 0.7.0+eol` are in the lock file because `drift_flutter` still lists them; both are empty packages without native code.

`pubspec.yaml`: four lines plus a comment under `dependencies`, two plus a comment under `dev_dependencies`. Expect a trivial conflict with WP-03 and WP-04 there and a real one in `pubspec.lock`: resolve the lock file by taking either side and running `flutter pub get`.

### How SQLite gets into the app, and CI

`sqlite3` 3.x uses a Dart build hook. `flutter test`, `flutter run` and `flutter build` download a prebuilt SQLite for the target (from the GitHub release of `simolus3/sqlite3.dart`, checked against a sha256 shipped inside the pub package) into `.dart_tool/hooks_runner/shared/sqlite3/` and bundle it. Consequences:

- **No apt package is needed in the `check` job and `.github/workflows/pr.yml` was not changed.** The hook's default path downloads a binary (Linux x64 is among the published ones) and compiles nothing, so no C toolchain either. The job needs network access to github.com, which GitHub runners have. This was not run on Linux. If the first CI run shows a problem with the hook on Ubuntu, the fallback that the package documents is system SQLite for tests: `apt-get install -y libsqlite3-dev` in the `check` job plus `hooks: user_defines: sqlite3: source: system` in `pubspec.yaml`. That would also change what iOS bundles, so prefer fixing the download.
- The `ios` job needs nothing new either.
- `tool/gen.sh` works unchanged. build_runner 2.16 prints `W These options have been removed and were ignored: --delete-conflicting-outputs`. It is harmless; whoever touches `gen.sh` next can drop the flag.
- A full `build_runner` run from cold takes about 18 s, a warm one under a second.

### Files outside `lib/core/storage` and `test/core/storage`

- `build.yaml` (new): restricts `drift_dev` to `lib/core/storage/**`. Without it the generator analyses every Dart file, the fixture trees of WP-02 included. Other generators (freezed, graphql_codegen) add their own builder sections next to it.
- `analysis_options.yaml`: one more exclude, `**/generated/**`. drift's generated migration helpers contain raw generic types, which `strict-raw-types` reports as warnings, and `// ignore_for_file: type=lint` does not cover those. WP-02 already exempts `generated/` directories from the format and header checks; this makes the analyzer agree.
- `docs/dependencies.md`, `docs/storage.md`, `drift_schemas/`.

### Riverpod: TODO for WP-03

`flutter_riverpod` is not in `pubspec.yaml` on this branch, so there is no `lib/core/storage/storage_providers.dart`. After WP-03 is merged, add it (it belongs to `lib/core/storage/`):

```dart
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final draftsDaoProvider = Provider((ref) => ref.watch(appDatabaseProvider).draftsDao);
// ... one line per DAO, as needed
```

Keep it a plain `Provider` that is never auto-disposed: two open `AppDatabase` instances on the same file corrupt it, and drift warns about exactly that. Tests override it: `appDatabaseProvider.overrideWithValue(openTestDatabase(clock))`, and close the database in `tearDown`.

### Tables

Timestamps are unix seconds (drift default, INTEGER). Enums are stored by name. `owner_sub` is the token's `sub`.

| Table (row class) | Columns |
| --- | --- |
| `drafts` (`Draft`) | `id` text pk (uuid v4), `owner_sub`, `pgn`, `meta_json` default `{}`, `state` `DraftState{editing, ready, submitting, submitted, failed}`, `client_game_id` text unique (uuid v4), `wants_analysis` bool default true, `server_game_id` null, `attempts` int default 0, `last_error` null, `next_attempt_at` null, `created_at`, `updated_at`. Index (`owner_sub`, `state`, `updated_at`). |
| `cached_games` (`CachedGame`) | `game_id` pk, `owner_sub`, `summary_json`, `played_date` null (TEXT `YYYY-MM-DD`, `DateTime` in Dart through `DateOnlyConverter`), `opponent_name` null, `opponent_search` null (lower case, written by the DAO), `updated_at` (server time), `fetched_at`. Index (`owner_sub`, `played_date`). |
| `cached_analyses` (`CachedAnalysis`) | `game_id` pk, `owner_sub`, `schema_version` int, `schema_minor` int, `payload` text, `fetched_at`. |
| `pending_jobs` (`PendingJob`) | `job_id` pk, `game_id`, `owner_sub`, `state` `JobState{queued, running, done, failed}` (+ `isActive`), `created_at`, `last_polled_at` null. Index (`owner_sub`, `state`). |
| `event_outbox` (`OutboxEvent`) | `id` autoincrement, `owner_sub` null, `device_id`, `session_id`, `name`, `occurred_at`, `props_json` default `{}`, `attempts` default 0. |
| `feedback_outbox` (`OutboxFeedback`) | `id` autoincrement, `owner_sub`, `comment_id`, `rating` `FeedbackRating{up, down, cleared}`, `created_at`, `attempts` default 0. Unique (`owner_sub`, `comment_id`). |
| `kv` (`KvEntry`) | `key` pk, `value`. |

One column more than the brief: `cached_games.opponent_search`. SQLite folds case for ASCII only, so a search for "müller" would not find "Müller"; the DAO stores `opponentName.toLowerCase()` (Unicode-aware in Dart) and searches that.

### DAO API

Reach a DAO through the database: `db.draftsDao`, `db.gamesCacheDao`, `db.analysisCacheDao`, `db.pendingJobsDao`, `db.eventOutboxDao`, `db.feedbackOutboxDao`, `db.kvDao`. Every owner-scoped method has `ownerSub` as its first argument and never reads or changes a row of another owner. "now" is always `db.now()`, the injected clock.

`AppDatabase`

```dart
AppDatabase(QueryExecutor executor, {Clock? clock});      // typedef Clock = DateTime Function();
factory AppDatabase.open({Clock? clock});
final Clock now;
Future<void> wipeOwner(String ownerSub, {bool keepDrafts = false});
Future<void> wipeAll();
```

`DraftsDao`. The state-changing methods return `false`, and change nothing, when the draft is not in an allowed "from" state (or is not the owner's). Each of them bumps `updated_at`.

```dart
Future<Draft> create(String ownerSub, {String pgn = '', String metaJson = '{}', bool wantsAnalysis = true});
Future<bool> autosave(String ownerSub, String id, {required String pgn, String? metaJson, bool? wantsAnalysis}); // editing only
Future<Draft?> get(String ownerSub, String id);
Stream<Draft?> watch(String ownerSub, String id);
Stream<List<Draft>> watchAll(String ownerSub, {Set<DraftState>? states});   // updated_at desc
Future<Draft?> nextSubmittable(String ownerSub);   // ready, next_attempt_at null or <= now; updated_at asc
Future<DateTime?> nextBackoffEnd(String ownerSub); // earliest next_attempt_at among ready drafts
Future<bool> markReady(String ownerSub, String id);        // editing -> ready; attempts 0, error and back-off cleared
Future<bool> reopen(String ownerSub, String id);           // ready|failed -> editing; refused once server_game_id is set
Future<bool> markSubmitting(String ownerSub, String id);   // ready -> submitting
Future<bool> setServerGameId(String ownerSub, String id, String serverGameId); // while submitting: createGame done, analysis request open
Future<bool> markSubmitted(String ownerSub, String id, {required String serverGameId}); // submitting -> submitted
Future<bool> markSubmitFailed(String ownerSub, String id, {required String error, required DateTime? nextAttemptAt});
    // submitting -> ready (back-off until nextAttemptAt) or, with null, -> failed; attempts + 1
Future<bool> retry(String ownerSub, String id);            // failed -> ready; attempts 0
Future<int> clearBackoff(String ownerSub);                 // connectivity is back: all ready drafts are due
Future<int> recoverInterrupted(String ownerSub);           // submitting -> ready, once at start-up
Future<bool> remove(String ownerSub, String id);
```

For WP-27: the queue loop is `recoverInterrupted` once, then `nextSubmittable` → `markSubmitting` → (`createGame` unless `serverGameId` is set → `setServerGameId`) → request analysis → `markSubmitted` or `markSubmitFailed`. A failure moves a draft behind the other ready ones, because ordering is by `updated_at`. The back-off policy and the attempt limit are the queue's: pass `nextAttemptAt: null` to give up. `attempts` and `lastError` are there for it to read. `LimitReached` after a successful create is a `markSubmitted`, not a failure (the game is in the library). `markSubmitting` returning false means somebody else took the draft: skip it.

`GamesCacheDao`

```dart
class CachedGameInput { gameId, summaryJson, updatedAt, playedDate?, opponentName? }
Future<void> upsertPage(String ownerSub, List<CachedGameInput> games, {DateTime? fetchedAt});
Stream<List<CachedGame>> watchGames(String ownerSub, {String? opponentQuery, DateTime? playedFrom, DateTime? playedTo, int? limit});
    // played_date desc (undated last), then updated_at desc; substring search ignores case, % and _ are literal;
    // the date range is inclusive and leaves undated games out
Future<CachedGame?> get(String ownerSub, String gameId);
Future<bool> remove(String ownerSub, String gameId);             // also its cached analysis and its pending jobs
Future<int> removeStale(String ownerSub, DateTime refreshStartedAt); // fetched_at < refreshStartedAt, with their analyses
```

For WP-26, a full refresh: take `final t = db.now()`, pass `fetchedAt: t` for every page, then `removeStale(owner, t)`. That is how games deleted on another device disappear.

`AnalysisCacheDao`

```dart
Future<void> put(String ownerSub, String gameId, {required int schemaVersion, required int schemaMinor, required String payload, DateTime? fetchedAt});
Future<CachedAnalysis?> get(String ownerSub, String gameId);
Stream<CachedAnalysis?> watch(String ownerSub, String gameId);
Future<bool> remove(String ownerSub, String gameId);
```

`PendingJobsDao`

```dart
Future<void> upsert(String ownerSub, {required String jobId, required String gameId, required JobState state}); // keeps created_at, last_polled_at
Stream<List<PendingJob>> watchActive(String ownerSub);   // queued|running, oldest first
Future<List<PendingJob>> getActive(String ownerSub);
Stream<PendingJob?> watchLatestForGame(String ownerSub, String gameId);
Future<void> markPolled(String ownerSub, Iterable<String> jobIds);
Future<bool> remove(String ownerSub, String jobId);
Future<int> removeFinished(String ownerSub);             // done|failed
```

`EventOutboxDao` (device-level, not owner-scoped; the consent gate sits in front of it)

```dart
static const defaultMaxRows = 1000;
Future<int> enqueue({required String deviceId, required String sessionId, required String name, String? ownerSub, DateTime? occurredAt, String propsJson = '{}', int maxRows = defaultMaxRows}); // inserts, then trims
Future<List<OutboxEvent>> takeBatch(int limit);          // oldest first; does not remove
Future<int> removeByIds(Iterable<int> ids);              // after a successful send
Future<void> bumpAttempts(Iterable<int> ids);            // after a failed send
Future<int> removeExhausted(int maxAttempts);
Future<int> trim(int maxRows);                           // keeps the newest
Future<int> count();
Future<int> clear();                                     // consent withdrawn
```

`FeedbackOutboxDao`

```dart
Future<void> put(String ownerSub, String commentId, FeedbackRating rating);  // latest wins; attempts start again
Stream<OutboxFeedback?> watchPending(String ownerSub, String commentId);
Future<List<OutboxFeedback>> takeBatch(String ownerSub, int limit);          // waited longest first
Future<int> removeSent(Iterable<OutboxFeedback> sent);   // pass the rows that were sent, not ids
Future<void> bumpAttempts(Iterable<int> ids);
Future<int> removeExhausted(String ownerSub, int maxAttempts);
```

`removeSent` takes rows on purpose: it deletes a row only if its rating is still the one that was sent. A thumb that the user changed while the request was in flight stays in the outbox and goes out next.

`KvDao`

```dart
Future<String?> get(String key, {String? ownerSub});
Stream<String?> watch(String key, {String? ownerSub});
Future<void> set(String key, String value, {String? ownerSub});
Future<void> remove(String key, {String? ownerSub});
Future<int> removeAllForOwner(String ownerSub);          // part of wipeOwner
```

Without `ownerSub` a key belongs to the installation (install marker); with it, to the account (AI consent version seen) and `wipeOwner` removes it.

### Migrations

`docs/storage.md`, "Changing the schema", is the procedure, and it was rehearsed (see Evidence). The short form: change the table, raise `schemaVersion`, run `tool/gen.sh` and the three `drift_dev schema` commands (`dump`, `steps`, `generate`), write the step in `onUpgrade: stepByStep(...)`, run the tests. The harness needs no edit for a new version. Never re-dump an old version. Do not use `drift_dev make-migrations`: it writes `app_database.steps.dart` outside a `generated/` directory, which fails the header check.

### Decisions

- **Timestamps as integer seconds**, not drift's text mode. In text mode drift compares through `julianday()` (no index use) but orders by the ISO string, and those strings have three or six fractional digits depending on the value, which does not sort correctly. Seconds are enough for everything stored here; every ordered query has a tie-breaker.
- **`played_date` as `YYYY-MM-DD` text.** A calendar date stored as an instant shifts by a day for some time zones.
- **Application support directory**, not documents (the drift_flutter default): it is backed up as well, but never visible in the Files app, should file sharing ever be switched on for PGN import.
- **Guarded transitions that return `bool`** instead of throwing: the queue, the UI and an app resume can race, and "somebody else was faster" is a normal outcome.
- **Cross-owner upserts are ignored** (`DO UPDATE ... WHERE owner_sub = ?`) on the three tables whose primary key is a server id.
- `onUpgrade` throws while version 1 is the only one. A database with a version the code has no step for must not be opened silently.
- `uuid` is used inside `DraftsDao.create`, so callers cannot forget or reuse `client_game_id`.

### Found on the way, not fixed (outside this work package)

`tool/check_bundled_assets.sh <relative path>`: the script changes into the assets directory (line 70) before the Firebase check does `cd "$app"` (line 129). With a relative path that `cd` fails, the failure is swallowed by `|| true`, and the Firebase section prints "none" without having looked. `pr.yml` passes exactly such a relative path (`build/ios/iphonesimulator/Runner.app`). Without an argument the script uses an absolute path and is fine. Fix: make `$app` absolute right after line 38.
