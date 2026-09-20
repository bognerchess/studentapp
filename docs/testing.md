# Testing and the gate

Most of the code in this repository is written by coding agents, several of
them at the same time on different branches. That only works if "is this
change acceptable?" has one mechanical answer that is the same on every
machine. The answer is `tool/check.sh`. CI runs that script and nothing else
for the gate, so a change that is green locally is green in CI, and the other
way round. A work package is not done until it is green.

This document explains what the gate checks and why, the small tools behind
it, and how golden tests fit in.

## The gate: `tool/check.sh`

    tool/check.sh                 # everything, a few seconds today
    tool/check.sh --fast          # without codegen and tests, for quick iterations
    tool/check.sh --format        # rewrite the files the format section would complain about
    tool/check.sh --strict-swift  # Swift files without a licence header are errors
    tool/check.sh --help

The script stops at the first section that fails, names the section and prints
one line on how to fix it. The sections run from cheap to expensive:

1. **Dependencies.** `flutter pub get --enforce-lockfile`. `pubspec.lock` is
   committed, because this is an app, and this step fails when it no longer
   matches `pubspec.yaml`. Without it CI would quietly resolve different
   versions from the ones the developer tested. If it fails: run
   `flutter pub get` and commit the lock file (and remember the row in
   `docs/dependencies.md`).
2. **Format.** `dart format --output=none --set-exit-if-changed` over the
   hand-written Dart files in `lib/`, `test/`, `tool/` and
   `integration_test/`. Generated files (`*.g.dart`, `*.freezed.dart`,
   `*.graphql.dart`, anything in a `generated/` directory) and `third_party/`
   are left out: their formatting belongs to the generator or to upstream. The
   gate only reports; `tool/check.sh --format` rewrites exactly the same set of
   files. Plain `dart format .` would also touch generated code and then trip
   section 6.
3. **Analyze.** `flutter analyze --fatal-infos`. The lint set in
   `analysis_options.yaml` is strict on purpose and an info is a failure: the
   analyzer is the cheapest reviewer there is.
4. **Licence headers.** `tool/check_headers.dart`, see below.
5. **Layer imports.** `tool/check_layers.dart`, see below.
6. **Codegen is clean.** Runs `tool/gen.sh` and compares the working tree
   before and after. Generated code is committed, so that the app builds from a
   clone without running generators and so that a review shows what a schema
   change really did. The price is that it can go stale; this section is what
   catches that. In CI the tree is clean, so the comparison amounts to
   `git diff --exit-code` plus a look for new untracked files. Locally it also
   works with uncommitted changes, which a bare `git diff --exit-code` could
   not. If it fails, `tool/gen.sh` has just brought the files up to date:
   review and commit them.
7. **Tests.** `flutter test --exclude-tags golden`: unit and widget tests.
   Goldens are separate, see below.

`--fast` skips sections 6 and 7. Use it while iterating; run the full script
before you hand a branch over.

## `tool/gen.sh`

Runs every generator the project is set up for: `flutter gen-l10n` when there
is an `l10n.yaml`, and `dart run build_runner build --delete-conflicting-outputs`
when `build_runner` is a dependency in `pubspec.yaml` (GraphQL operations,
drift, freezed, json_serializable). When neither applies it says so and exits
successfully, which is the state of the project at the time of writing. Run it
after changing a `.graphql` file, a drift table, a freezed model or an ARB
file, and commit what it produced.

## `tool/check_headers.dart`

    dart tool/check_headers.dart [--strict-swift] [--root <dir>]

The app is GPL, contains some code adapted from other GPL projects, and
carries an additional permission for app-store distribution that only the
copyright holder of a file can give. So every file has to say which of the two
kinds it is, and the check makes sure none forgets:

- **Own code** starts, on line 1, with
  `// SPDX-License-Identifier: GPL-3.0-or-later` and names
  `LICENSE-APP-STORE-PERMISSION.md` within the first five lines. Copy the three
  lines at the top of `lib/main.dart`.
- **Code adapted from lichess** starts with
  `// SPDX-License-Identifier: GPL-3.0-only`, keeps the original copyright
  line, and has a provenance line within the first ten lines:
  `// Adapted from <repo>/<path>@<commit sha>`. It must *not* name the
  app-store permission, because that permission is not ours to give for
  somebody else's code. A provenance line without a commit sha is a warning.
  Such a file also needs a row in `NOTICE`.

Checked: every `*.dart` under `lib/`, `test/`, `tool/` and `integration_test/`,
and every `*.swift` under `ios/Runner/` and `ios/ShareExtension/`. Skipped:
generated files, `third_party/`, and the fixture trees in
`tool/test_fixtures/`. The file list comes from git (tracked files plus new
files that are not ignored), so a file is checked before it is committed and
build output never is.

**`--strict-swift`.** The Swift files that `flutter create` wrote have no
header yet; the iOS hardening work package (WP-01) adds them. Until that is
merged a Swift finding is printed as a warning and does not fail the gate.
With `--strict-swift` it is an error. When WP-01 is on `main`, change
`strict_swift=0` to `strict_swift=1` near the top of `tool/check.sh`. That one
line turns it on for everybody and for CI at once, which is better than a flag
only the workflow passes, because then local and CI would differ.

## `tool/check_layers.dart`

    dart tool/check_layers.dart [--root <dir>]

The architecture rules from `CLAUDE.md` that can be read off an import
statement. Each violation is printed as `file:line: error: [rule] ...`.

| Rule | What it says | Why |
| --- | --- | --- |
| `chessground` | Only `lib/core/chess/` imports `package:chessground/`. | The board package changes its API between major versions. One directory wraps it, so an upgrade touches one directory. |
| `graphql` | Only `lib/core/api/` imports `package:graphql/` or a `package:gql*` package. | Transport is a detail of the API layer. Features see repositories and domain models. |
| `generated-graphql` | Nothing in `lib/features/*/ui/` or `lib/core/ui/` imports a `*.graphql.dart` file. | Generated types follow the server schema. If widgets used them, every schema change would ripple into the UI. `data/*_mapper.dart` converts them to domain models. |
| `cross-feature` | A feature does not import another feature's `ui/` or `data/`. Its `domain/` is fine. | Features stay separable, and parallel work packages do not reach into each other's internals. Code outside `lib/features/` (the router, for example) may import any feature. |

Only `lib/` is checked. Tests are exempt on purpose: a widget test builds a
`gql` link to serve fixtures. Generated files are not checked as sources
either; a generated `*.graphql.dart` next to a mapper does import `gql`.
Relative imports are resolved, so `../../library/ui/x.dart` is caught just like
the `package:` form.

The tool is a line scanner over the directive section of a file, not a Dart
parser, so it needs no package and runs in milliseconds. It understands
comments and directives that span several lines, and it stops at the first
declaration.

Both check tools are themselves tested: `test/tool/` runs them against small
good and bad trees in `tool/test_fixtures/`. Those trees are excluded from the
analyzer (they import packages that do not exist here) but not from the
formatter.

## The API in tests: fixtures, `FixtureLink`, the mock server

Nothing in the gate talks to a real backend. There are three stand-ins, and they share one set of
data, `test/fixtures/graphql/<Operation>/<scenario>.json` (GraphQL response bodies; see the README
there):

- **`FixtureLink`** (`test/helpers/fixture_link.dart`) is a `gql` link that answers from those
  files. Widget tests and repository tests put it under the API layer with one override:

      final api = FixtureLink({'RequestGameAnalysis': 'limit_reached'});
      await pumpApp(tester, overrides: api.overrides);      // apiLinkProvider -> api
      api.use('RequestGameAnalysis', 'default');            // change the answer later
      api.respond('AnalysisJob', (variables) => {...});     // or compute it
      api.fail('MyMobileGames', const SocketException('offline'));
      expect(api.requestsOf('ImportMobileGame').single.variables, ...);

  An operation without a chosen scenario gets its `default.json`, the happy path. No token is asked
  for and no HTTP happens, which matters: **a test file that contains `testWidgets` cannot make real
  HTTP requests** (the test binding answers them all with status 400).
- **The mock server** (`tool/mock_server`, a `shelf` app) is the same data behind real HTTP, with
  memory: imported games, jobs that go QUEUED, RUNNING, DONE, a daily limit of three, the consent
  flow, feedback. `dart run tool/mock_server/main.dart --port 5299` runs it for the simulator and for
  `integration_test` (`config/fake.json` points there); `--help` lists the options and the scenarios
  of `POST /__scenario`. Tests without `testWidgets` start it in-process on a free port:
  `final server = await MockServer.start();` (see `test/core/api/repositories_mock_server_test.dart`).
  It is development tooling and imports nothing but `dart:io` and `shelf`; `test/tool/mock_server_test.dart`
  is its own test.
- **`fixtures_test.dart`** runs every fixture through the generated `fromJson` and through the
  repository of its operation, and fails when an operation has no `default` or an error union has a
  member without a fixture. `schema_pin_test.dart` pins `graphql/schema.graphql` to the backend's
  contract by SHA-256 (`graphql/SCHEMA_SOURCE.md` says how to refresh it).

## `tool/check_bundled_assets.sh`

    flutter build ios --simulator --debug
    tool/check_bundled_assets.sh [path/to/Runner.app]

`pubspec.yaml` says what we asked for; the built bundle says what we ship.
Flutter copies every asset a package declares into the app, used or not, and
upstream `chessground` declares about forty piece sets with mixed licences and
a directory of board images. This app depends on a trimmed fork for that
reason, and this script is the proof that the trimming worked. It looks into
`Runner.app/Frameworks/App.framework/flutter_assets` and fails when

- a directory below any `piece_sets/` directory is not named in
  `tool/asset_allowlist.txt` (one name per line, `#` for comments; every name
  there also needs its row in `NOTICE`),
- any board image is bundled (board themes are colour schemes in code, so
  there is no allow-list for them), or
- any path in the whole bundle contains "firebase".

It passes trivially while `chessground` is not a dependency. It needs a built
app, so it is not part of `tool/check.sh`; CI runs it in the `ios` job after
the simulator build, through `tool/check_compliance.sh`.

## `tool/check_compliance.sh`

    tool/check_compliance.sh                                 # development mode
    tool/check_compliance.sh --app build/ios/iphonesimulator/Runner.app
    tool/check_compliance.sh --release --app <path>/Runner.app --accept <id>
    tool/check_compliance.sh --help

`tool/check.sh` answers "is this change acceptable?". This one answers "may
this build be conveyed?", which is the question the GPL asks every time a
binary leaves the building, and it is the machine half of
`docs/release-checklist.md`. It does not reimplement anything: sections 3 and 4
call `tool/check_headers.dart --strict-swift` and
`tool/check_bundled_assets.sh` and roll their result up. What it adds is the
part nothing else covers:

- **Section 1, forbidden dependencies.** A list of names (Firebase,
  Crashlytics, the ad and attribution SDKs) matched against `pubspec.yaml`,
  `pubspec.lock`, the Swift Package Manager pins and every path inside the
  built app. A native pin that is not classified in the script's `native_pins`
  table fails: adding native code is a licence decision, not a build detail.
- **Section 2, a licence row for every direct dependency** in
  `docs/dependencies.md`, with a licence from the accepted set (MIT, BSD,
  Apache-2.0, GPL-compatible; AGPL deliberately not). The check refuses to run
  if the table's fourth column is no longer "Licence", so it can never silently
  read the wrong one.
- **Section 5, NOTICE is complete**: every file whose header says "Adapted
  from …", every tree under `third_party/`, every name in
  `tool/asset_allowlist.txt` and every Swift Package Manager pin is named in
  `NOTICE` (or, for the packages, in `docs/dependencies.md`).
- **Section 6, the tag matches the build**: the release tag equals `v<version>`
  from `pubspec.yaml`.
- **Section 7, corresponding source**: the tree is clean, HEAD is reachable
  from a remote, the three legal texts exist and are bundled with the app, the
  section-7 permission is no longer a draft, and `docs/building.md` names the
  Flutter version that `pubspec.yaml` pins.
- **Section 8, reproducible build**: a named hook for WP-54, which verifies
  nothing yet and says so.

**Two modes, one set of checks.** Conditions that cannot be true before a
release is cut — a tag, a clean and published tree, a built app, a section-7
text that is no longer a DRAFT — are notes in development mode and failures
with `--release`. Every such line ends in `[release mode would fail here]`, and
the script prints its mode at the top, so a green run never has to be
interpreted.

**Owner decisions.** Some findings are questions, not bugs. Today there is one:
`sentry-cocoa` arrives as a prebuilt binary xcframework rather than as source
(`prebuilt:sentry-cocoa`). The script prints the whole story every time and, in
release mode, fails until the decision is acknowledged with
`--accept prebuilt:sentry-cocoa` — which puts the answer in the release log
instead of in somebody's memory.

CI runs it twice, the same way it splits everything else: on the `check` job
without a bundle (a second or two, and a forbidden dependency or a missing
licence row is caught in the pull request that adds it), and on the `ios` job
with `--app`, where the bundle-dependent sections have something to read.
`--release` is not run in CI; it belongs to the release, see
`docs/release-checklist.md`.

## Golden tests

A golden test renders a widget and compares the pixels with a committed PNG.
They are valuable for the few widgets where looks are the point (the board
with arrows and glyphs, the eval graph, a coach card) and expensive
everywhere else, so keep them to a handful.

**Goldens are macOS-only.** Flutter rasterises text and anti-aliases shapes
slightly differently per platform. A golden made on Linux never matches on a
Mac and the other way round. Every developer machine for an iOS app is a Mac,
so the reference platform is macOS: goldens are created on macOS, compared on
macOS, and the Linux `check` job excludes them with `--exclude-tags golden`.
Never run `--update-goldens` on Linux. `tool/golden.sh` refuses to run
anywhere but macOS for that reason.

    tool/golden.sh            # compare
    tool/golden.sh --update   # rewrite the PNGs

To add a golden:

1. Put the test under `test/`, next to the other tests of its feature, and tag
   it. Either the whole file, as its first line after the header,
   `@Tags(['golden'])` followed by `library;`, or a single test with
   `testWidgets('...', tags: 'golden', (tester) async { ... })`.
2. Make it deterministic: fixed surface size, fixed locale, fixed text scale,
   no clock, no network, no animation in flight (`pumpAndSettle`). Load a
   bundled, OFL-licensed font in `test/flutter_test_config.dart` (the first
   work package with a golden adds it, with a row in `NOTICE`); without a
   real font Flutter draws every glyph as a box, and with a system font the
   image depends on the OS version.
3. Create the image on a Mac with `tool/golden.sh --update` and look at it.
   A golden nobody looked at only proves that the output did not change.
4. Commit the PNG together with the test.

To change a golden on purpose, run `tool/golden.sh --update` and commit the
new images **in their own commit**, with before and after shown in the pull
request. An unexplained golden change in a feature commit is a review stop.

When a comparison fails, Flutter writes the expected image, the actual image
and two diffs to a `failures/` directory next to the test. CI uploads those as
the `golden-failures` artifact.

While there are no golden tests, `flutter test --tags golden` exits with 79
("no tests ran"). `tool/golden.sh` accepts that only as long as no file under
`test/` mentions the tag, so that a typo in a selector cannot turn the golden
job into a silent no-op later.

## `integration_test/`: the app on a simulator

    flutter test integration_test -d "iPhone 17 Pro" --dart-define-from-file=config/fake.json

These tests install the real app on a simulator and drive it with touches.
They are not part of `tool/check.sh`: they need a Mac, a simulator and
minutes, and they are the only tests that run the app as it is built rather
than a widget tree pumped by a test.

`integration_test/helpers/` is the whole harness, and it is meant to stay
small:

- `app_harness.dart`: `ensureIntegrationBinding()`, `launchApp(tester)` (the
  real `BognerChessApp` in a `ProviderScope`, with the one-time analytics
  question switched off), `goTo`, `locationOf`, and `publishReport`.
- `board_taps.dart`: touching squares of a `BoardView` by name. The
  coordinates come from the board's rectangle and `squareRect`, not from the
  semantics tree, so that the test does not pay for switching semantics on.
  The widget tests in `test/helpers/board_tester.dart` take the other route
  on purpose, and the two agree.
- `ply_work.dart`: how much work the app itself did for one step, from the
  frame timings the engine reports (`FrameTiming.buildDuration` on the UI
  thread and `rasterDuration` on the raster thread, attributed to a step by
  frame number). `entry_40_moves_test` holds that number under a budget.

**Reports.** `publishReport(binding, key, summary)` writes a JSON summary
twice: into `binding.reportData`, which is what `flutter drive` with
`integrationDriver` hands back, and as one line on stdout beginning with
`INTEGRATION-REPORT`, which is what `flutter test integration_test` leaves
behind. The integration workflow splits those lines into
`build/integration/<key>.json`, uploads them as the `integration-reports`
artifact and puts them in the job summary. Keep a summary small: `debugPrint`
throttles, and a report of tens of kilobytes can still be in the queue when
the process exits.

**A performance number in one of these tests is a regression proxy, not a
product claim.** A debug build on a simulator is several times slower than a
release build on a phone. The acceptance bar for entry speed is human gate
H9: a stopwatch, a paper scoresheet and a real iPhone.

## CI

`.github/workflows/pr.yml` runs on every pull request and on pushes to `main`.
A newer push to a pull request cancels the run of the older one. The workflow
has read access to the repository contents and uses no secrets.

- **`check`**, on `ubuntu-latest`: installs the Flutter version pinned in
  `pubspec.yaml` (`environment.flutter`), runs `tool/check.sh` and then
  `tool/check_compliance.sh` without a bundle. Linux, because it is the fast
  and cheap runner and nothing in the gate needs a Mac.
- **`ios`**, on macOS: `flutter build ios --simulator --debug` (with
  `config/fake.json` once that exists), then
  `tool/check_compliance.sh --app` on the result, which runs
  `tool/check_bundled_assets.sh` among other things, then `tool/golden.sh`. The
  runner is `macos-latest`; a comment in the workflow says what to do when
  GitHub's image and the Xcode that the pinned Flutter expects drift apart.

`.github/workflows/integration.yml` is for the slow tests that drive the app
in a simulator (`flutter test integration_test`). It runs nightly, on manual
dispatch, and on pull requests labelled `integration`. It boots the first
iPhone the runner image offers, runs the tests, and collects the reports
described above. A checkout without an `integration_test/` directory still
passes: the probe step skips the rest.

Workflow files are linted with `actionlint` (`brew install actionlint`), which
also runs `shellcheck` over the inline scripts. The shell scripts in `tool/`
pass `shellcheck` and work with the bash 3.2 that macOS ships.
