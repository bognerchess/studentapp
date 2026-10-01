---
id: WP-61
title: One button for the whole analysis
status: review
size: L
depends_on: [WP-60, backend BE-23]
blocked_by_human: []
branch: feat/wp-61-one-button-analysis
pr:
---

## Scope

WP-60 put the backend's four-stage pipeline on screen: a stage strip, an
"Analyse" button for the three free engine stages and a separate "Ask the
coach" button for the metered one. The product decision of 2026-10-01 takes
that apart again. The user must not see the pipeline at all.

One **Analyse** button calls one new mutation, `analyseGame`; the backend
chains the stages itself. The app keeps one state machine per game — idle,
analysing, ready, stale, failed — out of the new one-state view on
`GameAnalysisWorkflow` (`state`, `progress`, `targetStage`, `targetReason`).
The review opens as soon as the engine result is stored, while the coach is
still writing.

The coach quota no longer gates the button. When a gate of the coach is closed
the backend still runs the engine and says why there is no coach text
(`targetReason`); the app explains it with the sheets that already exist
(limit, e-mail, consent) and makes clear the engine analysis is running.

Files: `graphql/schema.graphql` + `graphql/operations/stages.graphql`,
`lib/core/api/{models/stage_models.dart,models/analysis_models.dart,mappers/stage_mapper.dart,stage_api.dart}`,
`lib/features/analysis_status/{domain/workflow_tracker.dart,ui/analysis_notices.dart}`,
`lib/features/game_detail/{domain/game_detail_controller.dart,ui/*}`,
`lib/features/review/ui/{review_screen.dart,review_ids.dart,coach_tab.dart}`,
`lib/features/library/{domain/library_models.dart,ui/library_row_tile.dart}`,
`lib/features/submit_queue/domain/submit_queue.dart`,
`tool/mock_server/mock_backend.dart`, the fixtures and their tests.

## Out of scope

- The review screen's own content (graph, tabs, coach cards): unchanged.
- The engine-stage mutations stay in the API layer and in the mock server; the
  backend keeps them and the one-button path does not use them.
- Push, analytics transport, drift schema: unchanged.

## Contracts

**Consumes:** `analyseGame(input: AnalyseGameInput!): AnalyseGamePayload!` and
the four new fields on `GameAnalysisWorkflow`, from backend
`feat/be-23-analyse-game` (`contracts/mobile-schema.graphql`).
**Produces:** `StageApi.analyseGame`, `AnalysisWorkflowState`,
`AnalysisTargetReason`, `WorkflowTracker.track`,
`GameDetailController.analyse` / `rerunCoach`, `runAnalyse`.

## Steps

1. Re-vendor the schema, update the pin and `SCHEMA_SOURCE.md`, extend
   `stages.graphql` with `AnalyseGame` and the four workflow fields,
   `tool/gen.sh`.
2. Models and mappers: the two open enums, the new workflow fields, `state`
   and `targetReason` on `GameWorkflowSummary` (codec version 3),
   `StageApi.analyseGame`, `AnalysisAccepted` carries the workflow.
3. Tracker: `track(gameId)` instead of `startChain`; the client-side chain,
   the rate-limit backoff and the outcome plumbing go.
4. Game detail: one card with five states, `analyse()` / `rerunCoach()`,
   `runAnalyse` and `targetReason` through the existing sheets.
5. Review: the banner collapses to coach-writing / failed / stale; the coach
   tab loses "Ask the coach".
6. Library: the engine-ready badge reads like the analysed one.
7. Mock server: an `AnalyseGame` handler that chains the stages, plus the four
   new workflow fields; fixtures and fixture tests.
8. Rewrite the tests of the removed behaviour.

## Acceptance commands

```bash
tool/gen.sh
tool/check.sh
flutter test test/core/api test/tool test/features/game_detail \
  test/features/review test/features/analysis_status test/features/library
```

## Evidence

```
$ tool/gen.sh
gen: flutter gen-l10n
gen: dart run build_runner build
  Built with build_runner/aot in 1s; wrote 9 outputs.

$ tool/check.sh
==> 1/7 dependencies: flutter pub get --enforce-lockfile
==> 2/7 format: dart format --set-exit-if-changed
==> 3/7 analyze: flutter analyze --fatal-infos
==> 4/7 licence headers: tool/check_headers.dart
==> 5/7 layer imports: tool/check_layers.dart
==> 6/7 codegen is clean: tool/gen.sh, then compare the working tree
codegen: clean
==> 7/7 tests: flutter test --exclude-tags golden
00:26 +2173 ~1: All tests passed!

OK in 35s

$ flutter test test/core/api test/tool test/features/game_detail \
    test/features/review test/features/analysis_status test/features/library
00:10 +854 ~1: All tests passed!
```

The simulator pass (German and English screenshots of the five card states) is
still open; this branch was taken to green on the gate first.

## Handoff notes

**What was removed.** The stage strip and its rows, `stageName`,
`stageFailureText`, `GameDetailIds.{askCoach,retryStage,stageStrip,stageRow}`,
`ReviewIds.stageAskCoach`, `CoachTab.onAskCoach`, the review banner's
`deepReady` / `lookingForKeyPositions` / `deepRunning` / `running` states,
`GameDetailController.{startFreeChain,retryStage,askCoach,recheckEmailAndAskCoach}`,
`runFreeChain` / `runCoachRequest` / `runStageRetry`, the tracker's whole chain
(`_chain`, `_staleStageUpTo`, `_codeOf`, `_outcomes`, `_restarted`,
`_justStarted`, the rate-limit `_floor`, `trackCoaching`), `StageStartedEvent`
and the `analysis_stage_started` event. The ARB files are append-only, so the
keys those used are still there, unused; a later pass can sweep them.

**What replaced it.** One `AnalyseGame` mutation, one `AnalysisWorkflowState`
per game, and a card with five branches. `WorkflowTracker.track(gameId)` only
watches: it fires no mutation at all, which is what the new
"it never fires a stage mutation" test pins down. It lets go once `state` says
nothing runs and every ready run id is in the cache, so the artifact of the last
stage is never missed; a game that reads IDLE for `idleGrace` polls in a row is
dropped, because a request that never landed must not leave a poller behind.

**`targetReason` replaces the quota errors on the one button.** `analyseGame`
can only answer with the fair-use limit, a missing game and an unreadable PGN.
Quota, queue cap, unverified e-mail and missing AI consent come back as
`targetReason` on the workflow *with* an accepted request, and
`analysis_request_flow.dart` runs them through the sheets that were already
there — each one now saying "Your analysis is running. Only the coach's
comments are missing." The AI-consent round trip is unchanged except that it
re-calls `analyse()`. The only path that can still be refused outright is
`runCoaching`, which is "Run the coach again" for an account without a limit.

**The mock server chain.** `AnalyseGame` decides the target (the coach when
`_coachGate()` is open, else the deep evaluation plus the reason), records it on
the `_Workflow`, and queues the first stage that is not stored. Every
`GameAnalysisWorkflow` poll then calls `_advanceChain`, which queues the next
one — so the chaining really happens on the server side of the wire. A STALE
stage is a stage to run; what stops a chain is the moves changing *after* it was
asked for (`chainStartedAt`), and a failure, which one more `analyseGame`
resumes. `progress` weights the stages by their share of the wall clock and
normalises against the target, so a chain that stops at the deep evaluation
still reaches 1.

**Deviations from the brief.** Three, all noted above: `GameDetailIds.progress`
was added as asked but `retryAnalysis` is now the failed-state button (the brief
listed both and `retryStage` as separate things); the ARB keys of the removed UI
were kept rather than deleted, because CLAUDE.md calls the ARB files
append-only; and the tracker drops an IDLE game after a few polls, which the
brief did not list among the stop conditions but which is needed now that the
app, not the tracker, starts the analysis.
