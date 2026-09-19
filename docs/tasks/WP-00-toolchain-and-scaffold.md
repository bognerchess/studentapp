---
id: WP-00
title: Toolchain and scaffold
status: review
size: M
depends_on: []
blocked_by_human: []         # H0 (install Flutter) and H1 (bundle id, names) resolved by the user on 2026-09-19. Creating the GitHub repo stays with the user.
branch: main   # first commit of the repository; every later WP uses its own branch
pr:
---

## Scope

Turn this directory into a buildable, launchable Flutter iOS project with the licence and documentation skeleton in place. The directory already contains `CLAUDE.md` and `docs/tasks/`; keep them.

- Install Flutter stable, pinned to one exact version (3.47.x at planning time; re-check the current stable and what `lichess-org/mobile` pins). Record the install method in `docs/building.md`. Flutter uses Swift Package Manager by default since 3.44, so CocoaPods should not be needed; say so if that turns out wrong.
- `git init` (branch `main`), then `flutter create --platforms ios --org com.bognerchess --project-name bogner_chess .` and set the bundle id to the value confirmed in H1 (proposal: `com.bognerchess.mobile`). Pin the Flutter version in `pubspec.yaml` (`environment.flutter`) so CI can read it.
- Strict `analysis_options.yaml` (`flutter_lints` plus `strict-casts`, `strict-inference`, `strict-raw-types`).
- `LICENSE` (GPL-3.0 text), `LICENSE-APP-STORE-PERMISSION.md` (placeholder marked DRAFT; the wording is human gate H7), `NOTICE` (asset and adapted-code table, empty rows for now, in the style of `../../chessapps/taktik/NOTICE`), `README.md` (what the app is, how to build, why it is GPL, "not affiliated with Lichess"; write prose that explains the reasons, as in the user's other repos).
- `docs/dependencies.md`: a table of every planned package from section 1 of `../product-hub/docs/mobile-mvp/03-design-flutter-client.md` with version, licence and purpose, **re-verified on pub.dev today**. Add only the packages this WP needs to `pubspec.yaml`; later WPs add theirs.
- `docs/plans/2026-09-19-mobile-mvp-client.md`: a public version of the client design (architecture, layer rules, testing strategy, iOS specifics). Leave out local filesystem paths and anything about backend internals.
- `.gitignore` additions: `ios/Config/Local.xcconfig`, build outputs.

## Out of scope

xcconfig layering, entitlements, Info.plist work (WP-01). CI and `tool/check.sh` (WP-02). App shell, routing, theming (WP-03). The chessground fork (WP-04). Do not add `chessground` from pub.dev even temporarily: it bundles piece sets this app may not ship.

## Contracts

**Consumes:** H1 decisions (bundle id, app display name "Bogner Chess").
**Produces:** the Flutter project, the pinned SDK version, the licence files, `docs/dependencies.md`, `docs/building.md`. Everything else in this repo depends on it.

## Steps

1. Confirm H0 and H1 are resolved (ask the user if the task file still says blocked).
2. Install and pin Flutter; run `flutter doctor -v` and fix what an agent can fix.
3. Scaffold, add the files above, make the first commit on a branch. Pushing and creating the GitHub repository are the user's call.
4. Build for the simulator, launch it with the iOS Simulator tool, take a screenshot.

## Acceptance commands

```bash
flutter --version
flutter doctor -v
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter build ios --simulator --debug
# then: launch build/ios/iphonesimulator/Runner.app in the simulator and attach a screenshot
```

## Evidence

All commands were run on 2026-09-19 from the repository root, after the last change to the code. Home directory paths are shortened to `~`.

`flutter --version`

```
Flutter 3.47.5 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 6a19cca564 (vor 2 Tagen) • 2026-09-17 14:13:22 -0400
Engine • hash ab598368592da0064197e2bc15c7f5b0a2c6bb1f (revision af7e796e16) (3 days ago) • 2026-09-16 18:35:09.000Z
Tools • Dart 3.13.4 • DevTools 2.60.0
```

`flutter doctor -v`

```
[✓] Flutter (Channel stable, 3.47.5, on macOS 26.6.2 25G83 darwin-arm64, locale de-CH) [165ms]
    • Flutter version 3.47.5 on channel stable at ~/development/flutter
    • Upstream repository https://github.com/flutter/flutter.git
    • Framework revision 6a19cca564 (vor 2 Tagen), 2026-09-17 14:13:22 -0400
    • Engine revision af7e796e16
    • Dart version 3.13.4
    • DevTools version 2.60.0
    • Feature flags: no-enable-web, enable-linux-desktop, enable-macos-desktop, enable-windows-desktop, no-enable-android, enable-ios, cli-animations, enable-native-assets, enable-record-use, enable-swift-package-manager, omit-legacy-version-file, enable-lldb-debugging, enable-uiscene-migration

[!] Xcode - develop for iOS and macOS (Xcode 27.0) [247ms]
    • Xcode at /Applications/Xcode.app/Contents/Developer
    • Build 27A266a
    ! iOS 27.0 Simulator not installed; this may be necessary for iOS and macOS development.
      To download and install the platform, open Xcode, select Xcode > Settings > Components,
      and click the GET button for the required platform.

      For more information, please visit:
        https://developer.apple.com/documentation/xcode/installing-additional-simulator-runtimes
    ! CocoaPods not installed.
        CocoaPods is a package manager for iOS or macOS platform code.
        Without CocoaPods, plugins will not work on iOS or macOS.
        For more info, see https://flutter.dev/to/platform-plugins
      For installation instructions, see https://guides.cocoapods.org/using/getting-started.html#installation

[✓] Connected device (3 available; the physical device is left out of this paste) [5.7s]
    • iPhone 17 Pro (mobile)               • 1037C9F7-CBE9-4FFC-B954-C67B25BBD107 • ios          • com.apple.CoreSimulator.SimRuntime.iOS-26-5 (simulator)
    • macOS (desktop)                      • macos                                • darwin-arm64 • macOS 26.6.2 25G83 darwin-arm64

[✓] Network resources [442ms]
    • All expected network resources are available.

! Doctor found issues in 1 category.
```

The two Xcode warnings are expected and harmless here; `docs/building.md` explains them. The simulator build below passes without CocoaPods and without the iOS 27.0 runtime.

`dart format --set-exit-if-changed .`

```
Formatted 2 files (0 changed) in 0.01 seconds.
exit code: 0
```

`flutter analyze --fatal-infos`

```
Analyzing studentapp...
No issues found! (ran in 3.4s)
exit code: 0
```

`flutter test`

```
00:00 +0: loading ~/Developer/bognerchess/studentapp/test/widget_test.dart
00:00 +0: the placeholder home screen shows the app name
00:00 +1: All tests passed!
exit code: 0
```

`flutter build ios --simulator --debug`

```
Building com.bognerchess.mobile for simulator (ios)...
Running Xcode build...
Xcode build done.                                            3.6s
✓ Built build/ios/iphonesimulator/Runner.app
exit code: 0
```

Bundle id and display name:

```
$ grep -n PRODUCT_BUNDLE_IDENTIFIER ios/Runner.xcodeproj/project.pbxproj
387:				PRODUCT_BUNDLE_IDENTIFIER = com.bognerchess.mobile;
403:				PRODUCT_BUNDLE_IDENTIFIER = com.bognerchess.mobile.RunnerTests;
420:				PRODUCT_BUNDLE_IDENTIFIER = com.bognerchess.mobile.RunnerTests;
435:				PRODUCT_BUNDLE_IDENTIFIER = com.bognerchess.mobile.RunnerTests;
569:				PRODUCT_BUNDLE_IDENTIFIER = com.bognerchess.mobile;
592:				PRODUCT_BUNDLE_IDENTIFIER = com.bognerchess.mobile;
$ /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" -c "Print :CFBundleDisplayName" build/ios/iphonesimulator/Runner.app/Info.plist
com.bognerchess.mobile
Bogner Chess
```

Launch: `build/ios/iphonesimulator/Runner.app` was installed and launched on the "iPhone 17 Pro" simulator (iOS 26.5) with the iOS Simulator tool. The placeholder screen rendered with the text "Bogner Chess" and the debug banner. `xcrun simctl listapps` shows `com.bognerchess.mobile` installed.

![Placeholder home screen in the simulator](evidence/WP-00-launch.png)

## Handoff notes

**Toolchain**

- Flutter **3.47.5** stable (Dart 3.13.4), the newest stable on 2026-09-19 (released 2026-09-18). `lichess-org/mobile` pins 3.47.4 today; the difference is one hotfix release. Pinned in `pubspec.yaml` (`environment.flutter: 3.47.5`), which is what `subosito/flutter-action` reads with `flutter-version-file`.
- Installed by `git clone --depth 1 -b 3.47.5` into `~/development/flutter`, with symlinks `flutter` and `dart` in `/opt/homebrew/bin`. No shell profile was changed, so non-interactive agent shells find both.
- A tag checkout is a detached HEAD, and Flutter then reports `channel [user-branch]` and doctor flags it. Fix: `git -C ~/development/flutter checkout -b stable`, delete `bin/cache/flutter.version.json`, run `flutter --version`. Doctor now shows `Channel stable`. The clone is shallow, so `flutter upgrade` and `flutter channel` will not work; upgrade by cloning the new tag.
- Global Flutter settings changed on this machine: analytics off for `flutter` and `dart`, and `flutter config --no-enable-android --no-enable-web` (the app is iOS only; this also removes two irrelevant doctor failures). Undo with `flutter config --enable-android --enable-web`.
- **CocoaPods was not needed and is not installed.** The project uses Swift Package Manager (`FlutterGeneratedPluginSwiftPackage` is referenced in the project file, there is no `Podfile`). If a later plugin supports only CocoaPods, follow `docs/building.md`: `brew install cocoapods` and record it.
- Doctor's "iOS 27.0 Simulator not installed" is a warning only: Xcode 27.0 has the iOS 27 SDK, the installed runtime is iOS 26.5, and building plus running on it works.
- `sed` on this machine is GNU sed (`gsed`); use `/usr/bin/sed -i ''` or avoid `sed -i` in scripts (relevant for WP-02).

**Project**

- Bundle id `com.bognerchess.mobile`, tests `com.bognerchess.mobile.RunnerTests`, display name "Bogner Chess" (`CFBundleDisplayName`; `CFBundleName` is still `bogner_chess`, left for WP-01), Dart package `bogner_chess`. `flutter create` generates `com.bognerchess.bognerChess`; re-running it may bring that back in new files.
- Version is `0.1.0+1`. `IPHONEOS_DEPLOYMENT_TARGET` is still Flutter's 15.0 and `TARGETED_DEVICE_FAMILY` still `1,2`; both are WP-01 (iOS 16.0, iPhone only).
- `pubspec.yaml` has no dependency beyond the SDK and `flutter_lints`; `cupertino_icons` was removed as unused. `pubspec.lock` is committed (this is an app).
- `analysis_options.yaml`: `flutter_lints` plus `strict-casts`, `strict-inference`, `strict-raw-types` and a set of extra lints (`unawaited_futures`, `discarded_futures`, `avoid_dynamic_calls`, `require_trailing_commas`, `prefer_single_quotes`, `directives_ordering` and others). It already excludes `**/*.g.dart`, `**/*.freezed.dart` and `**/*.graphql.dart`. `unnecessary_await_in_return` is deprecated in Dart 3.13 and fails `--fatal-infos`; do not add it back.
- `lib/main.dart` holds `BognerChessApp` and `PlaceholderHomeScreen`; WP-03 replaces both. The widget test only asserts the text "Bogner Chess".
- The header used on Dart files is three lines: the SPDX line, `Copyright (C) 2026 Bogner Chess`, and the reference to `LICENSE-APP-STORE-PERMISSION.md`. WP-02's header check should require the first and the third. The copyright holder's legal name is a guess and belongs to H7.

**Documents**

- `docs/dependencies.md` was verified against the pub.dev API today. Differences from the planning notes: `sqlite3_flutter_libs` is end of life (`0.6.0+eol`), so WP-13 should use `drift_flutter` 0.3.1; `freezed` 4.0.2 was published yesterday and needs Dart >= 3.13.0; `hive`'s licence is not even detected by pub.dev (it stays a tolerated, unused transitive dependency of `graphql`). Rows were added for `gql`, `gql_http_link`, `drift_dev`, `drift_flutter`, `intl`, `freezed_annotation`, `json_annotation`, `json_serializable`, `build_runner`, `uuid`, `http` and `sentry_dart_plugin`. Each WP re-checks its packages and fills in the constraint when it adds them.
- `LICENSE` is the unmodified text from gnu.org. `LICENSE-APP-STORE-PERMISSION.md` is a DRAFT that says explicitly that it grants nothing yet (H7). `NOTICE` has the empty allow-list tables (adapted code, piece sets, fonts, sound); WP-04 adds the first piece-set rows.
- `docs/plans/2026-09-19-mobile-mvp-client.md` is the public design. It contains no local paths, no server product names and no endpoint URLs. `CLAUDE.md` and `docs/tasks/INDEX.md` (both written before this WP) point to `../product-hub/...`; that is a relative path to a private repository, harmless but worth a look before the repository goes public.
- `.gitignore` additionally covers `ios/Config/Local.xcconfig`, build outputs, fastlane output and, as a second line of defence, `*.p8`, `*.p12`, `*.mobileprovision` and `.env*`.

**Git**

- The repository was created with `git init -b main` and this WP is its first commit, made directly on `main` because there was no history to branch from. From here on: one branch per WP, never commit to `main`. No remote exists; creating the GitHub repository and pushing are the user's call (rest of H1).
