---
id: WP-02
title: CI and check script
status: review
size: S
depends_on: [WP-00]
blocked_by_human: []
branch: mobile/WP-02
pr:
---

## Scope

The single gate and the CI that runs it.

- `tool/check.sh`: dependencies, format, analyze, licence headers, layer imports, codegen-is-clean, tests. Fail-fast, identical locally and in CI, with `--fast`.
- `tool/gen.sh`: l10n and build_runner, each only when the project is set up for it.
- `tool/check_headers.dart` and `tool/check_layers.dart` (shared file listing in `tool/src/source_files.dart`), unit-tested from `test/tool/` against fixture trees in `tool/test_fixtures/`.
- `tool/check_bundled_assets.sh` with the allow-list in `tool/asset_allowlist.txt`.
- `tool/golden.sh`: the macOS-only golden run, used by CI and by developers.
- `.github/workflows/pr.yml` (jobs `check` and `ios`) and `.github/workflows/integration.yml` (placeholder).
- `docs/testing.md`.
- `analysis_options.yaml`: one more exclude, `tool/test_fixtures/**`.

## Out of scope

`ios/` (WP-01), `lib/` and the dependencies in `pubspec.yaml` (WP-03), `third_party/chessground` and `lib/core/chess` (WP-04). The deploy workflow (WP-50). The GPL compliance script (WP-51).

## Contracts

**Consumes:** the Flutter pin in `pubspec.yaml` (`environment.flutter`), the three-line header from WP-00, the layer rules in `CLAUDE.md`.
**Produces:** `tool/check.sh` as the definition of done for every later work package; `tool/gen.sh` as the one entry point for generators (WP-10, WP-13 and WP-03's l10n plug into it without editing it); `tool/asset_allowlist.txt` for WP-04 to finalise; the `golden` tag convention and `tool/golden.sh`.

## Steps

1. Header and layer tools with fixture trees and tests.
2. `gen.sh`, `check.sh`, `check_bundled_assets.sh`, `golden.sh`.
3. Workflows, linted with actionlint.
4. `docs/testing.md`.
5. Demonstrate every failure mode in a scratch copy.

## Acceptance commands

```bash
tool/check.sh
tool/check.sh --fast
for f in tool/*.sh; do bash -n "$f"; done
shellcheck tool/*.sh
actionlint
dart tool/check_headers.dart --root tool/test_fixtures/headers/bad   # must fail
dart tool/check_layers.dart --root tool/test_fixtures/layers/bad     # must fail
flutter build ios --simulator --debug && tool/check_bundled_assets.sh
tool/golden.sh
```

## Evidence

All commands were run on 2026-09-19 (macOS 26.6, Flutter 3.47.5) after the last change. Progress lines of `flutter test` and the list of outdated packages are cut; paths are shortened.

### The gate is green

`tool/check.sh`

```
==> 1/7 dependencies: flutter pub get --enforce-lockfile
Resolving dependencies...
Downloading packages...
Got dependencies!
4 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.

==> 2/7 format: dart format --set-exit-if-changed
Formatted 33 files (0 changed) in 0.05 seconds.

==> 3/7 analyze: flutter analyze --fatal-infos
Analyzing studentapp-WP-02...
No issues found! (ran in 3.2s)

==> 4/7 licence headers: tool/check_headers.dart
ios/Runner/AppDelegate.swift:1: warning: line 1 must be "// SPDX-License-Identifier: GPL-3.0-or-later" (own code) or "// SPDX-License-Identifier: GPL-3.0-only" (adapted code)
ios/Runner/SceneDelegate.swift:1: warning: line 1 must be "// SPDX-License-Identifier: GPL-3.0-or-later" (own code) or "// SPDX-License-Identifier: GPL-3.0-only" (adapted code)
check_headers: ok, 2 warning(s) (Swift headers are not enforced without --strict-swift)

==> 5/7 layer imports: tool/check_layers.dart
check_layers: ok

==> 6/7 codegen is clean: tool/gen.sh, then compare the working tree
gen: nothing to generate yet (no l10n.yaml, build_runner is not a dependency)
codegen: clean

==> 7/7 tests: flutter test --exclude-tags golden
00:00 +29: All tests passed!

OK in 7s
exit code: 0
```

`tool/check.sh --fast` ends with `OK (fast: codegen and tests skipped) in 5s`, exit code 0. `tool/check.sh --bogus` prints `check: unknown option '--bogus' (try --help)` and exits with 64.

### Failure modes

Each was provoked in a scratch copy of the working tree (its own throw-away git repository outside this one), then removed again. Output starts at the failing section.

**Unformatted file** (`lib/unformatted.dart` containing `int  add(int a,int b){return a+b;}`):

```
==> 2/7 format: dart format --set-exit-if-changed
Changed lib/unformatted.dart
Formatted 34 files (1 changed) in 0.06 seconds.

FAILED: 2/7 format: dart format --set-exit-if-changed (exit code 1)
        Run 'tool/check.sh --format' (or 'dart format' on the files listed above) and commit.
exit code: 1
```

The gate did not rewrite the file (`--output=none`); `tool/check.sh --format` then did (`Formatted 34 files (1 changed)`).

**Missing header** (`lib/no_header.dart` without any header):

```
==> 4/7 licence headers: tool/check_headers.dart
lib/no_header.dart:1: error: line 1 must be "// SPDX-License-Identifier: GPL-3.0-or-later" (own code) or "// SPDX-License-Identifier: GPL-3.0-only" (adapted code)
check_headers: 1 error(s), 0 warning(s). Own files start with the three-line header of lib/main.dart.

FAILED: 4/7 licence headers: tool/check_headers.dart (exit code 1)
        Own files start with the three-line header of lib/main.dart; see docs/testing.md.
exit code: 1
```

**Forbidden import** (`lib/features/review/ui/review_screen.dart` exporting `package:bogner_chess/features/library/ui/library_screen.dart`; a cross-feature import was used because an import of a package that is not installed already fails section 3):

```
==> 5/7 layer imports: tool/check_layers.dart
lib/features/review/ui/review_screen.dart:5: error: [cross-feature] 'package:bogner_chess/features/library/ui/library_screen.dart': feature 'review' must not import the ui/ layer of feature 'library' (its domain/ is allowed)
check_layers: 1 violation(s). The rules are explained in CLAUDE.md under "Architecture rules".

FAILED: 5/7 layer imports: tool/check_layers.dart (exit code 1)
        See 'Architecture rules' in CLAUDE.md.
exit code: 1
```

**Stale generated code** (in the scratch copy `tool/gen.sh` was replaced by a stand-in that writes `lib/model.g.dart`, which is what a real generator does when its output was not committed):

```
==> 6/7 codegen is clean: tool/gen.sh, then compare the working tree
gen: (scratch stand-in for a generator whose output was not committed)
tool/gen.sh changed the working tree. It now looks like this:
?? lib/model.g.dart

FAILED: 6/7 codegen is clean: tool/gen.sh, then compare the working tree (exit code 1)
        Generated files are out of date. tool/gen.sh has just rewritten them: review and commit them.
exit code: 1
```

**Lock file out of date** (`args: ^2.0.0` added to `pubspec.yaml` without `flutter pub get`):

```
+ args 2.7.0
Would change 1 dependency.
Unable to satisfy `pubspec.yaml` using `pubspec.lock`.

To update `pubspec.lock` run `flutter pub get` without
`--enforce-lockfile`.
Failed to update packages.

FAILED: 1/7 dependencies: flutter pub get --enforce-lockfile (exit code 65)
        pubspec.lock does not match pubspec.yaml. Run 'flutter pub get' and commit pubspec.lock.
exit code: 65
```

**Failing test** (`test/broken_test.dart` expecting `2 + 2` to be 5):

```
00:01 +29 -1: Some tests failed.

Failing tests:
  .../test/broken_test.dart: two and two

FAILED: 7/7 tests: flutter test --exclude-tags golden (exit code 1)
        Goldens are not part of this run; they are tool/golden.sh on macOS.
exit code: 1
```

### The check tools on their fixture trees

`dart tool/check_headers.dart --root tool/test_fixtures/headers/bad`

```
integration_test/missing_test.dart:1: error: line 1 must be "// SPDX-License-Identifier: GPL-3.0-or-later" (own code) or "// SPDX-License-Identifier: GPL-3.0-only" (adapted code)
ios/Runner/NoHeader.swift:1: warning: line 1 must be "// SPDX-License-Identifier: GPL-3.0-or-later" (own code) or "// SPDX-License-Identifier: GPL-3.0-only" (adapted code)
ios/ShareExtension/NoHeader.swift:1: warning: line 1 must be "// SPDX-License-Identifier: GPL-3.0-or-later" (own code) or "// SPDX-License-Identifier: GPL-3.0-only" (adapted code)
lib/adapted_no_provenance.dart:1: error: a GPL-3.0-only file must carry an "Adapted from <repo>/<path>@<commit sha>" line within the first 10 lines
lib/adapted_no_sha.dart:3: warning: the provenance line names no commit sha (expected "Adapted from <repo>/<path>@<commit sha>")
lib/adapted_with_permission.dart:4: error: adapted code stays GPL-3.0-only and must not claim the app-store permission
lib/late_permission.dart:1: error: own code must name LICENSE-APP-STORE-PERMISSION.md within the first 5 lines
lib/missing.dart:1: error: line 1 must be "// SPDX-License-Identifier: GPL-3.0-or-later" (own code) or "// SPDX-License-Identifier: GPL-3.0-only" (adapted code)
lib/no_permission.dart:1: error: own code must name LICENSE-APP-STORE-PERMISSION.md within the first 5 lines
lib/spdx_not_first.dart:1: error: line 1 must be "// SPDX-License-Identifier: GPL-3.0-or-later" (own code) or "// SPDX-License-Identifier: GPL-3.0-only" (adapted code)
tool/missing.dart:1: error: line 1 must be "// SPDX-License-Identifier: GPL-3.0-or-later" (own code) or "// SPDX-License-Identifier: GPL-3.0-only" (adapted code)
check_headers: 8 error(s), 3 warning(s). Own files start with the three-line header of lib/main.dart.
exit code: 1
```

With `--strict-swift` the last line becomes `check_headers: 10 error(s), 1 warning(s).` On the real tree `dart tool/check_headers.dart --strict-swift` fails today with the two Swift files of `ios/Runner/`, as intended until WP-01 is merged.

`dart tool/check_layers.dart --root tool/test_fixtures/layers/bad`

```
lib/core/auth/conditional.dart:7: error: [chessground] 'package:chessground/chessground.dart': only lib/core/chess/ may import chessground; use the BoardView wrapper from lib/core/chess/ instead
lib/core/ui/game_tile.dart:7: error: [generated-graphql] 'package:bogner_chess/core/api/schema.graphql.dart': UI code must not see generated GraphQL types; map them to domain models in data/*_mapper.dart
lib/features/library/data/library_repository.dart:7: error: [graphql] 'package:gql_http_link/gql_http_link.dart': only lib/core/api/ may import graphql or gql packages
lib/features/library/data/library_repository.dart:8: error: [graphql] 'package:graphql/client.dart': only lib/core/api/ may import graphql or gql packages
lib/features/review/ui/review_screen.dart:7: error: [cross-feature] 'package:bogner_chess/features/library/ui/library_screen.dart': feature 'review' must not import the ui/ layer of feature 'library' (its domain/ is allowed)
lib/features/review/ui/review_screen.dart:8: error: [chessground] 'package:chessground/chessground.dart': only lib/core/chess/ may import chessground; use the BoardView wrapper from lib/core/chess/ instead
lib/features/review/ui/review_screen.dart:10: error: [cross-feature] '../../library/data/library_repository.dart': feature 'review' must not import the data/ layer of feature 'library' (its domain/ is allowed)
lib/features/review/ui/review_screen.dart:11: error: [generated-graphql] '../data/review_query.graphql.dart': UI code must not see generated GraphQL types; map them to domain models in data/*_mapper.dart
check_layers: 8 violation(s). The rules are explained in CLAUDE.md under "Architecture rules".
exit code: 1
```

Both tools exit with 0 on the `good` trees; `test/tool/` asserts all of this (28 of the 29 tests are theirs).

### Bundled assets

`flutter build ios --simulator --debug` built `build/ios/iphonesimulator/Runner.app` (Xcode build 16.6 s), then `tool/check_bundled_assets.sh`:

```
bundle:     .../build/ios/iphonesimulator/Runner.app
allow-list: cburnett merida chessnut rhosgfx

chessground assets in the bundle (files per directory):
  none: packages/chessground is not in the bundle

piece sets:
  none

board images:
  none

firebase:
  none

check_bundled_assets: ok
exit code: 0
```

Against a hand-made bundle with the upstream layout (`packages/chessground/assets/piece_sets/{cburnett,alpha,horsey}`, `packages/chessground/assets/boards/*`, an app-level `assets/piece_sets/pixel` and a `FirebaseCore.framework`):

```
chessground assets in the bundle (files per directory):
   2 packages/chessground/assets/boards
   1 packages/chessground/assets/piece_sets/alpha
   1 packages/chessground/assets/piece_sets/cburnett
   1 packages/chessground/assets/piece_sets/horsey

piece sets:
  FAIL: assets/piece_sets/pixel: piece set 'pixel' is not in tool/asset_allowlist.txt
  FAIL: packages/chessground/assets/piece_sets/alpha: piece set 'alpha' is not in tool/asset_allowlist.txt
  ok:   packages/chessground/assets/piece_sets/cburnett
  FAIL: packages/chessground/assets/piece_sets/horsey: piece set 'horsey' is not in tool/asset_allowlist.txt

board images:
  FAIL: packages/chessground/assets/boards/blue2.jpg: board images must not be bundled; board themes are colour schemes in code
  FAIL: packages/chessground/assets/boards/horsey.last-move.webp: board images must not be bundled; board themes are colour schemes in code

firebase:
  FAIL: Frameworks/FirebaseCore.framework: the app must not contain Firebase
  FAIL: GoogleService-Info-firebase.plist: the app must not contain Firebase

check_bundled_assets: 7 problem(s)
exit code: 1
```

A bundle with only allow-listed sets passes; a missing bundle or one without `flutter_assets` exits with 2. The same results came out with `PATH=/usr/bin:/bin` (BSD sed, grep and find) and with the GNU sed that is first on this machine's `PATH`. It was not run on Linux itself: no container image was at hand and pulling one was not part of the brief. The script uses only POSIX options plus `-mindepth`/`-maxdepth`, which GNU find has.

### Goldens

`tool/golden.sh`

```
No tests ran.
No tests match the requested tag selectors:
  include: "golden"
  exclude: "<none>"
golden: there are no golden tests yet, nothing to compare
exit code: 0
```

### Linters

```
$ for f in tool/*.sh; do bash -n "$f" && echo "bash -n $f ok"; done
bash -n tool/check.sh ok
bash -n tool/check_bundled_assets.sh ok
bash -n tool/gen.sh ok
bash -n tool/golden.sh ok
$ bash --version | head -1
GNU bash, version 3.2.57(1)-release (arm64-apple-darwin25)
$ shellcheck tool/*.sh; echo $?
0
$ actionlint -version | head -1; actionlint; echo $?
1.7.12
0
```

The workflows have not run on GitHub: the repository has no remote yet. The first PR after the repository exists is the real test of `pr.yml`.

## Handoff notes

**What other work packages must do to stay green**

- Every new `*.dart` under `lib/`, `test/`, `tool/`, `integration_test/` needs the three-line header from `lib/main.dart` (SPDX on line 1, `LICENSE-APP-STORE-PERMISSION.md` within the first five lines). Lichess-derived files: `// SPDX-License-Identifier: GPL-3.0-only` on line 1, `Adapted from <repo>/<path>@<sha>` within the first ten lines, and **no** mention of the permission file. WP-04: this applies to `lib/core/chess`; `third_party/` is skipped entirely.
- **WP-01:** Swift files under `ios/Runner/` and `ios/ShareExtension/` get the same `//` header. They only warn today. After WP-01 is merged, set `strict_swift=1` near the top of `tool/check.sh` (one line; do not pass the flag from the workflow only, or local and CI differ). `ios/RunnerTests/` is not checked.
- **WP-03 and everyone adding dependencies:** section 1 is `flutter pub get --enforce-lockfile`. After editing `pubspec.yaml`, run `flutter pub get` and commit `pubspec.lock`, or the gate fails with exit code 65 and says so. (Turning a transitive dependency into a direct one does not trip it; a package that is not in the lock file does.)
- **Formatting:** use `tool/check.sh --format`, not `dart format .`; the latter also reformats generated code, and then "codegen is clean" fails.
- **Generated code is committed** (l10n output, `*.g.dart`, `*.freezed.dart`, `*.graphql.dart`). `tool/gen.sh` picks generators up by itself: `l10n.yaml` present means `flutter gen-l10n`, a `  build_runner:` line in `pubspec.yaml` means build_runner. Nobody should need to edit `gen.sh`. If a generator is not deterministic across macOS and Linux, the `check` job will show it; fix the generator options rather than weakening the step.
- **WP-04:** finalise `tool/asset_allowlist.txt` (one directory name per line) together with `NOTICE`. The script checks every `piece_sets/` directory anywhere in `flutter_assets` and fails on any image in a `board/`, `boards/` or `board_themes/` directory. The upstream layout was verified against `lichess-org/flutter-chessground` (`assets/piece_sets/<set>/…`, `assets/boards/*`).
- **Layer check** covers `lib/` only. `test/` may import `gql`. Imports of generated GraphQL files are forbidden in any `ui/` directory inside a feature and in `lib/core/ui/`. Code outside `lib/features/` (router, app shell) may import any feature's `ui/`.
- **First golden test:** tag it `golden`, add a `dart_test.yaml` at the root that declares the tag (`tags: {golden: }`), otherwise `package:test` warns about an undeclared tag. It was left out here because the root was outside this work package's scope. Also add the test font and `test/flutter_test_config.dart` as `docs/testing.md` describes.

**Decisions**

- `dart format` runs with `--output=none`: a gate should report, not rewrite files under an agent that is editing them. `--format` is the explicit rewrite.
- "Codegen is clean" compares a fingerprint of the working tree (diff to HEAD plus untracked files with their hashes) before and after `tool/gen.sh`, instead of a bare `git diff --exit-code`. In CI both are equivalent, except that the fingerprint also sees new untracked files. Locally a bare `git diff --exit-code` would fail for every uncommitted change, and agents are told to run the gate before they commit.
- The check tools use `dart:io` only and run with plain `dart tool/<name>.dart`. The tests import them by relative path (`../../tool/...`), so they run inside `flutter test` without a second test runner.
- The fixture trees are real `.dart` files. They are excluded from the analyzer in `analysis_options.yaml` and from both check tools when those run on the repository, but they are formatted like everything else. `dart format` rewrote two of them while they were being written (it joins a short conditional import onto one line and removes a leading blank line); the multi-line cases are therefore covered by `parseDirectives` unit tests instead of fixture files. There is deliberately no `pubspec.yaml` inside a fixture tree: it would make the tooling treat the tree as a nested package.
- `actions/checkout@v5` (Node 24). `subosito/flutter-action@v2` reads `environment.flutter` through `flutter-version-file`; it needs `yq`, which GitHub's ubuntu and macOS images ship.
- `macos-latest` for the `ios` job, with the Xcode question written into the workflow. The planning document says `macos-26`; switch when the image and the Flutter pin drift apart. `xcodebuild -version` is logged in every run.
- `tool/golden.sh` was not in the brief. It exists so that the tolerance for "no tests ran" (exit code 79) lives in one place, is the same locally and in CI, and ends by itself as soon as a file under `test/` mentions the tag.
- `actionlint` was installed with Homebrew (`brew install actionlint`); `shellcheck` came along as its dependency, and the scripts pass it.

**Not done, on purpose**

- `CLAUDE.md` and `README.md` were not touched (outside the scope). `CLAUDE.md` could mention `tool/check.sh --fast` and `docs/testing.md` under "Commands".
- No Linux run of the scripts (see Evidence). The first CI run covers it.
