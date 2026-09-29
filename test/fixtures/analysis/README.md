# Analysis document fixtures

Test data for `lib/core/analysis/` (the domain model and tolerant parser of the versioned
analysis document, `bognerchess.game-analysis`).

## `v1/`: vendored, never edited here

The JSON Schema and the three official fixtures of the analysis document contract, version 1,
copied byte for byte together with their `SHA256SUMS`.

| | |
| --- | --- |
| Source | the analysis service repository (`chess-ai`, private), directory `contracts/` |
| Files | `contracts/game-analysis.v1.schema.json`, `contracts/fixtures/game-analysis.v1/*.json`, `contracts/SHA256SUMS` |
| Commit | `eaba07c` (branch `main`; `contracts/` at `schema_minor` 5, the staged pipeline), vendored 2026-09-29 |

The document format is an API fact and may be vendored. Nothing else from that repository is.

The files are stored flat, so the paths inside `SHA256SUMS` (`fixtures/game-analysis.v1/…`) do not
exist here; `test/core/analysis/vendored_fixtures_test.dart` compares by file name. That test fails
when a vendored file no longer has the pinned checksum, and when the directory contains a file the
app does not vendor.

`SHA256SUMS` pins one file more than this directory holds: `job-api.v1.json`, the contract between
that service and the backend. The app never sees it, so it is not copied and the test checks the
four files it does vendor.

**What minor 1 → 5 brought** (all additive; a document of a higher minor needs no app release).
The one change the app had to answer is `variation.kind = "peer_line"`: what players of the same
strength tend to play, with the first move from the human model and the rest from the engine. It
needed `VariationKind.peerLine` and the two exhaustive switches in `lib/features/review/`, where it
is styled muted and informational, never as a recommendation. Everything else is read past by the
tolerant parser: `variation.source` / `elo` / `elos` / `human_prob`, `node.time`
(`clock_after`, `is_snap`, `is_long_think`) and `game.time_control`.

| Fixture | What it covers |
| --- | --- |
| `short-game.json` | 21 plies, Black's perspective, two mistakes and a blunder, ends in checkmate (`eval_after: {"mate": 0}`) |
| `forty-move-game.json` | 80 plies, 7 critical moments and 1 positive moment, mate scores in the last 20 plies, resignation |
| `fallback-case.json` | 33 plies, no human model (no `human` objects), one `regenerated` and one `fallback` comment |

### Re-vendoring

When the contract changes (its owners announce it; a new `schema_minor` needs no app release):

```bash
SRC=<checkout of the analysis service>/contracts
cp "$SRC/game-analysis.v1.schema.json" "$SRC/SHA256SUMS" "$SRC"/fixtures/game-analysis.v1/*.json \
  test/fixtures/analysis/v1/
git -C "$SRC" rev-parse --short HEAD      # goes into the table above
python3 test/fixtures/analysis/forward-compat/make_fixtures.py
flutter test test/core/analysis
```

A new fixture has to be added to `officialFixtures` in `test/core/analysis/analysis_fixtures.dart`.
A new major version gets its own directory (`v2/`) and its own parser work package.

## `forward-compat/`: hand-made

Derived from `v1/short-game.json` by `make_fixtures.py` (all chess in them is copied from the
vendored fixture). They are not part of the contract and not pinned.

| Fixture | What it covers |
| --- | --- |
| `v1-with-unknowns.json` | Major 1 with `schema_minor: 7`: unknown top-level keys, extra fields inside nodes, evals, variations, comments and lessons, and unknown values for `classification` (ply 3), variation `kind` (`v12-plan`), comment `type` (a comment on ply 2), `theme`, square `role`, arrow `role`, `verification.status` and `engine.human_model`. Must parse as a supported document. |
| `v2-major.json` | A made-up `schema_version: 2` with a changed node shape (nested evals in another unit, `classification` as an object, variations as UCI strings, comments replaced by an `annotations` map). Must come out as "newer major" with the 21 moves readable. |
