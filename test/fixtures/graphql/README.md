# GraphQL response fixtures

`<Operation>/<scenario>.json`: the body of a GraphQL response (`{"data": …}`) for every operation in
`graphql/operations/` and for every member of every error union. All data is invented.

Three consumers read the same files, so they cannot drift apart:

- `FixtureLink` (`test/helpers/fixture_link.dart`), the `gql` link for widget and repository tests;
- the mock server (`tool/mock_server`), for typed errors, legal texts and its seed data;
- `test/core/api/fixtures_test.dart`, which runs every file through the generated `fromJson` and
  through the repository of its operation.

Conventions:

- `default.json` is the happy path and what a `FixtureLink` serves unless told otherwise. Every
  operation has one.
- `business_error`, `input_invalid`, `technical_error`: the three generic members of every error
  union. `unknown_error` is a member this build does not know (`SomethingNewError`), and the
  `unknown_*` scenarios carry enum values of the future. The client must survive all of them.
- `{"$fixture": "analysis/v1/forty-move-game.json"}` is replaced by the content of that file
  (relative to `test/fixtures`) when the fixture is loaded. The `GameAnalysis` fixtures embed the
  vendored analysis documents this way instead of copying them.
- The files are written by `make_fixtures.py` in this directory. Change the script and run it, so
  that the many near-identical error fixtures stay consistent; hand edits are overwritten.

`test/core/api/fixtures_test.dart` fails when a fixture lacks a field its operation selects, when an
operation has no `default`, and when a member of an error union has no fixture.
