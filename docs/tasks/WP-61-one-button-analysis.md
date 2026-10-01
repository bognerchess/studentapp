---
id: WP-61
title: One button for the whole analysis
status: in-progress
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

Filled in by the agent: command output, and for UI work screenshots (German and English).

## Handoff notes

Filled in by the agent: decisions taken, gotchas, anything the next session needs to know.
