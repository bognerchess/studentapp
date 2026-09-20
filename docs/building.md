# Building

This document names the exact toolchain, because a GPL app should be buildable
by whoever receives it, and "some recent Flutter" is not a build instruction.

## Toolchain

| Tool | Version | Notes |
| --- | --- | --- |
| Flutter | **3.47.5** (stable), framework revision `6a19cca564` | Pinned exactly in `pubspec.yaml` under `environment.flutter`. CI reads the version from there. |
| Dart | 3.13.4 | Comes with Flutter. |
| Xcode | 27.0 (27A266a) | The version the scaffold was built and launched with. |
| macOS | 26.6 on Apple Silicon | |
| iOS Simulator | iPhone 17 Pro, iOS 26.5 runtime | Any recent iPhone simulator works. |
| CocoaPods | **not needed, not installed** | See below. |

When Flutter is upgraded, change `environment.flutter` in `pubspec.yaml` and
the table above in the same commit, and re-run every command in this file.

## Installing Flutter

Flutter is installed from a git tag rather than through a version manager, so
that the version on the machine is unambiguous:

    git clone --depth 1 -b 3.47.5 https://github.com/flutter/flutter.git ~/development/flutter
    git -C ~/development/flutter checkout -b stable

The second command only gives the detached tag checkout a branch name. Without
it Flutter reports `channel [user-branch]` and `flutter doctor` complains about
an unknown channel. If it already showed that once, delete
`~/development/flutter/bin/cache/flutter.version.json` and run
`flutter --version` again.

Put `flutter` and `dart` on the `PATH`. On the development machine that is done
with two symlinks into Homebrew's bin directory, which needs no shell profile
change and also works for non-interactive shells (coding agents, scripts):

    ln -s ~/development/flutter/bin/flutter /opt/homebrew/bin/flutter
    ln -s ~/development/flutter/bin/dart    /opt/homebrew/bin/dart

Then, once:

    flutter --disable-analytics
    dart --disable-analytics
    flutter config --no-enable-android --no-enable-web   # this app is iOS only
    flutter precache --ios
    flutter doctor -v

`flutter doctor` is expected to show two warnings under Xcode that do not
affect this project:

- *"iOS 27.0 Simulator not installed"*. Xcode 27 ships the iOS 27 SDK, and the
  installed simulator runtime is iOS 26.5. Building for the simulator and
  running on the 26.5 runtime both work. Install the 27.0 runtime from
  Xcode > Settings > Components if you want it (several GB).
- *"CocoaPods not installed"*. Correct, and intended.

## CocoaPods is not used

Flutter integrates iOS plugins through Swift Package Manager by default since
3.44. The scaffold builds and launches without CocoaPods, and there is no
`Podfile` in `ios/`. If a plugin added later supports only CocoaPods, Flutter
will create a `Podfile` and ask for the tool; at that point
`brew install cocoapods` is the accepted way to get it, and this section, the
toolchain table and that plugin's row in `docs/dependencies.md` must say so.
Prefer a plugin that supports SwiftPM.

## Build and run in the simulator

    flutter pub get
    dart format --set-exit-if-changed .
    flutter analyze --fatal-infos
    flutter test
    flutter build ios --simulator --debug

    xcrun simctl boot "iPhone 17 Pro"        # if it is not booted yet
    xcrun simctl install booted build/ios/iphonesimulator/Runner.app
    xcrun simctl launch booted com.bognerchess.mobile
    xcrun simctl io booted screenshot /tmp/bogner-chess.png

No signing identity, Apple account or secret is needed for any of this. Once
the environment configs exist (work package WP-03), builds take
`--dart-define-from-file=config/<env>.json`; those files are committed and
contain no secrets.

## Identifiers

| | |
| --- | --- |
| Bundle id | `com.bognerchess.mobile` (`com.bognerchess.mobile.share` for the share extension, `com.bognerchess.mobile.RunnerTests` for the test target) |
| Display name | Bogner Chess |
| Dart package | `bogner_chess` |

`flutter create` derives the bundle id from the project name and would produce
`com.bognerchess.bognerChess`. The bundle id of the app is set in
`ios/Config/Shared.xcconfig`, that of the share extension in
`ios/Config/ShareExtension.xcconfig`, that of the test target in
`ios/Runner.xcodeproj/project.pbxproj`. Do not re-run `flutter create .`
without checking `git diff ios/` afterwards: it may write build settings back
into the project file, where they override the xcconfig files.

The minimum iOS version is 16.0, and the app is iPhone only. How the Xcode
project is organised, and what each `Info.plist` key is for, is described in
`docs/ios-project.md`.

## Device and release builds

An unsigned release build needs nothing beyond the toolchain:

    flutter build ios --release --no-codesign

Signed builds (a real device, an archive) need your Apple developer team in an
untracked `ios/Config/Local.xcconfig`; `docs/ios-project.md` says how. TestFlight
delivery will go through fastlane in CI and is not set up yet. Release builds are made without `--obfuscate`, so
that the published source reproduces the shipped client.
