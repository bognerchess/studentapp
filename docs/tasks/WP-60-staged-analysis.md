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
  `variation.kind = "peer_line"`.
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

**Consumes:** `contracts/mobile-schema.graphql` of the backend at `48cd383`
(a second refresh is pending for BE-22's `RateLimitedError` unions);
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
6. **B6–B14** as listed above.

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

Not in the plan but needed: `lib/features/review/dev/demo_analysis.dart`
carries a copy of `short-game.json`, and `review_providers_test.dart` compares
the two byte for byte. The copy was regenerated from the new fixture. Its
comment and lesson ids did not change, so the German texts next to it still
match.
