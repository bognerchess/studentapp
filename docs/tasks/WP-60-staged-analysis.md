---
id: WP-60
title: Staged (progressive) analysis
status: review
size: L
depends_on: [WP-26, WP-28, WP-29]
blocked_by_human: []
branch: feat/wp-60-staged-analysis
pr:
---

## Scope

The backend now runs the analysis pipeline one stage at a time: **base
evaluation** (Stockfish, one node per ply) → **base classification** (the plies
worth a closer look) → **deep evaluation** (multi-line search on those plies)
→ **coaching** (the model writes the document). Only the last stage calls a
model, and only it is metered.

This work package moves the app onto that pipeline. One tap on "Analyse" runs
the three free engine stages back to back and the user sees each result as it
lands; a separate "Ask the coach" button starts the metered stage and is the
only step that can be refused. The staged flow replaces the whole-game path in
the app entirely (the backend keeps `requestGameAnalysis` for the web).

The steps below are the plan's B1–B14. This file is updated as they land.

- **B1 Vendoring.** `graphql/schema.graphql` from the backend's stage commands;
  the chess-ai document contract at `schema_minor` 5, which brings
  `variation.kind = "peer_line"`. Re-vendored a second time for BE-22's
  `RateLimitedError` unions and message keys.
- **B2 Operations and API layer.** `graphql/operations/stages.graphql`,
  `lib/core/api/models/stage_models.dart`,
  `lib/core/api/mappers/stage_mapper.dart`, `lib/core/api/stage_api.dart`.
- **B3 Assembler.** `lib/core/analysis/stage_document_assembler.dart`: engine
  artifacts into a document the existing `AnalysisParser` reads.
- **B4 Persistence.** drift schema 2: `cached_analyses.source/stage/stage_run_ids`
  and the `pending_workflows` table with its DAO.
- **B5 Tracker.** `lib/features/analysis_status/domain/workflow_tracker.dart`,
  which polls one workflow per tracked game, chains the engine stages and
  stores what lands.
- **B6–B10** review repository, game detail, review screen, library, submit
  queue.
- **B11** mock server and fixtures.
- **B12 Deletion of the whole-game path.** `AnalysisApi.request` / `.job` /
  `.activeJobs` and their operations, `JobInfo`, `JobTracker`, `pending_jobs`,
  `GameSummary.latestJob` and everything that read them. `JobStatus` stays,
  in `stage_models.dart`.
- **B13 Analytics and docs.** `analysis_stage_started` / `_ready` / `_failed`
  and `coach_requested`; `docs/analytics-events.md`, `docs/storage.md`,
  `docs/testing.md` and this file.
- **B14** tests, throughout.

## Out of scope

`requestGameAnalysis` stays on the server for the web client; nothing in this
work package touches the backend. The coach document format does not change.
The app gains no dependency.

## Contracts

**Consumes:** `contracts/mobile-schema.graphql` of the backend at `41c2bbb`
(BE-22/A3: the `RateLimitedError` unions and the message keys);
`contracts/` of chess-ai at `eaba07c` (`schema_minor` 5);
`lib/core/analysis/analysis_parser.dart`;
`lib/core/storage/app_database.dart`.

**Produces:** `StageApi`, `AnalysisWorkflow` and the stage models,
`StageDocumentAssembler`, `WorkflowTracker` with `workflowTrackerProvider` and
`trackedWorkflowsProvider`, `PendingWorkflowsDao`, and the three new columns of
`cached_analyses`.

## Steps

1. **B1** Re-vendor both contracts; `VariationKind.peerLine`; the pins.
2. **B2** The stage operations, models, mapper and `StageApi`.
3. **B3** `StageDocumentAssembler`.
4. **B4** drift schema 2.
5. **B5** `WorkflowTracker`.
6. **B1b** The second re-vendor: `RateLimitedError` on the three engine
   commands, and the message keys A3 introduced.
7. **B6** The review repository reads the cache and the workflow.
8. **B7** Game detail: the stage strip, the free chain, the coach button.
9. **B8** Review: the stage banner and the engine-only tabs.
10. **B9** Library: the workflow summary, cached and badged.
11. **B10** The submit queue starts a chain.
12. **B11–B14** mock server, deletion, docs and analytics, tests.

## Acceptance commands

```bash
tool/gen.sh
tool/check.sh
tool/check_compliance.sh
flutter test test/core/analysis test/core/api test/core/storage test/features/analysis_status
dart run tool/mock_server/main.dart --port 5299 --quiet   # each scenario, through the simulator
flutter build ios --simulator --debug --dart-define-from-file=config/fake.json
flutter test integration_test -d "iPhone 17 Pro" --dart-define-from-file=config/fake.json
```

The simulator cannot be tapped from a script, so the screens below were driven
through `lib/features/game_detail/dev/flow_demo.dart`, the development entry
point WP-26-28 wrote for exactly that. It gained an `analyse` and a `coach`
step for the staged flow:

```bash
flutter build ios --simulator --debug --dart-define-from-file=config/fake.json \
  -t lib/features/game_detail/dev/flow_demo.dart
xcrun simctl launch booted com.bognerchess.mobile \
  -AppleLanguages "(de)" -flow_demo "game:game-2,analyse,wait:20,open,wait:60"
curl -X POST localhost:5299/__scenario -d '{"name":"stage_fails","stage":"DEEP_EVALUATION"}'
xcrun simctl io booted screenshot <path>
```

## Evidence

Run on 2026-09-30 on macOS 26.6 (Apple silicon), Xcode 26, Flutter 3.47.5,
iPhone 17 Pro simulator (iOS 26.5), on the branch as committed.

**The gate:**

```
$ tool/check.sh
==> 1/7 dependencies: flutter pub get --enforce-lockfile
==> 2/7 format: dart format --set-exit-if-changed
Formatted 402 files (0 changed) in 0.54 seconds.
==> 3/7 analyze: flutter analyze --fatal-infos
No issues found! (ran in 2.1s)
==> 4/7 licence headers: tool/check_headers.dart
check_headers: ok
==> 5/7 layer imports: tool/check_layers.dart
check_layers: ok
==> 6/7 codegen is clean: tool/gen.sh, then compare the working tree
codegen: clean
==> 7/7 tests: flutter test --exclude-tags golden
00:26 +2119 ~1: All tests passed!
OK in 36s
```

The count went 2193 → 2119: the whole-game path took its tests with it, and
what replaced them — the migration assertion, the tracker's publish order, the
review reload, the pipeline analytics, the library's remembered pipeline — put
some back. The one skipped test is the pre-existing one.

**The licence gate:**

```
$ tool/check_compliance.sh
==> 1/8 forbidden dependencies
  ok:   no forbidden dependency in pubspec.yaml, pubspec.lock or the SPM pins
==> 2/8 a licence row for every direct dependency
  ok:   22 direct dependencies, all with an accepted licence
==> 3/8 licence headers (tool/check_headers.dart --strict-swift)
  ok:   headers
==> 4/8 the bundled asset allow-list (tool/check_bundled_assets.sh)
  ok:   no built app given; checked the sources instead
==> 5/8 NOTICE
  ok:   NOTICE names every vendored work
==> 6/8 the source tag
==> 7/8 corresponding source
==> 8/8 reproducible build (tool/check_reproducible.sh)
1 decision(s) for the copyright holder are open; see the DECISION lines above.
check_compliance: ok (development mode), 4 note(s). Run with --release before conveying a build.
```

The four notes are the standing development-mode ones: HEAD is on no remote
branch (this work is not pushed), the App Store permission is still DRAFT
(human gate H7), and the two release-only checks did not run.

**Builds and the simulator:**

```
$ flutter build ios --simulator --debug --dart-define-from-file=config/fake.json
Xcode build done.                                           26.7s
✓ Built build/ios/iphonesimulator/Runner.app

$ flutter test integration_test -d "iPhone 17 Pro" --dart-define-from-file=config/fake.json
00:00 +0: the fixture is a legal 80-ply game with its special moves
00:00 +1: a 40-move game entered on the board gives exactly its movetext
00:09 +2: All tests passed!
```

**What the simulator showed.** `dart run tool/mock_server/main.dart --port 5299
--quiet` throughout, driven through `flow_demo` (the simulator cannot be
tapped from a script; there is no `simulator` tool in this session, so every
state below was reached with `xcrun simctl launch -flow_demo …`, `curl
localhost:5299/__scenario` and `xcrun simctl io booted screenshot`).

| State | What was on screen |
| --- | --- |
| Tap "Analyse this game" | "Analysing your game", the four rows, Engine running with a determinate bar counting plies ("2 of 8"), the other three "Not started", and the leave-the-app hint. |
| Stage 1 stored, stage 2 running | Engine "Ready", Key positions running, and **"Open analysis" appears** — minutes before the coach. |
| Chain finished | Engine / Key positions / Deep analysis all "Ready", Coach "Not started", the coach explanation, "Ask the coach", "3 of 3 analyses left today · resets at 2:00 AM", "Open analysis". |
| Review opened while stage 2 ran | The engine assembly: eval graph with key-moment markers, glyphs on the moves, the banner "Engine analysis ready. Looking for key positions…", opened on Moves rather than an empty Coach tab. |
| Coach running | Accuracy 92 % / 90 % in the header, banner "Your coach is writing…". |
| Coach done | The screen switched to the Coach tab, "The moments that mattered", banner gone. |
| `stage_fails` with `DEEP_EVALUATION` | "This step failed" / "An earlier step has to run again.", Deep analysis "Failed", "Try this step again" **and** "Open analysis" — the engine result stays readable. |
| `limit_reached`, then "Ask the coach" | The day-limit sheet: "Daily limit reached", the three-a-day sentence, the reset time, "Your game is saved…". |

The German "Dein Coach schreibt…" banner has no screenshot: the mock finishes
a coaching run within one poll at the settings used, so the screen was already
showing the document by the time the shot was taken. The English one caught it,
and the German string is asserted in `review_screen_test.dart` ("the coach is
writing", German group).

`rate_limited` and `stale` were exercised against the mock server rather than
through the simulator: both are covered end to end in
`test/core/api/repositories_mock_server_test.dart` ("the staged chain refuses:
a failing stage, a rate limit, and stale moves") and in the mock server's own
test, and neither has a screen of its own that the states above do not show.

**Screenshots** (`docs/tasks/evidence/WP-60/`, iPhone 17 Pro, dark):

| File | |
| --- | --- |
| `en-strip-running.png` / `de-strip-running.png` | the stage strip while the engine runs |
| `en-strip-stage2.png` | stage 1 stored, stage 2 running, "Open analysis" there |
| `en-engine-ready.png` / `de-engine-ready.png` | engine ready, the coach button and the quota line |
| `en-review-banner-engine.png` / `de-review-banner-engine.png` | the review banner on an engine-only analysis |
| `en-review-banner-coach-writing.png` | the banner while the coach writes |
| `en-review-coach-ready.png` / `de-review-coach-ready.png` | the coach's document |
| `en-stage-failed.png` / `de-stage-failed.png` | a failed step with its retry |
| `en-limit-sheet.png` / `de-limit-sheet.png` | the day limit |

**Two bugs the simulator found**, both fixed on this branch with a regression
test each (`470beb4`, `18fffcf`):

1. The listen that reloads the review when a stage lands sat in `_ReviewBody`,
   which only exists once a document has loaded. A review opened during the
   first engine stage therefore showed "Something went wrong" and stayed there.
2. The tracker published a stage as READY *before* it had fetched and stored
   that stage's artifact, so the screen that reacted looked into an empty
   cache. The artifacts are stored first now.

Neither was reachable from a widget test as the tests were written, which is
what the simulator run is for.

## Handoff notes

**B1.** The mobile schema copy is purely additive over the previous one, so
`tool/gen.sh` was green on the new schema before a single new operation
existed — that is the check the plan asked for, and it means the second
refresh for BE-22 will be a copy and a checksum.

The chess-ai contract jumped four minors at once (1 → 5). Only one change
reached the code: `variation.kind = "peer_line"`, a line showing what players
of the same rating tend to play. It is styled muted and informational in the
line panel and drawn with the hint arrow, never the best-move green, because
it is not a recommendation. Its first move comes from the human model and the
rest from the engine, and it starts at the node's `fen_before`, so the parser
treats it like `best_line` and `alternative` when it checks where a line
begins. Everything else the four minors added (`variation.source` / `elo` /
`elos` / `human_prob`, `node.time`, `game.time_control`) is read past by the
tolerant parser.

`contracts/SHA256SUMS` upstream now pins `job-api.v1.json` as well, which is
the contract between chess-ai and the backend and has no business in this
repository. `vendored_fixtures_test.dart` therefore checks the four files the
app vendors rather than every line of `SHA256SUMS`.

**B2.** Three deviations from the plan, all forced by the schema as it stands
today.

1. `RateLimitedError` is not a member of the three engine commands' error
   unions yet (BE-22 adds it), so the operations cannot select it — selecting
   a type that is not in the union fails codegen. The commands therefore
   select only the three generic members, and the second re-vendor adds the
   block plus `retryAfterSeconds`. The *mapping* already works: a
   `RateLimitedError` on one of those commands reads its `__typename` through
   the generated unknown-member class and comes out as `AnalysisRateLimited`,
   only with the one-minute fallback instead of the server's number. There is
   a fixture and a test for exactly that, because the backend may ship A3
   before this app re-vendors.
2. The plan's `AnalysisAccepted(StageRun run, AnalysisStage stage)` would have
   changed the member the whole-game path still uses. The staged answer is a
   new member, `AnalysisStageAccepted(StageRun run)`; B12 deletes
   `AnalysisAccepted` and this one takes its name. The three exhaustive
   switches over the sealed outcome (game detail, its request flow, the submit
   queue) got a case each that cannot be reached from `requestGameAnalysis`.
3. `gameAnalysisWorkflow` is non-null in the schema, so a game that is gone or
   is somebody else's comes back as a *top-level* GraphQL error, and the
   backend's error filter strips it to a bare message with no code. `workflow()`
   reads null from that message — the key BE-22 introduces, or the English
   sentence the resolver sends today — and rethrows anything else, so a cost
   or validation problem is never mistaken for a deleted game. A fixture whose
   body is a top-level error also needed `fixtures_test.dart` to skip the
   `fromJson` round trip for it.

`StageApi.workflow` returning null is what lets the tracker untrack a game;
`artifact()` uses `kAnalysisApiTimeout` because one artifact is hundreds of
kilobytes, which is also why the workflow query selects no artifact at all.

Not in the plan but needed: `lib/features/review/dev/demo_analysis.dart`
carries a copy of `short-game.json`, and `review_providers_test.dart` compares
the two byte for byte. The copy was regenerated from the new fixture. Its
comment and lesson ids did not change, so the German texts next to it still
match.

**B3.** `StageDocumentAssembler` is pure and total: it never throws and never
touches an artifact. With no usable nodes it returns a document with an empty
`nodes` list, which the parser then rejects — the caller parses before it
stores, so there is no second place that decides what "valid" means.

The one real shape difference is `engine`: stage 3 writes it flat
(`pass1_nodes`, `pass2_nodes`, `pass2_multipv`), the document nests it. A key
that is not in the artifact is left out rather than guessed.

`is_critical` has three sources and they must not fight: stage 1 sets it false
everywhere, stage 2's selections stand in until stage 3 lands, and stage 3's
nodes carry the settled value. So `build` applies `criticalPlies` only when
there is no deep artifact, and `withCriticalPlies` — the in-place patch for
"stage 2 finished before stage 3" — is idempotent and also clears a mark that
a re-run of stage 2 no longer picks.

The stage fixtures are generated from the vendored forty-move game by a
committed `make_fixtures.py`. Two things in them are deliberate: the stage-2
selection holds two plies more than stage 3 keeps, so "superset" is visible
rather than asserted; and one `peer_line` is added per critical node, because
the vendored fixtures are minor 5 but happen to contain none, and the app has
to carry that kind through without mistaking it for a recommendation.

The `!` glyph on a positive moment needs a comment, so it stays absent until
the coach has run. That is a gap the staged flow cannot close on the engine
stages alone.

**B4.** Schema 2, and the first real migration this app has: three columns on
`cached_analyses` and the new `pending_workflows` table. `docs/storage.md` now
uses it as the worked example instead of an invented one, and says the two
things it teaches — a new column needs `withDefault` both to be legal on a
table with rows and to make an old row keep its meaning, and an index a new
table declares has to be created next to `createTable`.

`AnalysisCacheDao.put` became `putCoach`, so the plan's split is also a rename
at the five call sites that had it. `putEngine` returns whether it wrote:
the guarded upsert is silent about what it did, and the two things it refuses
to touch look the same from outside — a coach document, and a row of another
owner. It reads the row back inside the transaction to tell the caller.

`pending_workflows` keeps one row per game, not per run, and its `target_stage`
is the *wire* name of `AnalysisStage` rather than the enum: the storage layer
does not know types from `lib/core/api/models/`, and a `textEnum` there would
have put the pipeline's shape into the schema.

`migration_test.dart` gained a group that inserts a version-1 row through
`schema.rawDatabase`, migrates, and checks what the row now means — that it
reads as a coach document and that an engine assembly still cannot write over
it. The generated `from 1 to 2` case only compares the shape of the schema.

**B5.** The tracker keeps `JobTracker`'s shape — the same gating, the same
3 s / ×1.5 / 30 s cadence, the same single-flight poll — and changes what one
tick is: one `gameAnalysisWorkflow` per watched game, then artifacts, then the
next stage. Its public surface is `workflows`, `events`, `setOwner`,
`setForeground`, `refreshNow`, `startChain` and `trackCoaching`.

Three decisions worth knowing.

`startChain` does not fire a mutation itself. It writes the `pending_workflows`
row and calls `refreshNow()`, and the poll that follows starts the right stage.
That is one extra query before the first one goes out, and in exchange there is
exactly one place that decides which stage is next — so "Analyse" on a game
whose base evaluation is already stored starts the classification rather than
running stage 1 again.

A pipeline that went stale stops with `WorkflowState.failed` and a
`WorkflowStaleEvent`. `failed` in that column means "the tracker stopped and
the user has to act", which covers both a stage that failed and moves that
changed; which of the two it was comes off the workflow, not off the row. The
chain deliberately does not re-run a stale stage: the server reports it as
runnable, and firing it would re-analyse behind the user's back.

A ready coaching stage short-circuits the artifact work. The server has the
whole document in that case, so assembling one from the engine artifacts would
cost a fetch of hundreds of kilobytes and be replaced in the same tick.

Deviations:

- **Nothing reads `workflowTrackerProvider` yet.** `AnalysisNotices` carries a
  TODO instead of a second `ref.watch`. Wiring a poller into the app shell
  before any screen starts a chain would only add timers to every widget test,
  and there is nothing to resume until B7 and B10 exist. The snackbar policy
  the plan names (deep evaluation ready, coach ready, failures) goes in with
  that wiring, where its ARB keys are written anyway.
- **The library summary is in memory only.** `GameWorkflowSummary` and
  `trackedWorkflowsProvider` are there, but persisting the summary next to the
  cached game needs `game_summary_codec` version 2, which is B9. `applyAnalysis`
  was added to `GamesRepository` now, because the coach document arriving has
  to flip the badge and there is no job to record on the staged path.

Two bugs the tests found, both worth remembering: `{for (…) ?entry}` where
`entry` is a `MapEntry?` is a **set** of entries, not a map, and the analyzer is
happy with it in a `Map<String, dynamic>` position — it only blows up at
`jsonEncode`. It was in `GameWorkflowSummary.toJson` and in the tracker's run-id
column; both are written out as loops now, and the round trip is a test.

**B1b, the second re-vendor.** The backend's `41c2bbb` makes the diff over
`48cd383` three union members and one reworded description, so the copy, the
checksum and `... on RateLimitedError { retryAfterSeconds }` on the three
engine mutations was all of it. Two tests that documented the fallback now
assert the server's number instead: a rate-limited engine stage says 42 s in
`stage_api_test.dart` and the tracker waits the 90 s of
`workflow_tracker_test.dart`, not a flat minute.

The keys arrived one letter off the plan: `EntityNotFound` is
`api_errors.entity_not_found`, not `web_api_errors.entity_not_found`.
`StageApi._isGameGone` matches on the `entity_not_found` substring, so it
reads both and needed no change. `web_api_errors.pgn_invalid` comes as an
`InputValidationError` on `chessGameId` and stays a plain failure: the user
cannot fix a stage by retrying a game with no moves, and the submit path
already refuses those.

**B6.** The review repository's order of preference is coach document, engine
assembly, `gameAnalysis`, nothing; `source` travels to the screen on
`ReviewData` so the tabs can say where the text is.

The plan's "run-id staleness rule" needed a place to keep the coach's run id,
because the document itself carries none and `gameAnalysis` always serves the
newest. `cached_analyses.stage_run_ids` was already there and nullable, so a
coach row now holds `{"COACHING": "<run id>"}` — no schema change, and the
tracker records the same thing. A coach row *without* a recorded run (the
whole-game path writes those) is never refetched: it is already the best kind
of document, and there is nothing to compare.

The tracker had a matching hole. `_followCoaching` returned early on any
stored coach row, so a second coaching run would never have been picked up;
it now compares the run id as well.

Two things the repository deliberately does not do. It **never fetches an
artifact** — those are hundreds of kilobytes and the tracker owns them — so a
device with no stored assembly and an unfinished coaching stage shows
"not available", exactly as before. And it asks for the workflow only when the
answer could change what happens next: with nothing cached the document is
fetched either way, so that cold open costs one query, not two. A workflow
query that fails is "nothing known", so the screen still opens offline.

**B7.** The game screen now shows the pipeline, not a job. `_AnalysisCard`
reads `trackedWorkflowsProvider[gameId]` and picks one of six shapes — nothing
run, running, engine ready, coach ready, a failed step, moves changed — and
`_StageStrip` under it lists the four stages with a state each. "Open
analysis" appears as soon as any engine stage is stored, which is the whole
point of the staged flow: the eval graph is there minutes before the coach is.

The progress bar is back, deliberately. WP-26-28 decided against one because
there was a single opaque job and a bar would have been decoration; each stage
now reports `progressDone` / `progressTotal`, so the bar shows something real
and falls back to indeterminate only on the stage that is moving.

Three deviations.

1. **The tracker needed a retry path.** The plan says `retryStage` on an engine
   stage is `startChain` again, because the server reports a failed stage as
   runnable and `nextRunnableStage` names it. But B5's tracker stops the
   moment it sees a failed or stale stage, so the retry did nothing: one poll,
   one bail-out. `startChain` now marks the game as restarted and the next
   tick gets exactly one attempt at whatever is runnable, failed or stale
   included. Everything after that tick behaves as before, so a stage that
   fails twice still stops the chain, and nothing re-analyses behind the
   user's back.
2. **`startChain` returns the outcome** of the stage command the poll fired
   (null when nothing was started). Without it there was nowhere to explain a
   refusal: the button writes a row, the *poll* fires the mutation, and a
   rate-limited or refused engine stage would have left the card looking as if
   the tap had not registered. It is one field on the tracker, cleared as it
   is read.
3. **The card's fallback for a cold open is still only `hasAnalysis`.** The
   plan wants the library row's remembered summary, and the parameter is there
   with a TODO; it needs `game_summary_codec` version 2, which is B9.

`workflowTrackerUiMountedProvider` is its own provider rather than the job
tracker's, so a test can run one poller without the other; `pumpApp`'s
`jobPolling` gates both, and `pollingOverrides()` in `pump_app.dart` turns
them on for a screen test — which the staged flow needs, because "Analyse"
only works if something is polling.

`AnalysisNotices` now listens to both trackers. The staged snack bars are the
three the plan names: the deep evaluation is ready, the coach is ready (the
same text the job path uses), and a step failed or the moves changed. Stages 1
and 2 say nothing — the card and the review banner fill in where the user is
already looking, and four snack bars per game would be four interruptions.

**B8.** The review screen carries a one-line stage banner above the tabs, and
knows whether what it is showing is the coach's document or an engine
assembly. `ref.listen` on the workflow's ready run ids reloads the data when a
stage lands, so a screen left open fills in.

Three things worth knowing.

The banner's "Ask the coach" is the *same* flow as the game screen's, reached
through a new `lib/features/game_detail/game_detail.dart` barrel — the pattern
`usage.dart` already sets, because the layer check forbids importing another
feature's `ui/` directly. One place explains a quota refusal, an unconfirmed
address and a missing consent; duplicating those sheets into the review feature
would have been the alternative. The screen keeps the game controller alive
with a `ref.listen` that ignores its value, which costs one `GameById` request
per review open.

A reload no longer flashes the skeleton. `ReviewScreen` used to match
`AsyncData` only, so every invalidation replaced the screen with the loading
shape; it now keeps a document that is being refreshed. What it does *not*
keep is the reading position: `ReviewController.build` watches the data, so a
stage that lands resets the ply and the tab. That is at most three times per
game and only while the pipeline runs, so it is left as it is — worth
revisiting if it ever annoys somebody.

The opening tab follows the source. An engine assembly with no comments opens
on Moves, because the coach tab would be one engine fact per move and nothing
else; its terminal button becomes "Ask the coach" instead of "See your
lessons", and the summary tab says "The coach has not written yet." rather than
"There are no lessons for this game." — a coach who found nothing to say is a
different thing from a coach who has not run.

**B9.** `GameSummary` gains `workflow`, a `GameWorkflowSummary` the tracker
writes next to the cached game on every poll that changed something.
`game_summary_codec` is version 2; a version-1 row reads as a game whose
pipeline this device knows nothing about, which is what it was. `LibraryStatus`
gains `engineReady`, badged "Engine analysis", and `statusOfGame` takes the
summary.

`latestJob` stayed for the length of B9 — removing it would have broken the
whole-game path, the mapper, the job tracker, `applyJob` and their tests — so
`workflow` sat beside it with a TODO, and so did `LibraryGameRow.job` and
`statusOfGame`'s `job` parameter. B12 took all four.

The order in `statusOfGame` is worth reading once: work in flight beats a
stored result (a game being analysed again reads as "analysing", as it did
before), the coach's document beats everything else, a failed step beats a
readable engine analysis — the same choice the game screen's card makes — and
stage 1 alone is not `engineReady`, because there are no variations and no
accuracy yet.

**Not in the plan, and needed.** The server's game list and `myChessGameById`
carry no workflow, so every library refresh and every game-screen open was
about to overwrite the cached summary with null and blank the badge until the
next poll. `CachedGamesRepository` now puts the remembered pipeline back in
`fetchPage`, in `put` and — this one is the easy one to miss — in the value
`fetchDetail` *returns*, not only in what it stores: the game screen shows what
it got back, not what went into the database. `GameDetail.withWorkflow` exists
for that.

**B10.** "Save & analyse" now starts the free chain: a `pending_workflows` row
(before the mutation, so a kill resumes it) and `runBaseEvaluation`. The coach
is never asked from the queue. `lib/core/analysis/analysis_job_sink.dart`,
`SubmitQueue._jobSink` and `RecordingJobSink` are gone, as WP-26-28's handoff
recommended, and with them the queue's `coachLanguage` callback and the
`coachLanguageOf(String)` helper in `submit_queue_providers.dart`, which nothing
but its own test still used.

Only two `AnalysisHold` values are reachable from here now: `rateLimited` (fair
use on the engine commands) and `requestFailed`. The others stay in the enum
and in the sentences, because the coach path on the game screen produces them
and a draft row written by an older build may still carry one. The parametrised
test in `submit_queue_test.dart` was cut to the two.

One behaviour changed that the plan does not mention. The new-game flow still
asks for AI consent before "Save & analyse", and it still saves the game when
that check cannot reach the server — but the analysis is no longer held for it,
because the free stages need no consent. A consent that is genuinely missing is
now collected on the way to the coach, where it belongs. Worth a product look:
the consent prompt in the save flow is early by one step.

**B12.** The whole-game path is gone from the app. `AnalysisApi` keeps
`analysis` and `submitFeedback`; `request`, `job` and `activeJobs`, the three
operations, `JobFields` and `latestAnalysisJob` went, and
`AnalysisStageAccepted` took the name `AnalysisAccepted` back, which removed
the unreachable case from the four sealed-outcome switches.

Five decisions worth keeping.

`JobStatus` stayed and moved to `stage_models.dart`, where the thing it
describes now lives. It is still named after the schema's
`AnalysisJobStatus`, which the stage commands share with the web client's
jobs, so the name is the contract's rather than a leftover.

`pending_jobs` is dropped by the 1→2 migration **by name**
(`m.deleteTable('pending_jobs')`): the class is gone, so the version-2
snapshot no longer describes it and `schema.pendingJobs` would not compile.
Version 2 has never shipped — this branch created it — so its dump and the
generated helpers were rewritten rather than a version 3 invented. Nothing is
carried over; those rows were ids of jobs the old poller watched.
`migration_test` now asserts the table is gone.

A version-1 cached game row keeps its `job` key and it is **read past**. The
plan allowed either that or keeping `jobFromJson`; dropping it is the honest
one, because that job was transient state of a pipeline the app no longer
drives and the badge never depended on it. `docs/storage.md` says so.

`GamesCacheDao.remove` used to delete the game's `pending_jobs` rows. It now
deletes its `pending_workflows` row, which nothing did before: a deleted game
was polled once more before the tracker untracked it.

`repositories_fixture_test` lost the two whole-game groups, which
`stage_api_test` covers stage by stage; the one case it did not cover, a typed
error without its fields, moved there. `analysis_notices_test` was rewritten to
drive the workflow tracker over a scripted pipeline, because the old half
handed a finished job to a tracker that no longer exists.

**B13.** The five pipeline events are fired from one place,
`lib/core/analytics/analysis_analytics.dart`, an extension on `Analytics`.
`analysis_requested` is **derived** there: `stageStarted` fires it whenever the
stage it was given is the base evaluation. The staged pipeline has no single
"request", so the first stage is the definition, and one function deciding it
is what stops the two counts from drifting apart.

`source` is recorded by whoever knows what asked: `game_detail` and
`game_detail_coach` by `GameDetailController`, `submit_queue` by `SubmitQueue`
(which gained an `Analytics` parameter, a no-op by default so no test had to
change), and `chain` by `AnalysisNotices`. That last one needed a new tracker
event, `StageStartedEvent`, with a `chained` flag: the tracker fires *every*
engine mutation, including the first one, so without the flag a stage the user
started would be counted twice — once by the caller that got the outcome back,
once by the notices widget.

`analysis_stage_ready` carries `duration_s`, which the tracker now computes
from the run's `requestedAt` and `finishedAt` and hands over on
`StageReadyEvent`. `AnalysisNotices` counts ready and failed stages for **every**
watched game, including the one whose screen is open: the snack bar is
suppressed there, the count is not.

`analysis_limit_hit` is unchanged and can now only come from the coach, which
is the only metered step. Its property is `window` (`day` / `month` /
`unknown`), not the `limit_kind` the catalogue planned; the catalogue says so
now. The backend has no client-event allow-list to extend — it only has
server-written constants — so there is no cross-repo change, as the plan
expected.

`analysisReadyListenerProvider` is still the no-op it always was; nothing in
`app.dart` overrides it. Its documentation now says what an override would do
(`ref.read(workflowTrackerProvider).refreshNow()`, one line) and that the
staged pipeline has no push of its own yet.

`flow_demo.dart` gained an `analyse` and a `coach` step, which is what made
the simulator evidence possible at all; `request` was renamed to `coach`.

**Two bugs this work package's own simulator run found**, both fixed here with
a regression test:

1. `470beb4` — the listen that reloads the review when a stage lands lived in
   `_ReviewBody`, which only exists once a document has loaded, so a review
   opened during the first engine stage showed "Something went wrong" and
   stayed there.
2. `18fffcf` — the tracker published a stage as READY before it had stored
   that stage's document, so whatever reacted looked into an empty cache. The
   artifacts are stored first now.

Both are worth remembering as a shape: a listener that only exists in the
success state, and a publish that runs ahead of the data it announces.

**What is left for later.**

- The backend gaps the plan listed are unchanged: coaching-stage limit hits do
  not call `RecordLimitHitAsync`; `myAnalysisUsage.queuedJobs` counts
  `analysis_job` rows only, so it reads 0 on the staged path (the mock server
  reports the number it actually enforces instead, and says why in a comment);
  there is no per-person cap on active `engine_stage_run` rows; `engine_ms` is
  under-reported in the unit-cost metric; `PersonErasureService` deletes
  `engine_stage_run` only through the game cascade.
- **No push on staged completion.** The app polls while it is in the
  foreground; a coaching run that finishes in the background is picked up on
  the next open. `analysisReadyListenerProvider` is where that would be wired.
- **"Adopt a job started on the web" is gone.** There is no active-workflows
  root field, so the app only learns of an analysis somebody else started
  through `hasAnalysis` on the next library refresh.
- **The `!` glyph on a positive moment needs a comment**, so it stays absent
  until the coach has run — a gap the engine stages cannot close.
- **The review resets the reading position** when a stage lands, because
  `ReviewController.build` watches the data. At most three times per game and
  only while the pipeline runs; worth revisiting if it annoys anybody.
- **The consent prompt in the save flow is early by one step.** "Save &
  analyse" still asks for AI consent although the free stages need none; the
  coach collects it where it belongs. Worth a product look.
- The progress-bar reversal (WP-26-28 decided against one, this one brings it
  back because each stage reports real numbers) and `variation.kind =
  peer_line` are recorded above under B1 and B7.


**An account whose usage policy is unlimited gets a "Run the coach again"
affordance** on a game whose coaching stage is already READY — in the game
screen's analysis card (`GameDetailIds.rerunCoach`) and in the review screen's
stage banner (`ReviewIds.stageRerunCoach`), both through the same
`runCoachRequest` flow — so that the coach's voice can be developed and the
new text read in place from the phone; a default account sees nothing, because
every run supersedes the old one at the cost of one quota (BE-21/BE-22).
