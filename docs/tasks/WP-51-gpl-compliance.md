---
id: WP-51
title: GPL compliance script and release checklist
status: review
size: S
depends_on: [WP-04, WP-31]
blocked_by_human: []    # H7 (section-7 wording, courtesy note to Lichess) and H8 (privacy labels, review notes) are checklist items, not blockers for this WP
branch: mobile/WP-51
pr:
---

## Scope

The machine half and the human half of the GPL compliance story for a release.

- `tool/check_compliance.sh`: one command that answers "may this build be
  conveyed?" It reuses `tool/check_headers.dart` and
  `tool/check_bundled_assets.sh` rather than reimplementing them, and adds the
  checks nothing else covers: forbidden dependencies, a licence row for every
  direct dependency, NOTICE completeness, the release tag against
  `pubspec.yaml`, and the mechanical part of the corresponding-source
  obligation.
- `docs/release-checklist.md`: the ordered list somebody follows at 11pm,
  saying what the script covers and what only a human can.
- `.github/workflows/pr.yml`: the cheap checks on the ubuntu job, the
  bundle-dependent ones on the macOS job.
- `docs/testing.md`: a section for the new script, next to the other tools.

## Out of scope

fastlane and TestFlight (WP-50). The reproducible-build verification itself
(WP-54); the script leaves a named hook for it. `lib/features/library`,
`lib/features/submit` and the analysis job code, which other agents own.

## Contracts

**Consumes:** `tool/check_headers.dart`, `tool/check_bundled_assets.sh`,
`tool/asset_allowlist.txt`, `NOTICE`, `docs/dependencies.md`,
`docs/building.md`, `pubspec.yaml` (`version`, `environment.flutter`),
`ios/**/Package.resolved`.

**Produces:** `tool/check_compliance.sh` with `--release[=<tag>]`, `--app`,
`--accept <id>`; `docs/release-checklist.md`, whose steps WP-50 and WP-54 hang
their own work off.

## Steps

1. Write the script; run it against the repository as it is.
2. Fix what it finds, where the fix is small and in scope.
3. Break the inputs deliberately, one at a time, and show the failures.
4. Checklist, CI wiring, `docs/testing.md`.

## Acceptance commands

```bash
tool/check.sh
tool/check_compliance.sh
tool/check_compliance.sh --release=v0.1.0+1
shellcheck tool/check_compliance.sh
actionlint .github/workflows/pr.yml
```

## Evidence

All commands were run on 2026-09-20 from the worktree root, after the last
change to the code. `shellcheck` 0.11.0, `actionlint` 1.7.7, bash 3.2.57
(macOS), Flutter 3.47.5.

### `tool/check.sh`

```
==> 1/7 dependencies: flutter pub get --enforce-lockfile
==> 2/7 format: dart format --set-exit-if-changed
Formatted 330 files (0 changed) in 0.84 seconds.
==> 3/7 analyze: flutter analyze --fatal-infos
No issues found! (ran in 7.8s)
==> 4/7 licence headers: tool/check_headers.dart
check_headers: ok
==> 5/7 layer imports: tool/check_layers.dart
check_layers: ok
==> 6/7 codegen is clean: tool/gen.sh, then compare the working tree
codegen: clean
==> 7/7 tests: flutter test --exclude-tags golden
00:27 +1653: All tests passed!
OK in 45s
```

No test was added or changed by this work package; 1653 is what was there.

### `shellcheck tool/check_compliance.sh` and `actionlint .github/workflows/pr.yml`

Both silent, exit 0. `docs/testing.md` promises that the shell scripts in
`tool/` pass shellcheck; this one does, with no `# shellcheck disable`.

### `tool/check_compliance.sh --app build/ios/iphonesimulator/Runner.app`

The bundle is the output of
`flutter build ios --simulator --debug --dart-define-from-file=config/fake.json`
(`Xcode build done. 35.0s`).

```
Bogner Chess licence compliance
repository: /Users/romanweis/Developer/bognerchess/.worktrees/studentapp-WP-51
version:    0.1.0+1 (expected release tag v0.1.0+1)
flutter:    3.47.5 (pinned in pubspec.yaml)
mode:       development - release-only conditions are reported, not required
bundle:     .../build/ios/iphonesimulator/Runner.app

==> 1/8 forbidden dependencies
  ok:   167 packages in pubspec.lock (36 of them direct in pubspec.yaml), none forbidden
  ok:   both Package.resolved files agree
  ok:   appauth-ios 2.1.0: built from source - Apache-2.0, github.com/openid/AppAuth-iOS, pulled by flutter_appauth. Xcode compiles it from source.
  DECISION prebuilt:sentry-cocoa: NOT yet answered
        sentry-cocoa 8.58.4 ships as a PREBUILT BINARY FRAMEWORK, not as source. MIT,
        github.com/getsentry/sentry-cocoa, pulled by sentry_flutter. Its Package.swift
        declares binary targets, so Xcode downloads Sentry.xcframework.zip from the
        GitHub release and verifies the SHA-256 written in that manifest. The licence
        is fine and the corresponding source is the tag; what we do not have is a build
        of it made by us. Whether this app may convey a binary it did not build from
        source is a launch decision for the copyright holder, not something this script
        can settle. See docs/release-checklist.md.
  ok:   no forbidden name anywhere in the bundle
  frameworks in the bundle:
        App.framework
        Flutter.framework
        Sentry.framework
        objective_c.framework
        sqlite3.framework

==> 2/8 every direct dependency has a licence row in docs/dependencies.md
  ok:   all 36 direct dependencies have a row with an accepted licence
        131 transitive packages are covered by the in-app licence list, not by a row

==> 3/8 SPDX headers (tool/check_headers.dart --strict-swift)
check_headers: ok
  ok:   every own file carries the header

==> 4/8 bundled assets (tool/check_bundled_assets.sh)
        [full tool/check_bundled_assets.sh output, indented; 12 files in each of
        cburnett, merida, rhosgfx and their 2.0x/3.0x/4.0x variants]
        piece sets:
          ok:   packages/chessground/assets/piece_sets/cburnett
          ok:   packages/chessground/assets/piece_sets/merida
          ok:   packages/chessground/assets/piece_sets/rhosgfx
        board images:
          none
        firebase:
          none
        check_bundled_assets: ok
  ok:   only allow-listed piece sets, no board images, no Firebase

==> 5/8 NOTICE is complete
  ok:   ios/ShareExtension/ShareViewController.swift is in NOTICE
  ok:   third_party/chessground/ is in NOTICE
  ok:   piece set 'cburnett' is in NOTICE
  ok:   piece set 'merida' is in NOTICE
  ok:   piece set 'rhosgfx' is in NOTICE
  ok:   native library 'appauth-ios' is in NOTICE
  ok:   native library 'sentry-cocoa' is in NOTICE

==> 6/8 the tag matches the build
  note: HEAD carries no tag: this is not a tagged build, so nothing to compare. A
        release must be tagged v0.1.0+1, which is what the in-app 'source for this
        build' link points at.

==> 7/8 corresponding source
  note: the working tree is not clean; the published source would not be what was
        built [release mode would fail here]
           M .github/workflows/pr.yml
           M CLAUDE.md
           M docs/testing.md
          ?? docs/release-checklist.md
          ?? docs/tasks/WP-51-gpl-compliance.md
          ?? tool/check_compliance.sh
  note: no git remote: the corresponding source of this build is not published
        anywhere (HEAD is e35b1da68ab16b72b0f98f7c434d96d44aa3c029)
        [release mode would fail here]
  ok:   LICENSE exists and is bundled with the app
  ok:   LICENSE-APP-STORE-PERMISSION.md exists and is bundled with the app
  ok:   NOTICE exists and is bundled with the app
  note: LICENSE-APP-STORE-PERMISSION.md is still marked DRAFT and grants nothing.
        Without it the GPL alone governs, and the App Store terms conflict with it.
        This is human gate H7. [release mode would fail here]
  ok:   docs/building.md names the pinned Flutter version 3.47.5

==> 8/8 reproducible build (WP-54)
        Not verified here. WP-54 builds the app from a clean clone of the tag,
        following docs/building.md, and compares the result with the shipped
        binary. When it lands, its script is called from this section and its
        result becomes a release-mode failure like the others. Until then the
        claim that the published source reproduces the binary rests on the human
        step in docs/release-checklist.md.
  ok:   docs/building.md talks about --obfuscate (release builds are made without it)

1 decision(s) for the copyright holder are open; see the DECISION lines above.
check_compliance: ok (development mode), 4 note(s). Run with --release before conveying a build.
```

Exit code 0. The four notes are the four release-only conditions; this is what
the script is supposed to say about an untagged working copy of a repository
that has no remote yet.

### `tool/check_compliance.sh --release=v0.1.0+1 --app ... ` (before this commit)

```
mode:       RELEASE - a tag, a clean published tree and a built app are required
  DECISION prebuilt:sentry-cocoa: NOT yet answered
  FAIL: decision 'prebuilt:sentry-cocoa' is open; re-run with --accept prebuilt:sentry-cocoa once the owner has decided
  FAIL: the working tree is not clean; the published source would not be what was built
  FAIL: no git remote: the corresponding source of this build is not published anywhere (HEAD is e35b1da6...)
  FAIL: LICENSE-APP-STORE-PERMISSION.md is still marked DRAFT and grants nothing. Without it the GPL alone governs, and the App Store terms conflict with it. This is human gate H7.
check_compliance: 4 problem(s), 0 note(s)
```

Exit code 1. **Release mode cannot pass today and should not**: H7 has not
delivered the section-7 wording, and the repository has no remote because H1
has not created the public one. That is the correct answer, not a bug.

### `tool/check_compliance.sh --release --app ... --accept prebuilt:sentry-cocoa` on a tagged, clean tree

Run on the commit of this work package, with a throw-away local tag `v0.1.0+1`
that was deleted again afterwards (`git tag -d v0.1.0+1`; `git tag` lists none).
No `--release=<tag>` was passed: the tag was read from HEAD. Sections 1 to 5
and 8 are unchanged from the run above.

```
mode:       RELEASE - a tag, a clean published tree and a built app are required

==> 1/8 forbidden dependencies
  ...
  DECISION prebuilt:sentry-cocoa: accepted on the command line
        sentry-cocoa 8.58.4 ships as a PREBUILT BINARY FRAMEWORK, not as source. ...
  ok:   no forbidden name anywhere in the bundle

==> 6/8 the tag matches the build
  ok:   tag v0.1.0+1 matches version 0.1.0+1 in pubspec.yaml

==> 7/8 corresponding source
  ok:   the working tree is clean: the commit is what was built
  FAIL: no git remote: the corresponding source of this build is not published anywhere (HEAD is 0a1430a532a123cd8008049c04f8c029706187b3)
  ok:   LICENSE exists and is bundled with the app
  ok:   LICENSE-APP-STORE-PERMISSION.md exists and is bundled with the app
  ok:   NOTICE exists and is bundled with the app
  FAIL: LICENSE-APP-STORE-PERMISSION.md is still marked DRAFT and grants nothing. Without it the GPL alone governs, and the App Store terms conflict with it. This is human gate H7.
  ok:   docs/building.md names the pinned Flutter version 3.47.5

check_compliance: 2 problem(s), 0 note(s)
```

Exit code 1. The tag check and the clean-tree check went green, the decision
was accepted, and what is left is exactly the two human gates: **H1** (the
public repository this has no remote for) and **H7** (the section-7 wording).
That is the shape a passing release run will have once those two are done; no
third thing is hiding behind them.

### It fails when it should

Ten deliberate breaks, each reverted immediately afterwards. Only the `FAIL`
lines and the exit code are shown.

**1. A forbidden dependency written into `pubspec.yaml`** (`firebase_crashlytics: ^4.0.0`;
not resolved, so it is in the yaml but not in the lock file, which is exactly
the moment worth catching):

```
  FAIL: pubspec.yaml declares 'firebase_crashlytics', which is on the forbidden list
  FAIL: firebase_crashlytics is in pubspec.yaml but has no row in docs/dependencies.md
check_compliance: 2 problem(s), 4 note(s)
exit code: 1
```

**2. The `fl_chart` row deleted from `docs/dependencies.md`:**

```
  FAIL: fl_chart is in pubspec.yaml but has no row in docs/dependencies.md
exit code: 1
```

**3. `fl_chart` relabelled `CC BY-NC-SA`** (the licence most of upstream
chessground's piece sets carry, so the realistic wrong answer):

```
  FAIL: fl_chart is listed as 'CC BY-NC-SA' in docs/dependencies.md; CC BY-NC-SA is not in the accepted set (MIT, BSD, Apache-2.0, GPL-compatible)
exit code: 1
```

**4. `merida` removed from `NOTICE`, and `maestro` added to
`tool/asset_allowlist.txt`** (a piece set allow-listed without a row):

```
  FAIL: piece set 'merida' is allow-listed but has no row in NOTICE
  FAIL: piece set 'maestro' is allow-listed but has no row in NOTICE
exit code: 1
```

**5. The vendored tree's `NOTICE` entry removed:**

```
  FAIL: the vendored tree third_party/chessground/ has no entry in NOTICE
exit code: 1
```

**6. A new adapted file with no `NOTICE` entry**
(`lib/core/chess/wp51_demo_adapted.dart`, GPL-3.0-only with a provenance
header, deleted again):

```
  FAIL: lib/core/chess/wp51_demo_adapted.dart is adapted from another project but has no entry in NOTICE
exit code: 1
```

`dart tool/check_headers.dart --strict-swift` said `check_headers: ok` for the
same file, which is the point: the header check asks whether the header is
right, this one asks whether the file is recorded.

**7. `environment.flutter` bumped to 3.48.0 without `docs/building.md`:**

```
  FAIL: docs/building.md does not name Flutter 3.48.0, which pubspec.yaml pins; the build instructions and the build disagree
exit code: 1
```

**8. `--release=v0.9.9+7`, a tag that does not match the version:**

```
  FAIL: tag v0.9.9+7 does not match version 0.1.0+1 in pubspec.yaml (expected v0.1.0+1)
  FAIL: the working tree is not clean; ...
  FAIL: no git remote: ...
  FAIL: LICENSE-APP-STORE-PERMISSION.md is still marked DRAFT ...
check_compliance: 4 problem(s), 0 note(s)
exit code: 1
```

**9. A rogue piece set and a board image planted inside the built bundle**
(`piece_sets/alpha/wN.png` and `boards/blue.png`, removed again):

```
  FAIL: packages/chessground/assets/piece_sets/alpha: piece set 'alpha' is not in tool/asset_allowlist.txt
  FAIL: packages/chessground/assets/boards/blue.png: board images must not be bundled; board themes are colour schemes in code
  FAIL: tool/check_bundled_assets.sh found assets that must not ship; its own FAIL lines are above and count as this one
exit code: 1
```

(The first two lines are `tool/check_bundled_assets.sh`'s own; the summary
counts the sub-script as one problem, which the message says.)

**10. An unclassified Swift package added to both `Package.resolved` files:**

```
  FAIL: Swift package 'some-closed-sdk' is not classified in tool/check_compliance.sh (native_pins); a new native library is a licence decision
  FAIL: native library 'some-closed-sdk' is pinned in Package.resolved but named neither in NOTICE nor in docs/dependencies.md
exit code: 1
```

After every revert the script was re-run and returned to
`check_compliance: ok (development mode), 4 note(s)`, exit code 0.

### What the script found in the repository

Nothing. Every section was green on the first real run: the piece-set
allow-list, `NOTICE`, `docs/dependencies.md` and `docs/building.md` were
already consistent with `pubspec.yaml` and with the built bundle. WP-04,
WP-31 and WP-34 had done that work; this script is what keeps it done. Two
bugs were found in the script itself by the break tests and fixed (see the
handoff notes).

## Handoff notes

**The script is `tool/check_compliance.sh`.** The name follows the `tool/`
convention (`check.sh`, `check_headers.dart`, `check_layers.dart`,
`check_bundled_assets.sh`). It is not part of `tool/check.sh`: the gate answers
"is this change acceptable?" and runs on every save, this one answers "may this
build be conveyed?" and wants a built app for two of its eight sections. Both
run in CI.

**Two modes, one set of checks.** The only difference between development and
release mode is the severity of the conditions a working copy cannot satisfy: a
tag on HEAD, a clean tree, a commit that is on a remote, a built app, and a
section-7 text that is no longer a DRAFT. In development mode each of those is
a note that ends in `[release mode would fail here]`; with `--release` each is a
failure. Nothing is checked in one mode and not the other, so a green
development run never hides a release problem — it lists them.

**`--accept <id>` and the prebuilt binary.** `sentry_flutter` pulls
`sentry-cocoa`, whose `Package.swift` declares binary targets: Xcode downloads
`Sentry.xcframework.zip` from the GitHub release and verifies its SHA-256
instead of compiling anything. MIT is GPL-compatible and the corresponding
source is the tag `8.58.4`, so the licence is not the problem; conveying a
binary we did not build is a judgement the copyright holder has to make. The
script prints the whole story every run and, in release mode, fails until
`--accept prebuilt:sentry-cocoa` is passed, which puts the answer into the
release log rather than into somebody's memory. `docs/release-checklist.md`
step 10 spells out what accepting and refusing each mean. **This is the one
place where a future maintainer could turn the check into a rubber stamp** by
putting `--accept` into a script; do not.

**Every native pin has to be classified.** `native_pins()` in the script is a
two-row table (`appauth-ios` source, `sentry-cocoa` prebuilt). A pin in
`Package.resolved` that is not in it fails, because a new native library is a
licence decision and not a build detail. Adding one means: a row in that table,
a row in `NOTICE` or `docs/dependencies.md`, and — if it is prebuilt — a new
decision id that the release has to accept.

**Two bugs the break tests found**, both in the script, both fixed before the
commit:

- The forbidden-name scan read only `pubspec.lock`. A package written into
  `pubspec.yaml` but not yet resolved slipped through, which is the single most
  likely way Firebase would arrive. It now scans both and says which file the
  hit came from.
- The provenance scan used plain `git grep`, which ignores untracked files, so
  a freshly written adapted file was invisible. It now uses
  `git grep --untracked -I`, the same set `tool/check_headers.dart` looks at.

Both were only visible because the breaks were actually run. A compliance
script nobody ran is worse than none.

**Why the provenance scan looks only at the first ten lines.** That is the
window `tool/check_headers.dart` uses for the provenance line, and it also
keeps the checkers themselves out of the result: `check_headers.dart` and this
script both talk about the `Adapted from` marker, but further down. Combined
with the `@<sha>` part of the pattern, a prose mention cannot be mistaken for a
provenance header.

**The dependency table is parsed by column, with a guard.** Section 2 reads the
"In `pubspec.yaml` today" table of `docs/dependencies.md`, takes every
backticked name out of the first cell (one row may name two packages) and the
fourth cell as the licence. Before it does, it checks that the header of that
fourth column still reads "Licence" and exits 2 with an explanation if it does
not. Reordering that table without touching the script is therefore loud, not
silent. The accepted set is MIT, BSD\*, Apache-2.0, the GPL and LGPL families,
MPL-2.0, CC0, ISC, Zlib, Unlicense and public domain. **AGPL is deliberately
absent**: lila's image boards and sound files are AGPLv3+ and this app does not
take that on (`NOTICE`), so an AGPL row should stop and make someone think.

**Transitive packages are not required to have a row.** There are 131 of them
against 36 direct ones. The rule in `CLAUDE.md` is about dependencies somebody
adds; the transitive ones are covered by Flutter's `LicenseRegistry`, which
puts their licence texts into the app (WP-31), and section 1 scans all 167 for
forbidden names. The script prints the count so the ratio stays visible.

**CI.** `pr.yml` runs it twice, split the way everything else is split: the
`check` job on ubuntu runs it without a bundle right after `tool/check.sh` (a
second or two, and it catches a forbidden dependency or a missing licence row
in the pull request that adds it), and the `ios` job on macOS runs it with
`--app` after the simulator build. That step **replaced** the standalone
`tool/check_bundled_assets.sh` step, which the script now calls and whose full
output it forwards indented, so nothing was lost from the log. `--release` is
not run in CI: no pull request has a release tag, and gating the ordinary loop
on H7 would be absurd.

**For WP-50 (fastlane).** The release job should run
`tool/check_compliance.sh --release --app <the archived Runner.app> --accept …`
**before** `upload_to_testflight`, not after, and put the output into the
GitHub release for the tag (checklist step 19). Everything the script needs
about the tag it reads from `pubspec.yaml`; fastlane does not have to pass a
version.

**For WP-54 (reproducible build).** Section 8 is an empty, named hook. When
WP-54 has a script, call it from there and let its exit code become a failure
like the others; the checklist's step D6 (clone the tag on a second machine and
build) then stops being a human step. The section already checks the one thing
that is cheap: that `docs/building.md` still talks about `--obfuscate`, because
release builds have to stay unobfuscated for the claim to hold.

**Human gates on the checklist, for the coordinator.** The checklist's part D
is the list of things no script can answer: D1 a new dependency's real licence,
D2 the section-7 wording (**H7** — the script fails release mode while the word
DRAFT is in `LICENSE-APP-STORE-PERMISSION.md`), D3 the courtesy note to the
Lichess maintainers (H7), D4 the privacy labels (**H8**), D5 the App Review
notes (H8, WP-53), D6 the reproducible build (WP-54), D7 reading the About
screen on a device. None of them blocks this work package; all of them block a
release, which is why they are in the document and not in the script.

**Not done, on purpose.** No Dart unit test for the script: it is bash, like
`tool/check_bundled_assets.sh`, which has none either, and the ten break tests
above are the evidence in its place. If it grows, the honest move is to rewrite
the parsing parts in Dart under `tool/src/` where `test/tool/` can reach them.
`CLAUDE.md` gained one line in the Commands block; nothing else in it changed.
