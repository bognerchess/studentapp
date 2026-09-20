# Release checklist

Everything that has to be true before a build of Bogner Chess is handed to
Apple. Work through it in order; each step says whether a script answers it or
a person has to.

The machine half is one command:

    tool/check_compliance.sh --release --app build/ios/iphonerelease/Runner.app

It fails loudly and says why. It cannot answer the questions in part D, and it
does not pretend to: those are the ones that need a human, and skipping them is
how a GPL app ends up on a store without the source that goes with it.

A release is a **tag**. The version in `pubspec.yaml` (`0.1.0+1`) becomes the
tag `v0.1.0+1`, and the "Source for this build" row in the app points at
`https://github.com/bognerchess/studentapp/tree/v0.1.0+1`. A build that is not
tagged and pushed has a 404 in its About screen, which is a licence problem,
not a cosmetic one.

---

## A. Before you cut the tag

1. **The gate is green on `main`.**

       tool/check.sh

2. **Bump the version.** `version: <name>+<build>` in `pubspec.yaml`. The build
   number must be higher than every build already on App Store Connect, even
   for a version name that was never submitted.
3. **`docs/building.md` still matches the toolchain.** If Flutter was upgraded,
   `environment.flutter` in `pubspec.yaml` and the table in `docs/building.md`
   change in the same commit. The script compares the two.
4. **`docs/dependencies.md` has a row for every dependency**, with a licence
   from the accepted set (MIT, BSD, Apache-2.0, GPL-compatible). Step D1 is the
   part of this nobody can automate.
5. **Commit, push, and confirm the branch is on the remote.** The corresponding
   source has to be published before the binary is; the script checks that HEAD
   is reachable from a remote branch.
6. **Tag and push the tag.**

       git tag v$(awk '$1 == "version:" { print $2 }' pubspec.yaml)
       git push origin --tags

   The repository must be **public** by now (human gate H1). A private
   repository with a public binary is a GPL violation, and the About screen
   link is the proof one way or the other.

## B. Build

7. **Build the app the release way**, without `--obfuscate` and without
   `--split-debug-info`, so that the published source really reproduces the
   shipped client (see `docs/building.md`). fastlane does this from CI once
   WP-50 has landed.
8. **Keep the `.app` around** for step 9. The compliance script reads the
   bundle, not the project.

## C. Run the compliance script

9. **Run it in release mode against the built bundle.**

       tool/check_compliance.sh --release --app <path>/Runner.app

   What it checks, section by section:

   | | Section | Fails when |
   | --- | --- | --- |
   | 1 | Forbidden dependencies | Firebase or any name on the script's list turns up in `pubspec.yaml`, `pubspec.lock`, a Swift Package Manager pin, or anywhere inside the built app. A native pin that is not classified in the script's `native_pins` table also fails: adding native code is a licence decision. |
   | 2 | Licence rows | A direct dependency has no row in `docs/dependencies.md`, or its licence is outside the accepted set. |
   | 3 | SPDX headers | `tool/check_headers.dart --strict-swift`: an own file without the three-line header, or an adapted file that claims the app-store permission. |
   | 4 | Bundled assets | `tool/check_bundled_assets.sh`: a piece set that is not in `tool/asset_allowlist.txt`, any board image, any Firebase path. |
   | 5 | NOTICE complete | A file with an "Adapted from …" header, a tree under `third_party/`, an allow-listed piece set or a native library that NOTICE does not name. |
   | 6 | Tag matches the build | The tag is not `v<version from pubspec.yaml>`, or HEAD is tagged differently. Outside release mode this only reports. |
   | 7 | Corresponding source | The tree is dirty, HEAD is on no remote, `LICENSE` / `NOTICE` / `LICENSE-APP-STORE-PERMISSION.md` are missing or not bundled with the app, the permission is still a DRAFT (H7), or `docs/building.md` does not name the pinned Flutter version. |
   | 8 | Reproducible build | Nothing yet. WP-54 hangs its verification here; until then step D6 is a person's job. |

10. **Answer the open decisions.** The script prints a `DECISION <id>` block for
    anything it refuses to decide on its own and, in release mode, will not pass
    until each one is acknowledged:

        tool/check_compliance.sh --release --app <path>/Runner.app \
          --accept prebuilt:sentry-cocoa

    Today there is exactly one. **`prebuilt:sentry-cocoa`**: `sentry_flutter`
    pulls `sentry-cocoa`, whose `Package.swift` declares binary targets, so
    Xcode downloads `Sentry.xcframework.zip` from the GitHub release and checks
    its SHA-256 instead of compiling anything. The licence is MIT and the
    corresponding source is the tag `8.58.4`, so the *licence* is fine; what is
    missing is a build of that framework made by us. Accepting it is the
    copyright holder saying "conveying this prebuilt MIT framework alongside our
    GPL app is acceptable". Refusing it means either dropping crash reporting or
    forking the plugin's `Package.swift` onto a source target
    (`docs/dependencies.md` describes both). Do not type `--accept` out of
    habit: write the answer and its date into the release notes for this tag.

## D. What no script can check

11. **D1 — a new dependency's licence is really what the row says.** The script
    compares `pubspec.yaml` against a table; it cannot read a `LICENSE` file on
    pub.dev. For anything added since the last release, open the package's
    repository, read its licence file, and confirm the row.
12. **D2 — the section-7 wording (human gate H7).**
    `LICENSE-APP-STORE-PERMISSION.md` is a **DRAFT** and grants nothing. Until
    the copyright holder (and, if they want one, a lawyer) settles the wording,
    the GPL alone governs, and the GPL and the App Store terms are widely read
    as incompatible. The script fails release mode while the word DRAFT is in
    the file. Replacing it also means: delete the draft box and the
    `aboutAppStorePermissionDraft*` strings the About screen shows (see
    `docs/tasks/WP-31-about-and-licences.md`).
13. **D3 — the courtesy note to the Lichess maintainers (H7).** This app is
    built on `chessground`, `dartchess` and a share extension adapted from
    `lichess-org/mobile`, and it uses piece artwork from lila. Nothing obliges
    us to write to them, and everything about the spirit of the thing does.
    Send it before the first public build, and say plainly what was taken, that
    the Lichess name and logo are not used, and where the source is.
14. **D4 — privacy labels (H8).** App Store Connect asks what the app collects.
    `docs/privacy.md` is the source of truth; the built bundle's privacy
    manifests are the evidence:

        find <path>/Runner.app -name PrivacyInfo.xcprivacy

    Every one of them (the app's own, AppAuth's, Sentry's,
    `flutter_secure_storage_darwin`'s) has to be reflected in the labels.
    Crash data is collected **only** with consent; say so.
15. **D5 — App Review notes (H8, WP-53).** A demo account that reviewers can
    sign in with, set to unlimited analyses; where the AI consent screen is and
    what it says; that the analysis is asynchronous and can take minutes; that
    account deletion is in Settings and really deletes. Screenshots come from
    WP-53's generator.
16. **D6 — the build reproduces the source.** Until WP-54 automates it: clone
    the tag into an empty directory on a second machine, follow
    `docs/building.md` exactly, build, and confirm you get an app that behaves
    like the one you are shipping. Note the date and the two machines in the
    release notes.
17. **D7 — read the About screen on a device.** Version and build number match
    the tag, the source link opens the right tree, the GPL text is complete, the
    permission is marked correctly, and the third-party notices list every piece
    set. It is the user-facing half of everything above, and it is the half a
    script cannot look at.

## E. Submit

18. Upload through fastlane (WP-50), not by hand.
19. Attach the compliance run: the script's output for this tag, the decisions
    that were accepted and why, and the D-steps with who did them and when. Put
    it in the GitHub release for the tag, next to the source everyone is
    entitled to.

---

## If something fails

Do not weaken the check. Three ways out, in order of preference:

1. **Fix the repository.** A missing NOTICE row, a missing dependency row and a
   stale `docs/building.md` are all one-line fixes.
2. **Fix the check**, when it is wrong about the world — a new licence that is
   genuinely GPL-compatible, a native pin that needs classifying. Change
   `tool/check_compliance.sh`, say why in the commit message, and run the whole
   thing again.
3. **Do not ship.** A build that cannot pass section 7 is a build whose
   corresponding source is not available. That is the one thing the GPL does
   not bend on.
