---
id: WP-60
title: Staged (progressive) analysis
status: in-progress
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
- **B11** mock server and fixtures. **B12** deletion of the whole-game path.
  **B13** analytics and docs. **B14** tests.

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
flutter test test/core/analysis test/core/api test/core/storage test/features/analysis_status
dart run tool/mock_server/main.dart --port 5299   # each scenario, through the simulator build
flutter build ios --simulator --debug --dart-define-from-file=config/fake.json
flutter test integration_test -d "iPhone 17 Pro" --dart-define-from-file=config/fake.json
tool/check_compliance.sh
```

## Evidence

Filled in by the agent: command output, and for UI work screenshots (German and English).

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
gains `engineReady`, badged "Engine analysis", and `statusOfGame` now takes the
summary as well as the job.

`latestJob` stays. Removing it breaks the whole-game path — the mapper, the job
tracker, `applyJob` and their tests — so `workflow` sits beside it with a
TODO for B12, and so does `LibraryGameRow.job` and `statusOfGame`'s `job`
parameter.

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

**What B12 still has to delete, and where it is referenced.**

| Symbol | Hand-written files that still name it |
| --- | --- |
| `AnalysisApi.request` / `.job` / `.activeJobs`, the `RequestGameAnalysis`, `AnalysisJob` and `MyActiveAnalysisJobs` operations | `lib/core/api/analysis_api.dart` (`AnalysisApi.analysis` and `submitFeedback` stay) |
| `AnalysisAccepted`, `JobInfo`, `jobOf` | `lib/core/api/models/analysis_models.dart`, `lib/core/api/mappers/game_mapper.dart`, `lib/core/api/games_api.dart`; the sealed-outcome switches in `workflow_tracker.dart`, `game_detail_controller.dart`, `analysis_request_flow.dart` and `submit_queue.dart` each carry one unreachable case for it |
| `JobStatus` | keep it: `StageRun`, `StageRunSummary` and `stageRunOf` use it. The plan's note applies — move it to `stage_models.dart` |
| `JobTracker`, `job_tracker.dart`, `job_tracker_providers.dart` (`jobTrackerProvider`, `trackedJobsProvider`, `newestJob`, `jobTrackerUiMountedProvider`, `JobTrackerUiMounted`) | `analysis_notices.dart` (its second listener and the second mounted provider), `library_controller.dart` (`newestJob`, `trackedJobsProvider`), `pump_app.dart` (`jobPolling`, `_NeverMounted`, `_AlwaysMounted`) |
| `GameSummary.latestJob`, `LibraryGameRow.job`, `statusOfGame`'s `job`, `gameSummaryWith`'s `latestJob`, `GameSummaryCodec.jobToJson` / `jobFromJson` and the `job` key | `game_models.dart`, `game_mapper.dart`, `game_summary_codec.dart`, `library_models.dart`, `library_controller.dart`, `cached_games_repository.dart` |
| `GamesRepository.applyJob` and its implementation | `games_repository.dart`, `cached_games_repository.dart`, `job_tracker.dart` |
| `pending_jobs` (`tables/pending_jobs.dart`, `daos/pending_jobs_dao.dart`) | `job_tracker.dart` only; the table is already dropped by the 1→2 migration |
| `JobFields` / `latestAnalysisJob` in `graphql/operations/fragments.graphql` | `game_mapper.dart` |
| Tests of the old path | `job_tracker_test.dart`, `pending_jobs_dao_test.dart`, `analysis_notices_test.dart` (its job half), `repositories_fixture_test.dart` and `repositories_mock_server_test.dart` (the `latestJob` assertions), the `newestJob` group of `library_domain_test.dart` |

A version-1 cached game row still decodes its `job` key, so `jobFromJson` has
to survive B12 or the migration note has to say that those rows lose it. Either
is fine; the badge no longer depends on it.

**What B13 still owes.** No analytics event was added: `analysis_requested` now
fires from `startFreeChain` (source `game_detail`) and from `askCoach` (source
`game_detail_coach`), and `analysis_limit_hit` still fires on the coach
refusal only — the plan's `analysis_stage_started` / `_ready` / `_failed` and
`coach_requested` are not there yet, and neither is the `docs/analytics-events.md`
row for the new `source` values. `docs/storage.md` does not yet mention that
`cached_analyses.stage_run_ids` also holds the coaching run on a coach row.
`analysisReadyListenerProvider` is still the no-op it always was: nothing in
`app.dart` overrides it, so no push refreshes either tracker.
