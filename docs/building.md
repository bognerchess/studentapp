# Building

This document names the exact toolchain, because a GPL app should be buildable
by whoever receives it, and "some recent Flutter" is not a build instruction.

## Toolchain

| Tool | Version | Notes |
| --- | --- | --- |
| Flutter | **3.47.5** (stable), framework revision `6a19cca564` | Pinned exactly in `pubspec.yaml` under `environment.flutter`. CI reads the version from there. |
| Dart | 3.13.4 | Comes with Flutter. |
| Xcode | 27.0 (27A266a) | The version the scaffold was built and launched with, and the one every build in this file was last verified with. |
| macOS | 26.6.2 (25G83) on Apple Silicon | |
| iOS Simulator | iPhone 17 Pro, iOS 26.5 runtime | Any recent iPhone simulator works. |
| CocoaPods | **not needed, not installed** | See below. |
| git | any | Needed to build: the clone is the input, see "Verify this yourself". |

When Flutter is upgraded, change `environment.flutter` in `pubspec.yaml` and
the table above in the same commit, and re-run every command in this file.

Xcode and macOS are not pinned and cannot be: Apple ships one Xcode at a time
and you get the one you get. They are written down because they are part of the
answer to "why did my build come out different from yours"
(`tool/check_reproducible.sh` prints all three versions at the top of every
run, for exactly that reason).

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
    flutter build ios --simulator --debug --dart-define-from-file=config/fake.json

    xcrun simctl boot "iPhone 17 Pro"        # if it is not booted yet
    xcrun simctl install booted build/ios/iphonesimulator/Runner.app
    xcrun simctl launch booted com.bognerchess.mobile
    xcrun simctl io booted screenshot /tmp/bogner-chess.png

No signing identity, Apple account or secret is needed for any of this.

Every build takes a configuration: `--dart-define-from-file=config/<env>.json`,
one of `fake`, `dev`, `staging`, `prod`. The files are committed and contain no
secrets — an API URL, a tenant slug, the OIDC client id, nothing you could not
read off the wire. `config/fake.json` points the app at the local mock server
(`dart run tool/mock_server/main.dart --port 5299`) and needs no backend;
`config/prod.json` is what a release is built with. The define changes what
ends up in the binary, so a build without one, or with a different one, is a
different app: `tool/check_reproducible.sh` names the configuration it used in
its report.

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

An unsigned release build needs nothing beyond the toolchain — no Apple
account, no certificate, no keychain:

    flutter pub get
    flutter build ios --release --no-codesign --dart-define-from-file=config/prod.json

    # the result
    build/ios/iphoneos/Runner.app

Those two commands are what `tool/check_reproducible.sh` runs, and they are the
only two it runs. If this document and that script ever disagree, the script is
the one that gets changed.

Signed builds (a real device, an archive) need your Apple developer team in an
untracked `ios/Config/Local.xcconfig`; `docs/ios-project.md` says how. TestFlight
delivery will go through fastlane in CI and is not set up yet. Release builds are made without `--obfuscate`, so
that the published source reproduces the shipped client.

## Verify this yourself

You do not have to take our word for any of the above. Nothing here needs an
account with us, a key from us, or our permission.

    git clone <the published repository> bogner-chess
    cd bogner-chess
    git checkout v0.1.0+1            # the tag of the build you are holding
    flutter pub get
    flutter build ios --release --no-codesign --dart-define-from-file=config/prod.json

Build it twice, in two directories, and compare the two `Runner.app` bundles.
`tool/check_reproducible.sh` in this repository does exactly that — three
builds, in fact, for the reason below — and prints the result file by file. You
are welcome to read it first, and to not run it at all and use `diff -r`
instead.

    tool/check_reproducible.sh --ref v0.1.0+1            # clone from `origin`
    tool/check_reproducible.sh --ref v0.1.0+1 --source <url or path>

It clones from the repository's `origin` remote — the published source, which
is the thing being checked — and says at the top of every run which source it
used, because a run that cloned from somebody's working copy proves less than
one that cloned from the published URL. (Today it says "this repository on
disk": the repository is not public yet. That is tracked as human gate **H1**,
and until it is open the "take our source and check us" part of this section is
an intention, not something you can act on.)

**232 files come out of that build. Here is what does and does not come out the
same, measured rather than assumed.** The run this section is written from is
pasted in full in `docs/tasks/WP-54-reproducible-build.md`; re-running it is the
point of the script.

Two things vary, and they have to be kept apart, because only one of them is
about where you built.

**1. Two builds in the same directory: 230 of 232 files identical.** Take two
separate clean clones of the same commit, build both in the *same* directory,
and two files still differ:

| What differs | Why |
| --- | --- |
| `Frameworks/objective_c.framework/objective_c` | 48 bytes: the sixteen of `LC_UUID`, which the linker derives from the inputs of that particular link so a crash report can be matched to its symbols, and the 32 of the embedded ad-hoc signature that hash the page those sixteen sit in. Nothing else in the file differs. |
| `Runner` | 2,628 bytes: sixteen of `LC_UUID` and 2,612 in `__TEXT`. Those 2,612 are 2,612 instructions that load `_objc_msgSend` through a pointer slot eight bytes away from the one the other build chose. The linker emits two `__got` entries for that symbol and does not always send a given instruction to the same one. |

That second row is the honest headline: **the `Runner` Mach-O does not
reproduce bit for bit, and the reason has nothing to do with our source.** The
script does not take it on trust — it requires the two disassemblies to have
the same instructions at the same addresses and to differ only in immediates,
requires `dyld_info -fixups` to be identical so both binaries bind the same
symbols at the same addresses, and requires every immediate to move by a
distance that separates two slots holding the *same* symbol. A real code change
fails all three.

Everything else does reproduce exactly: the 10.9 MB Dart AOT snapshot in
`Frameworks/App.framework/App`, every asset, every `Info.plist`, the share
extension, the prebuilt `Flutter.framework` and `Sentry.framework`.

**2. Two builds in different directories: 228 of 232 identical.** Build the
same commit somewhere else and two more files join the list:

| What differs | Why |
| --- | --- |
| `Frameworks/App.framework/App` | About a million bytes of the Dart AOT snapshot. The snapshot records the path of `.dart_tool/flutter_build/dart_plugin_registrant.dart`, which is inside the build directory, and a different path shifts a great deal of what follows. The evidence that this is all it is: the file is byte-identical whenever the two builds share a directory, so the directory is the only variable that can have changed it. |
| `PlugIns/ShareExtension.appex/ShareExtension` | ~50 bytes: the absolute paths of its two intermediate object files under `~/Library/Developer/Xcode/DerivedData/Runner-<hash>/`, where Xcode derives `<hash>` from the absolute path of the project. |

`Runner` differs here too, but differently: its symbol and string tables carry
a debug map, one entry per intermediate object file, and each of those paths
carries that build's own DerivedData hash. The script dumps both maps with
`dsymutil`, normalises the location away, and requires what is left to match —
the same object files, the same symbols, the same `binAddr` for every one of
them. In the run above two symbols also sat at a different *offset inside their
object file*; their address in the shipped binary was unchanged, and the script
says so and counts them rather than waving at them.

So, plainly: **building at the same absolute path removes group 2. It does not
remove group 1**, because group 1 is not about the path — it is the Apple
toolchain not being deterministic. In both runs made so far, two builds at the
same absolute path produced `Runner` binaries that differ in exactly the way
the table above describes, so we cannot tell you a path at which this app comes
out bit for bit identical. The release notes for each tag record the directory
the shipped build was made in, so that you can at least eliminate group 2.

None of this is unfixable, and none of it is fixed. `-oso_prefix`, a build at a
fixed path, or stripping the debug map out of the release binary would each
remove part of group 2; group 1 needs the linker to be deterministic, which is
Apple's to do. We measured it before changing anything, because a number you
have not measured is not a guarantee.

**What this does not prove.** The binary Apple distributes is *signed*, and it
is signed after the build, with a certificate and a provisioning profile that
are not in this repository and cannot be. The honest claim is therefore: this
source produces the unsigned app, with the exceptions above and no others. If
you want to check a signed build against this source yourself, strip the
signature from a copy of each — `codesign --remove-signature` — before
comparing, and expect `embedded.mobileprovision` to exist only on the signed
side. Apple also re-signs and may re-encrypt what it distributes, so a download
from the App Store will not match byte for byte no matter what anybody does.

**If your build differs from ours in some other way**, the likely causes, in
order: a different Flutter (the pin is in `pubspec.yaml`, the script refuses to
run on the wrong one), a different Xcode or macOS (both are printed at the top
of every run), a different `--dart-define-from-file`, or a working tree that is
not a clean clone. If none of those explains it, that is worth telling us
about: it means the source and the binary have drifted apart, which is the one
thing this whole document exists to prevent.
