# Where `schema.graphql` comes from

`graphql/schema.graphql` is a **byte copy** of the mobile contract of the bognerchess.com backend
(`contracts/mobile-schema.graphql` in the private backend repository). That file is a pruned subset of
the Web API schema, made for this public repository: it contains only what the mobile root fields
reach. Nothing else from the backend is copied here. Never edit the copy.

| | |
| --- | --- |
| Source | backend repository, `contracts/mobile-schema.graphql` (generated there by `scripts/export-mobile-schema.sh`) |
| Backend commit | `41c2bbb` (branch `feat/staged-coaching-document`; the engine-stage rate limit and the message keys, BE-22/A3) |
| Copied on | 2026-09-30 |
| SHA-256 | `9c84b3f2d1d5c103e446e3a348c6fefb25a7a38919ce6c40cfdd8c2393b90d3d` |

Both copies of this branch are **purely additive** over the ones before them; no diff removes a
line. `48cd383` (2026-09-29) added the staged analysis surface — `engineStageRun`,
`engineStageRunsForGame`, `gameAnalysisWorkflow`, the four `run*` commands with their payloads,
inputs and error unions, the `EngineStage` and `AnalysisStageState` enums, and `progressDone` /
`progressTotal` on `AnalysisJob`. `41c2bbb` (2026-09-30) adds `RateLimitedError` to
`RunBaseEvaluationError`, `RunBaseClassificationError` and `RunDeepEvaluationError` and rewords one
description; `graphql/operations/stages.graphql` now selects `retryAfterSeconds` on all four
commands, so a rate-limited engine stage carries the server's number instead of the one-minute
fallback.

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
