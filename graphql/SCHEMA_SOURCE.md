# Where `schema.graphql` comes from

`graphql/schema.graphql` is a **byte copy** of the mobile contract of the bognerchess.com backend
(`contracts/mobile-schema.graphql` in the private backend repository). That file is a pruned subset of
the Web API schema, made for this public repository: it contains only what the mobile root fields
reach. Nothing else from the backend is copied here. Never edit the copy.

| | |
| --- | --- |
| Source | backend repository, `contracts/mobile-schema.graphql` (generated there by `scripts/export-mobile-schema.sh`) |
| Backend commit | `1517aa8` (`main`, PR #22; `analyseGame` and the one-state view of the workflow, BE-23) |
| Copied on | 2026-10-01 |
| SHA-256 | `3020ccdba55f84200d22a994bd341633cb14b81a326fc4e5bc1529ce3e7e4d8b` |

Both copies of this branch are **purely additive** over the ones before them; no diff removes a
line. `48cd383` (2026-09-29) added the staged analysis surface — `engineStageRun`,
`engineStageRunsForGame`, `gameAnalysisWorkflow`, the four `run*` commands with their payloads,
inputs and error unions, the `EngineStage` and `AnalysisStageState` enums, and `progressDone` /
`progressTotal` on `AnalysisJob`. `41c2bbb` (2026-09-30) adds `RateLimitedError` to
`RunBaseEvaluationError`, `RunBaseClassificationError` and `RunDeepEvaluationError` and rewords one
description; `graphql/operations/stages.graphql` now selects `retryAfterSeconds` on all four
commands, so a rate-limited engine stage carries the server's number instead of the one-minute
fallback.

`1517aa8` (2026-10-01, BE-23) adds the one-button surface WP-61 is built on: the mutation
`analyseGame` with `AnalyseGameInput`, `AnalyseGamePayload` and the error union `AnalyseGameError`
(`RateLimitedError`, `BusinessError`, `InputValidationError`, `TechnicalError`), the enums
`AnalysisWorkflowState` and `AnalysisTargetReason`, and four fields on `GameAnalysisWorkflow`:
`state`, `progress`, `targetStage` and `targetReason`. Quota, queue cap, rate limit, unverified
e-mail and missing AI consent are never errors of `analyseGame`; the engine result is produced
anyway and `targetReason` says why the chain stopped short of the coach. The same change notes that
`run.language` is now set on the engine stages of a chained analysis, which hand it on to the coach.

The same backend change also turned three raw English sentences into message keys:
`api_errors.entity_not_found` for a game that is gone, `web_api_errors.stage_prerequisite_missing`
for a stage asked for before the one it builds on, and `web_api_errors.pgn_invalid` — sent as an
`InputValidationError` on `chessGameId` — for a game without moves. The first two are mapped in
`stage_api.dart`; the third is a plain failure, like every other validation error.

`test/core/api/schema_pin_test.dart` pins the checksum, so a change of the file is always a
deliberate refresh and never an accident.

## Refreshing

```bash
SRC=<checkout of the backend>/contracts/mobile-schema.graphql
cp "$SRC" graphql/schema.graphql
shasum -a 256 graphql/schema.graphql                      # new checksum
git -C "$(dirname "$SRC")" rev-parse --short HEAD         # new source commit
```

1. Put the checksum into `kSchemaSha256` in `test/core/api/schema_pin_test.dart` and into the table
   above, together with the commit and the date.
2. `tool/gen.sh`. The generator validates every operation in `graphql/operations/` against the new
   schema; a removed or renamed field fails here.
3. `flutter analyze`: a changed type shows up in `lib/core/api/mappers/` and the repositories. New
   enum values and new members of an error union need no change to keep working (they read as
   `unknown` or as a generic failure), only to be handled specifically.
4. Bring the fixtures in `test/fixtures/graphql/` in line (`make_fixtures.py` there) and run
   `flutter test test/core/api test/tool`. `fixtures_test.dart` fails when a fixture lacks a field an
   operation selects, and when an error union has a member without a fixture (update `_errorUnions`
   there).
5. Commit schema, generated code, fixtures and the pin together.

## How the code is generated

`graphql_codegen` (see `build.yaml`) reads `graphql/schema.graphql` and `graphql/operations/*.graphql`
and writes `lib/core/api/generated/**.graphql.dart`. The generated code is committed, and
`tool/check.sh` fails when it is stale.

| Schema | Dart |
| --- | --- |
| `DateTime` | `DateTime`, always UTC (`lib/core/api/scalars.dart`) |
| `LocalDate` | `String` in generated code, `GameDate?` in the domain models; malformed reads as null |
| `Any` | `Object` (decoded JSON): the analysis document, event properties |
| `ID`, `UUID` | `String`, opaque |
| enums | generated enums with a `$unknown` fallback for values a newer server sends |
| error unions | one generated class per member plus a base class for unknown members |

`__typename` is only selected where a union needs it (`errors { __typename … }`): nothing is
normalised into a cache. Only `lib/core/api/` may import the generated files; the rest of the app
sees the domain models in `lib/core/api/models/`.
