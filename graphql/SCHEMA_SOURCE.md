# Where `schema.graphql` comes from

`graphql/schema.graphql` is a **byte copy** of the mobile contract of the bognerchess.com backend
(`contracts/mobile-schema.graphql` in the private backend repository). That file is a pruned subset of
the Web API schema, made for this public repository: it contains only what the mobile root fields
reach. Nothing else from the backend is copied here. Never edit the copy.

| | |
| --- | --- |
| Source | backend repository, `contracts/mobile-schema.graphql` (generated there by `scripts/export-mobile-schema.sh`) |
| Backend commit | `c2a61b8` (branch `mobile-mvp`) |
| Copied on | 2026-09-20 |
| SHA-256 | `96803b4c0e4cae0933d9a0072a0a99ac4fc930542e83d2f437f71a7369e37df8` |

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
