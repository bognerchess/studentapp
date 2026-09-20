---
id: WP-54
title: Verify that the published source reproduces the app
status: review
size: M
depends_on: [WP-51]
blocked_by_human: [H4]  # the SIGNED half only. The unsigned half is done and green: the run below is real. See "What H4 still has to verify".
branch: mobile/WP-54
pr:
---

## Scope

The app is GPL-3.0 and published as source. The promise is that somebody who
distrusts us can take that source, follow `docs/building.md`, and get this app.
Nobody had ever checked. This work package checks it, and says exactly how far
the guarantee goes.

- `tool/check_reproducible.sh`: clean clones of a ref into temporary
  directories, built with the commands in `docs/building.md` verbatim, compared
  file by file, with every difference classified as expected (with its reason
  and its evidence) or unexpected (a failure).
- Section 8 of `tool/check_compliance.sh`, which WP-51 left as a named empty
  hook, now calls it, and its exit code is a release-mode failure like the
  others.
- `.github/workflows/reproducible.yml`: nightly, on every `v*` tag, and on
  manual dispatch. Deliberately not on pull requests.
- `docs/building.md`: the exact commands, the environment assumptions, and a
  "Verify this yourself" section written for a sceptic rather than for us.
- `docs/release-checklist.md` step D6 and `docs/testing.md`.

## Out of scope

Signing, certificates, keychains, App Store Connect, fastlane (WP-50). Nothing
in this work package touches a signing identity. The comparison between a
**signed** release build and a clean-clone build is written down but not done:
human gate **H4**.

`config/prod.json` is used as the build configuration because that is what a
release ships; no backend is contacted and the file holds no secret.

## Contracts

**Consumes:** `docs/building.md` (the build commands are read from it and it is
what the script proves true), `pubspec.yaml` (`environment.flutter`),
`config/prod.json`, `tool/check_compliance.sh` section 8.

**Produces:** `tool/check_reproducible.sh` with `--ref`, `--source`,
`--config`, `--target`, `--against`, `--work`, `--keep`, `--reuse`,
`--verbose`; `.github/workflows/reproducible.yml`; the difference table in
`docs/building.md` that WP-50 and the release notes point at.

`--reuse` compares bundles an earlier `--keep` run left behind instead of
building. It exists to work on the classifier; it prints a banner saying the
run is not evidence, at the top and in the summary, and CI never passes it.

## Steps

1. Claim the work package. Write the script; run it end to end.
2. Explain every difference it finds, or fail on it. Add the third build when
   two turned out not to be enough to explain anything.
3. Wire section 8, the workflow, the checklist and the docs.
4. Run it again from scratch and paste the real output below.

## Acceptance commands

```bash
tool/check.sh
shellcheck tool/check_reproducible.sh tool/check_compliance.sh
actionlint .github/workflows/reproducible.yml
tool/check_reproducible.sh --keep          # three builds, two and a half minutes
tool/check_compliance.sh                   # section 8 in development mode
```

## Evidence

### The run

Three clean clones, three builds, two comparisons. Ref `3f44e98`, this branch.
Started 10:12:52, finished 10:15:22 on 2026-09-20: **two and a half minutes**
on the development machine with a warm pub and SwiftPM cache (the three Xcode
builds themselves were 32.7 s, 33.0 s and 26.6 s). A cold CI runner will take
considerably longer, which is what the workflow's timeout allows for.

Command: `TMPDIR=/tmp/bc-wp54-tmp tool/check_reproducible.sh --keep --work /tmp/bc-wp54-tmp/evidence`
Exit code: **0**.

```
Bogner Chess reproducible build
repository: /Users/romanweis/Developer/bognerchess/.worktrees/studentapp-WP-54
source:     /Users/romanweis/Developer/bognerchess/.worktrees/studentapp-WP-54
            (this repository on disk: there is no remote yet (human gate H1), so nobody outside can run this exact command)
ref:        3f44e98f3697c99cb594c8b2d3518d0b33fdfa2d
target:     release (flutter build ios --release --no-codesign --dart-define-from-file=config/prod.json)
work dir:   /private/tmp/bc-wp54-tmp/evidence
flutter:    3.47.5 (pubspec.yaml pins 3.47.5)
xcode:      27.0, macOS 26.6.2

==> 1/4 build A, in /private/tmp/bc-wp54-tmp/evidence/dir-1
        a: git clone into /private/tmp/bc-wp54-tmp/evidence/dir-1
        a: 3f44e98f3697c99cb594c8b2d3518d0b33fdfa2d
        a: flutter pub get
        a: flutter build ios --release --no-codesign --dart-define-from-file=config/prod.json
        a: 232 files kept in /private/tmp/bc-wp54-tmp/evidence/bundle-a

==> 2/4 build A', a second clean clone in the SAME directory
        anything that differs between A and A' differs for no reason at all
        a2: git clone into /private/tmp/bc-wp54-tmp/evidence/dir-1
        a2: 3f44e98f3697c99cb594c8b2d3518d0b33fdfa2d
        a2: flutter pub get
        a2: flutter build ios --release --no-codesign --dart-define-from-file=config/prod.json
        a2: 232 files kept in /private/tmp/bc-wp54-tmp/evidence/bundle-a2

==> 3/4 build B, in /private/tmp/bc-wp54-tmp/evidence/dir-2 -- a different place on disk
        what differs here and not between A and A' is what the build location is
        baked into
        b: git clone into /private/tmp/bc-wp54-tmp/evidence/dir-2
        b: 3f44e98f3697c99cb594c8b2d3518d0b33fdfa2d
        b: flutter pub get
        b: flutter build ios --release --no-codesign --dart-define-from-file=config/prod.json
        b: 232 files kept in /private/tmp/bc-wp54-tmp/evidence/bundle-b

==> 4/4 A vs A': the same source, built twice in the same directory
        A:  /private/tmp/bc-wp54-tmp/evidence/bundle-a
        A': /private/tmp/bc-wp54-tmp/evidence/bundle-a2
        232 files in a, 232 in a2: 230 identical, 2 differing

        per area (identical / differing):
          7      1      (top level)
          2      0      AppAuth_AppAuth.bundle/...
          2      0      AppAuth_AppAuthCore.bundle/...
          6      0      Base.lproj/...
          159    0      Frameworks/App.framework
          25     0      Frameworks/Flutter.framework
          3      0      Frameworks/Sentry.framework
          2      1      Frameworks/objective_c.framework
          3      0      Frameworks/sqlite3.framework
          3      0      PlugIns/ShareExtension.appex
          2      0      connectivity_plus_connectivity_plus.bundle/...
          1      0      de.lproj/...
          1      0      en.lproj/...
          2      0      file_picker_darwin_file_picker_darwin.bundle/...
          2      0      flutter_appauth_flutter_appauth.bundle/...
          2      0      flutter_secure_storage_darwin_flutter_secure_storage_darwin.bundle/...
          2      0      package_info_plus_package_info_plus.bundle/...
          2      0      shared_preferences_foundation_shared_preferences_foundation.bundle/...
          2      0      url_launcher_ios_url_launcher_ios.bundle/...
          2      0      wakelock_plus_wakelock_plus.bundle/...

  DIFFER Frameworks/objective_c.framework/objective_c
        202896 bytes in both (Mach-O universal binary with 1 architecture: [arm64:Mach-O 64-bit dynamically linked shared library arm64])
        LC_UUID  A: 1F08D9D9-DF6A-34E3-8998-00D5B3FAE8C1
        LC_UUID  B: B73F8632-BBA1-32BF-A865-644B0FBB7EFE
        48 differing bytes: 16 in LC_UUID, 0 in the symbol and string tables, 32 in the embedded signature, 0 elsewhere
  EXPECTED: LC_UUID, which the linker derives from the inputs of that particular link; the embedded ad-hoc signature, which hashes the pages those bytes are in. The code and the data are identical.

  DIFFER Runner
        4833664 bytes in both (Mach-O 64-bit executable arm64)
        LC_UUID  A: C524010B-C0CA-3EE3-A7EA-B1F5CF418490
        LC_UUID  B: 96C87204-3FA8-38CA-B520-F37F1D8A254F
        2628 differing bytes: 16 in LC_UUID, 0 in the symbol and string tables, 0 in the embedded signature, 2612 elsewhere
        2612 byte(s) in neither, first at 942426 942954 943702
        2612 instruction(s) differ, 0 of them in more than an immediate
        the immediates move by: -8 (x57) 8 (x2555)
        both files bind the same symbols at the same addresses (29366 fixups, identical)
        -8 bytes apart, same symbol: __got libobjc/_objc_msgSend
        8 bytes apart, same symbol: __got libobjc/_objc_msgSend
  EXPECTED: LC_UUID, which the linker derives from the inputs of that particular link; and the same program otherwise: every differing instruction loads the same symbol through a different but equivalent slot, which the linker does not always place identically

==> 4/4 A vs B: the same source, built somewhere else
        A: /private/tmp/bc-wp54-tmp/evidence/bundle-a   (/private/tmp/bc-wp54-tmp/evidence/dir-1)
        B: /private/tmp/bc-wp54-tmp/evidence/bundle-b   (/private/tmp/bc-wp54-tmp/evidence/dir-2)
        232 files in a, 232 in b: 228 identical, 4 differing

        per area (identical / differing):
          7      1      (top level)
          2      0      AppAuth_AppAuth.bundle/...
          2      0      AppAuth_AppAuthCore.bundle/...
          6      0      Base.lproj/...
          158    1      Frameworks/App.framework
          25     0      Frameworks/Flutter.framework
          3      0      Frameworks/Sentry.framework
          2      1      Frameworks/objective_c.framework
          3      0      Frameworks/sqlite3.framework
          2      1      PlugIns/ShareExtension.appex
          2      0      connectivity_plus_connectivity_plus.bundle/...
          1      0      de.lproj/...
          1      0      en.lproj/...
          2      0      file_picker_darwin_file_picker_darwin.bundle/...
          2      0      flutter_appauth_flutter_appauth.bundle/...
          2      0      flutter_secure_storage_darwin_flutter_secure_storage_darwin.bundle/...
          2      0      package_info_plus_package_info_plus.bundle/...
          2      0      shared_preferences_foundation_shared_preferences_foundation.bundle/...
          2      0      url_launcher_ios_url_launcher_ios.bundle/...
          2      0      wakelock_plus_wakelock_plus.bundle/...

  DIFFER Frameworks/App.framework/App
        10949200 bytes in both (Mach-O universal binary with 1 architecture: [arm64:Mach-O 64-bit dynamically linked shared library arm64])
        1031434 differing bytes, first at 16433 16434 16435
        identical when both builds happen in the same directory, so the only
        variable left is the directory. The paths inside the file differ:
          /private/tmp/bc-wp54-tmp/evidence/dir-1/.dart_tool/flutter_build/dart_plugin_registrant.dart
          /private/tmp/bc-wp54-tmp/evidence/dir-2/.dart_tool/flutter_build/dart_plugin_registrant.dart
  EXPECTED: the absolute build location is written into this file, and it is byte-identical whenever the two builds share a directory, so the location is the only variable that could have changed it

  DIFFER Frameworks/objective_c.framework/objective_c
        202896 bytes in both (Mach-O universal binary with 1 architecture: [arm64:Mach-O 64-bit dynamically linked shared library arm64])
        LC_UUID  A: 1F08D9D9-DF6A-34E3-8998-00D5B3FAE8C1
        LC_UUID  B: 790DCDB2-3316-3C90-A5C0-433E9208C51A
        48 differing bytes: 16 in LC_UUID, 0 in the symbol and string tables, 32 in the embedded signature, 0 elsewhere
  EXPECTED: LC_UUID, which the linker derives from the inputs of that particular link; the embedded ad-hoc signature, which hashes the pages those bytes are in. The code and the data are identical.

  DIFFER PlugIns/ShareExtension.appex/ShareExtension
        122792 bytes in both (Mach-O 64-bit executable arm64)
        53 differing bytes, first at 122288 122289 122290
        identical when both builds happen in the same directory, so the only
        variable left is the directory. The paths inside the file differ:
          /Users/romanweis/Library/Developer/Xcode/DerivedData/Runner-cgjfjcvjktmwydezceuowxzgdnvn/Build/Intermediates.noindex/Runner.build/Release-iphoneos/ShareExtension.build/Objects-normal/arm64/ShareExtension.swiftmodule
          /Users/romanweis/Library/Developer/Xcode/DerivedData/Runner-cgjfjcvjktmwydezceuowxzgdnvn/Build/Intermediates.noindex/Runner.build/Release-iphoneos/ShareExtension.build/Objects-normal/arm64/ShareViewController.o
          /Users/romanweis/Library/Developer/Xcode/DerivedData/Runner-cpgqcfcfddhwlgcksglsggnlhjjm/Build/Intermediates.noindex/Runner.build/Release-iphoneos/ShareExtension.build/Objects-normal/arm64/ShareExtension.swiftmodule
          /Users/romanweis/Library/Developer/Xcode/DerivedData/Runner-cpgqcfcfddhwlgcksglsggnlhjjm/Build/Intermediates.noindex/Runner.build/Release-iphoneos/ShareExtension.build/Objects-normal/arm64/ShareViewController.o
  EXPECTED: the absolute build location is written into this file, and it is byte-identical whenever the two builds share a directory, so the location is the only variable that could have changed it

  DIFFER Runner
        4833664 bytes in both (Mach-O 64-bit executable arm64)
        LC_UUID  A: C524010B-C0CA-3EE3-A7EA-B1F5CF418490
        LC_UUID  B: C524010B-C0CA-3EE3-A7EA-B1F5CF418490
        2402 differing bytes: 0 in LC_UUID, 2402 in the symbol and string tables, 0 in the embedded signature, 0 elsewhere
        the two debug maps list the same object files, the same symbols and the
        same binAddr for every one of them; 2 symbol(s) sat at a different
        offset inside the intermediate object file they came from:
          <       - { sym: '_$s17connectivity_plus16ConnectivityTypeOSHAAMcMK', objAddr: 0x3220, binAddr: 0x10026E3F0, size: 0x0 }
          >       - { sym: '_$s17connectivity_plus16ConnectivityTypeOSHAAMcMK', objAddr: 0x3210, binAddr: 0x10026E3F0, size: 0x0 }
          <       - { sym: '_$s17connectivity_plus16ConnectivityTypeOSQAAMcMK', objAddr: 0x31A0, binAddr: 0x10026E370, size: 0x0 }
          >       - { sym: '_$s17connectivity_plus16ConnectivityTypeOSQAAMcMK', objAddr: 0x3190, binAddr: 0x10026E370, size: 0x0 }
  EXPECTED: the debug map's record of where the intermediate object files were; and, for 2 symbol(s), the offset it had inside its intermediate object file -- its binAddr, the address in the binary that ships, is unchanged. The code and the data are identical.

commit:     3f44e98f3697c99cb594c8b2d3518d0b33fdfa2d
work dir:   /private/tmp/bc-wp54-tmp/evidence (a clean run deletes it; --keep keeps it)

check_reproducible: ok -- 6 difference(s), every one of them accounted for above
```

### What that says, in one paragraph

**The Dart side of this app reproduces exactly and the Mach-O side does not.**
Two clean clones of the same commit, built in the same directory, produce 230
of 232 identical files — including all 10.9 MB of the Dart AOT snapshot and
every asset, string table and `Info.plist`. The two that differ are `Runner`
and `objective_c`, and neither difference is about our source: `LC_UUID` is a
per-link value, and 2,612 instructions in `Runner` reach `_objc_msgSend`
through whichever of two identical `__got` slots the linker happened to pick.
Build somewhere else and two more files join them, both because an absolute
path is written into the output. So the guarantee we can actually make is:
*the published source produces this app, with six named and measured
exceptions, none of which changes what the program does.* That is weaker than
"bit-identical" and it is the truth.

### Negative test: does the script actually fail?

A check that has only ever been green proves nothing. Build A's bundle was
copied, one byte of an asset was flipped (offset 2481 of
`flutter_assets/packages/material_ui/shaders/ink_sparkle.frag`) and an extra
file was added, and the copy was fed back in with `--against`:

```
==> extra: A vs /tmp/bc-wp54-tmp/doctored2.app
  MISSING only in against: Frameworks/App.framework/flutter_assets/debug_notes.txt
        232 files in a, 233 in against: 231 identical, 1 differing

  DIFFER Frameworks/App.framework/flutter_assets/packages/material_ui/shaders/ink_sparkle.frag
        4960 bytes in both (data)
        1 differing bytes, first at 2481
  UNEXPECTED: not accounted for

check_reproducible: 1 unexpected difference(s), 1 missing file(s), 6 accounted for
The published source does not reproduce this build. Do not claim that it does.
```

Exit code **1**. One flipped byte and one extra file are both caught; the six
accounted-for differences are still accounted for.

### The other acceptance commands

```
$ shellcheck tool/check_reproducible.sh tool/check_compliance.sh   # exit 0, no output
$ actionlint .github/workflows/reproducible.yml                    # exit 0, no output

$ tool/check.sh
==> 1/7 dependencies: flutter pub get --enforce-lockfile
==> 2/7 format: dart format --set-exit-if-changed
==> 3/7 analyze: flutter analyze --fatal-infos
==> 4/7 licence headers: tool/check_headers.dart
==> 5/7 layer imports: tool/check_layers.dart
==> 6/7 codegen is clean: tool/gen.sh, then compare the working tree
==> 7/7 tests: flutter test --exclude-tags golden
OK in 41s                                                          # exit 0

$ tool/check_compliance.sh                                         # exit 0
==> 8/8 reproducible build (tool/check_reproducible.sh)
  ok:   docs/building.md talks about --obfuscate (release builds are made without it)
  note: the reproducible build did not run: it builds the app three times from clean clones, which is release work [release mode would fail here]
        run it by hand with tool/check_reproducible.sh, or read the nightly
        'Reproducible build' workflow. docs/release-checklist.md step D6 is the
        human half, and what a signed build adds to it is human gate H4.

1 decision(s) for the copyright holder are open; see the DECISION lines above.
check_compliance: ok (development mode), 7 note(s). Run with --release before conveying a build.
```

Development mode is what `pr.yml` runs, and section 8 costs it nothing: the
three builds happen only under `--release`, where the exit code above becomes a
failure.

## What H4 still has to verify

The script builds `--no-codesign`. It never touches a signing identity, a
certificate, a keychain or App Store Connect, and it must not start. Whoever
holds **H4** (Apple team id, App Store Connect key) has to close this, and
here is precisely what is open — not "check signing", but these five things:

1. **That the signed binary differs from an unsigned clean-clone build only in
   its signature.** Procedure: `cp -R` both bundles, `codesign
   --remove-signature` the copies of `Runner`, `ShareExtension` and each
   framework binary, then
   `tool/check_reproducible.sh --ref <tag> --against <the stripped bundle>`.
   What must come out is the table in `docs/building.md` and nothing else.
2. **That stripping is a fair comparison at all.** This is the wrinkle and it
   is untested: `--no-codesign` still leaves the linker's **ad-hoc**
   `LC_CODE_SIGNATURE`, while `codesign --remove-signature` removes the load
   command outright. The two sides may therefore differ in *size*, which the
   script reports as "two Mach-O files of different sizes: the code itself
   differs" — a false failure. If that happens, the fix is to strip both sides
   the same way, or to teach `macho_classify` to compare with the
   `LC_CODE_SIGNATURE` region and its load command excluded. Decide which
   before reading anything into a red run.
3. **The files that only a signed bundle has.** `embedded.mobileprovision`, and
   whatever entitlements blob the signing step adds, will be reported as
   `MISSING only in a`. That is correct behaviour and has to be read as such,
   not silenced.
4. **That `ios/Config/Local.xcconfig` changes nothing but signing.** It is
   untracked, it is where `DEVELOPMENT_TEAM` lives, and it is `#include?`-d by
   both `Debug.xcconfig` and `Release.xcconfig`, so it can in principle
   override any build setting. Confirm it sets signing keys only — a bundle id
   or a compiler flag in there would mean the shipped app is built from
   something the published source does not describe.
5. **A second machine.** Everything above ran on one Mac with one Xcode.
   `docs/release-checklist.md` step D6 asks for a run on somebody else's, and
   the script prints Flutter, Xcode and macOS versions at the top of every run
   so a difference has somewhere to be traced to.

Until all five are done, the claim in `docs/building.md` stops where it says it
stops: **this source produces the unsigned app.**

## Handoff notes

**What landed.**

- `tool/check_reproducible.sh` (new, executable, `shellcheck`-clean, bash 3.2).
  Three clean clones, three builds, two comparisons, seven classes of expected
  difference and a failure for anything else. `--help` explains it.
- `tool/check_compliance.sh` section 8: previously a named empty hook, now runs
  the script in **release mode only** and lets its exit code fail the release.
  In development mode it prints a `gate` note and does the one cheap check
  (that `docs/building.md` still says release builds are unobfuscated), so
  `pr.yml` is unaffected.
- `.github/workflows/reproducible.yml` (new): nightly, on every `v*` tag, and
  on manual dispatch. **Not** on pull requests. Report in the run summary and
  as an artifact.
- `docs/building.md`: a "Verify this yourself" section aimed at an outsider,
  with the measured difference tables; the toolchain table now pins the macOS
  build and says why Xcode/macOS cannot be pinned.
- `docs/release-checklist.md`: section 8 row, step D6 rewritten around the
  script (second machine, and the signed build as H4), and D6 now also asks
  for the shipped build's absolute directory to go in the release notes,
  because `docs/building.md` tells readers that path is what removes the
  location-dependent differences.
- `docs/testing.md`: what the script does, the table of the seven classes, and
  the workflow.
- `CLAUDE.md`: one line in the commands block.

**Three things the previous pass had wrong, for the record.**

1. `diff … | sed … | while …` under `set -euo pipefail` **exits the script**
   when the files differ, because `diff` returns 1. That code only runs when a
   debug map fails to match, so it had never executed — and the first time it
   did, the run died mid-sentence with no verdict and no summary. Both
   occurrences (the debug-map branch and the property-list branch) now wrap the
   pipeline in `{ …; } || true`, as does the `comm | head -4` that prints
   differing paths.
2. The list of differing byte offsets was capped at 100,000 silently. A
   truncated list can prove that something differs but never that the rest does
   not, so an "expected" built on one is worthless. The cap is now 4,000,000,
   hitting it is recorded, and a truncated list forces UNEXPECTED.
3. Build logs were opened with `>>`, so a second run in the same work directory
   appended to the first one's log and made its timings a lie. Truncated now.

**One judgement call worth reviewing.** `Runner`'s debug map can differ across
directories in a way the strict comparison rejects: the same symbol, the same
`binAddr`, a different `objAddr` — the offset it had inside the intermediate
object file. I made that a *separate, named* expected class rather than
widening the existing one, and it is only reachable when every differing byte
is already inside the symbol and string tables, so the code and data are
provably identical. It fired on 8 symbols in one run and 2 in another, always
Swift `…MK` metadata symbols. If you think an unexplained 16-byte shift in an
object file should be a failure until somebody explains *why* it shifts, that
is a defensible position and the change is a four-line revert in
`debug_maps_agree`.

**Not done, deliberately.** Nothing was changed to *improve* reproducibility —
no `-oso_prefix`, no fixed build path, no stripping the debug map. Measuring
first was the job; `docs/building.md` names the options and says none of them
is taken.

**Cost.** Two and a half minutes for three builds on a warm development
machine, and a peak of about 27 GB of scratch space in `TMPDIR` (three clones
with their Xcode intermediates). `--keep` leaves it; a clean run deletes it.
The workflow gets 150 minutes, which is generous on purpose: a hosted runner
starts cold.

**Follow-ups, none blocking.**

- **H1** (publish the repository). Until then the script clones from the local
  repository and says so in its own report, and the "clone the published
  source" instruction in `docs/building.md` is an intention.
- **H4**: the five items above.
- WP-50 (fastlane) should call `tool/check_compliance.sh --release --app …`, so
  section 8 runs on the bundle that actually ships.
